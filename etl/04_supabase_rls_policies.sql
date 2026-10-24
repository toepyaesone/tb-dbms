-- ============================================================================
-- STEP 2: CLOUD SUPABASE ROW-LEVEL SECURITY (RLS) POLICIES
-- Covers: user_roles, township_org_units, 4 DHIS2 tables, ygntbpro, and target
-- ============================================================================

-- 1. Enable RLS on user_roles & township_org_units
ALTER TABLE public.user_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.township_org_units ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can view own role" ON public.user_roles;
CREATE POLICY "Users can view own role"
ON public.user_roles FOR SELECT TO authenticated
USING (auth.uid() = user_id);

DROP POLICY IF EXISTS "Authenticated users can read township mapping" ON public.township_org_units;
CREATE POLICY "Authenticated users can read township mapping"
ON public.township_org_units FOR SELECT TO authenticated
USING (true);

-- ============================================================================
-- 2. SECURITY DEFINER HELPER FUNCTIONS FOR FAST RLS CHECKS
-- ============================================================================

-- Helper A: Get current user's role as text
CREATE OR REPLACE FUNCTION public.get_my_role()
RETURNS text AS $$
    SELECT role::text FROM public.user_roles WHERE user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper B: Check if user is an Admin or has 'ALL' township access
CREATE OR REPLACE FUNCTION public.is_admin_or_all_access()
RETURNS boolean AS $$
    SELECT EXISTS (
        SELECT 1 FROM public.user_roles
        WHERE user_id = auth.uid()
          AND (role::text = 'admin' OR UPPER(COALESCE(township_name, '')) = 'ALL')
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper C: Get all DHIS2 org_unit_ids authorized for the current user
CREATE OR REPLACE FUNCTION public.get_my_allowed_org_units()
RETURNS SETOF varchar AS $$
    SELECT t.org_unit_id
    FROM public.township_org_units t
    JOIN public.user_roles u ON u.user_id = auth.uid()
    WHERE LOWER(TRIM(u.township_name)) IN (
        LOWER(TRIM(t.township_name)),
        LOWER(TRIM(t.short_tsp))
    )
    UNION
    SELECT unnest(u.allowed_org_unit_ids)::varchar
    FROM public.user_roles u
    WHERE u.user_id = auth.uid();
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper D: Check if user can access a specific DHIS2 org_unit_id
CREATE OR REPLACE FUNCTION public.can_access_org_unit(target_ou varchar)
RETURNS boolean AS $$
    SELECT (
        public.is_admin_or_all_access()
        OR target_ou IN (SELECT public.get_my_allowed_org_units())
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper E: Check if user can access a patient UPI (cohort-level access)
CREATE OR REPLACE FUNCTION public.can_access_upi(target_upi varchar)
RETURNS boolean AS $$
    SELECT (
        public.is_admin_or_all_access()
        OR EXISTS (
            SELECT 1 FROM public.dhis2_registration_screening r
            WHERE r.upi = target_upi
              AND public.can_access_org_unit(r.org_unit_id)
        )
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- Helper F: Check if user can access a ygntbpro / target row by Township ("Tsp"), Team ("Team"), or org_unit_id
CREATE OR REPLACE FUNCTION public.can_access_tsp_team(row_tsp text, row_team integer, row_ou varchar)
RETURNS boolean AS $$
    SELECT (
        public.is_admin_or_all_access()
        OR (row_ou IS NOT NULL AND row_ou IN (SELECT public.get_my_allowed_org_units()))
        OR EXISTS (
            SELECT 1
            FROM public.user_roles u
            LEFT JOIN public.township_org_units t
              ON LOWER(TRIM(u.township_name)) IN (LOWER(TRIM(t.township_name)), LOWER(TRIM(t.short_tsp)))
            WHERE u.user_id = auth.uid()
              AND (
                  LOWER(TRIM(COALESCE(row_tsp, ''))) = LOWER(TRIM(COALESCE(u.township_name, '')))
                  OR LOWER(TRIM(COALESCE(row_tsp, ''))) = LOWER(TRIM(COALESCE(t.short_tsp, '')))
                  OR LOWER(TRIM(COALESCE(row_tsp, ''))) = LOWER(TRIM(COALESCE(t.township_name, '')))
              )
              AND (u.assigned_team IS NULL OR u.assigned_team = row_team)
        )
    );
$$ LANGUAGE sql SECURITY DEFINER STABLE;

-- ============================================================================
-- 3. RLS POLICIES FOR THE 4 DHIS2 TABLES (Read-Only for Clinic Users)
-- (Automated Python ETL uses SUPABASE_SERVICE_ROLE_KEY which bypasses RLS)
-- ============================================================================

-- 3A. Registration & Screening (Filtered by org_unit_id)
ALTER TABLE public.dhis2_registration_screening ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_select_dhis2_registration_screening ON public.dhis2_registration_screening;
CREATE POLICY rls_select_dhis2_registration_screening
ON public.dhis2_registration_screening FOR SELECT TO authenticated
USING (public.can_access_org_unit(org_unit_id));

-- 3B. Multi-Episode DHIS2 Tables (Accessible by org_unit_id OR registered UPI cohort)
DO $$
DECLARE
    tbl text;
BEGIN
    FOREACH tbl IN ARRAY ARRAY[
        'dhis2_diagnostic_evaluation',
        'dhis2_tb_surveillance',
        'dhis2_registration_screening'
    ]
    LOOP
        EXECUTE format('ALTER TABLE public.%I ENABLE ROW LEVEL SECURITY;', tbl);
        EXECUTE format('DROP POLICY IF EXISTS rls_select_%I ON public.%I;', tbl, tbl);
        EXECUTE format('
            CREATE POLICY rls_select_%I ON public.%I
            FOR SELECT TO authenticated
            USING (
                public.can_access_org_unit(org_unit_id)
                OR public.can_access_upi(upi)
            );
        ', tbl, tbl);
    END LOOP;
END;
$$;

-- ============================================================================
-- 4. RLS POLICIES FOR public.ygntbpro (SELECT, INSERT, UPDATE, DELETE)
-- ============================================================================
ALTER TABLE public.ygntbpro ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_select_ygntbpro ON public.ygntbpro;
CREATE POLICY rls_select_ygntbpro
ON public.ygntbpro FOR SELECT TO authenticated
USING (public.can_access_tsp_team("Tsp", "Team", "org_unit_id"));

DROP POLICY IF EXISTS rls_insert_ygntbpro ON public.ygntbpro;
CREATE POLICY rls_insert_ygntbpro
ON public.ygntbpro FOR INSERT TO authenticated
WITH CHECK (
    public.get_my_role() IN ('admin', 'supervisor', 'clinic_staff', 'data_entry')
    AND public.can_access_tsp_team("Tsp", "Team", "org_unit_id")
);

DROP POLICY IF EXISTS rls_update_ygntbpro ON public.ygntbpro;
CREATE POLICY rls_update_ygntbpro
ON public.ygntbpro FOR UPDATE TO authenticated
USING (
    public.get_my_role() IN ('admin', 'supervisor', 'clinic_staff', 'data_entry')
    AND public.can_access_tsp_team("Tsp", "Team", "org_unit_id")
)
WITH CHECK (
    public.get_my_role() IN ('admin', 'supervisor', 'clinic_staff', 'data_entry')
    AND public.can_access_tsp_team("Tsp", "Team", "org_unit_id")
);

DROP POLICY IF EXISTS rls_delete_ygntbpro ON public.ygntbpro;
CREATE POLICY rls_delete_ygntbpro
ON public.ygntbpro FOR DELETE TO authenticated
USING (public.get_my_role() = 'admin');

-- ============================================================================
-- 5. RLS POLICIES FOR public.target (SELECT for All Clinic Users, Write for Admin/Supervisor)
-- ============================================================================
ALTER TABLE public.target ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS rls_select_target ON public.target;
CREATE POLICY rls_select_target
ON public.target FOR SELECT TO authenticated
USING (public.can_access_tsp_team("Tsp", "Team", "org_unit_id"));

DROP POLICY IF EXISTS rls_insert_target ON public.target;
CREATE POLICY rls_insert_target
ON public.target FOR INSERT TO authenticated
WITH CHECK (
    public.get_my_role() IN ('admin', 'supervisor')
    AND public.can_access_tsp_team("Tsp", "Team", "org_unit_id")
);

DROP POLICY IF EXISTS rls_update_target ON public.target;
CREATE POLICY rls_update_target
ON public.target FOR UPDATE TO authenticated
USING (
    public.get_my_role() IN ('admin', 'supervisor')
    AND public.can_access_tsp_team("Tsp", "Team", "org_unit_id")
)
WITH CHECK (
    public.get_my_role() IN ('admin', 'supervisor')
    AND public.can_access_tsp_team("Tsp", "Team", "org_unit_id")
);
