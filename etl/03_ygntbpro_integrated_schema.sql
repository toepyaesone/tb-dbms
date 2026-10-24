-- ============================================================================
-- INTEGRATED YGNTBPRO, TARGET & MULTI-USER SCHEMA
-- Safe for BOTH Cloud Supabase (skips locked auth schema & preserves data)
-- and Local Docker PostgreSQL / NocoDB (`tb_local_data`)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";

-- 0. Only create the local auth.users stub if the 'auth' schema does NOT exist
-- (Cloud Supabase already has 'auth', so it skips this block and avoids Error 42501)
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_namespace WHERE nspname = 'auth') THEN
        CREATE SCHEMA auth;
        CREATE TABLE auth.users (
            id uuid PRIMARY KEY
        );
    END IF;
END
$$;

-- Ensure app_role ENUM exists and contains all required collaboration roles
DO $$
BEGIN
    IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'app_role') THEN
        CREATE TYPE public.app_role AS ENUM ('admin', 'supervisor', 'clinic_staff', 'data_entry', 'viewer');
    END IF;
END
$$;

ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'admin';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'supervisor';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'clinic_staff';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'data_entry';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'viewer';

-- ============================================================================
-- 1. TOWNSHIP & DHIS2 ORG UNIT MAPPING TABLE
-- Maps Township names ("Tsp") and DHIS2 org_unit_id (YTP & NTP UIDs)
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.township_org_units (
    org_unit_id VARCHAR(64) PRIMARY KEY,
    township_name VARCHAR(255) NOT NULL,
    short_tsp VARCHAR(100),
    ou_type VARCHAR(50)
);

INSERT INTO public.township_org_units (org_unit_id, township_name, short_tsp, ou_type) VALUES
    ('YGCPqlBamwD', '12. YTP/Pyi Gyi Khin (Hlaing)', 'Hlaing', 'Partner_YTP'),
    ('KqjORlUe8Yc', '12. YTP/Pyi Gyi Khin (Hlaing)', 'Hlaing', 'Township_NTP'),
    ('dE0upZMc4xG', '12. YTP/Pyi Gyi Khin (Kyeemyindaing)', 'Kyeemyindaing', 'Partner_YTP'),
    ('rTTCKrLpxTB', '12. YTP/Pyi Gyi Khin (Kyeemyindaing)', 'Kyeemyindaing', 'Township_NTP'),
    ('mCgl8tnCaee', '12. YTP/Pyi Gyi Khin (Dagon Myothit (South))', 'Dagon Myothit (South)', 'Partner_YTP'),
    ('XHz6CPxTAbR', '12. YTP/Pyi Gyi Khin (Dagon Myothit (South))', 'Dagon Myothit (South)', 'Township_NTP'),
    ('lJ9AHubJTjg', '12. YTP/Pyi Gyi Khin (Thingangyun)', 'Thingangyun', 'Partner_YTP'),
    ('aBfPB9AwbF5', '12. YTP/Pyi Gyi Khin (Thingangyun)', 'Thingangyun', 'Township_NTP'),
    ('KSRVZsryAKz', '12. YTP/Pyi Gyi Khin (South Okkalapa)', 'South Okkalapa', 'Partner_YTP'),
    ('OeZsFpNKLP5', '12. YTP/Pyi Gyi Khin (South Okkalapa)', 'South Okkalapa', 'Township_NTP'),
    ('bctwifUcioE', '12. YTP/Pyi Gyi Khin (Mayangone)', 'Mayangone', 'Partner_YTP'),
    ('mPwLv1cjror', '12. YTP/Pyi Gyi Khin (Mayangone)', 'Mayangone', 'Township_NTP'),
    ('Z7Qf4wgtHz3', '12. YTP/Pyi Gyi Khin (Shwepyithar)', 'Shwepyithar', 'Partner_YTP'),
    ('aMAEOgli6W8', '12. YTP/Pyi Gyi Khin (Shwepyithar)', 'Shwepyithar', 'Township_NTP')
ON CONFLICT (org_unit_id) DO UPDATE
SET township_name = EXCLUDED.township_name,
    short_tsp = EXCLUDED.short_tsp,
    ou_type = EXCLUDED.ou_type;

-- ============================================================================
-- 2. PROJECT ACHIEVEMENTS TABLE: public.ygntbpro
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.ygntbpro (
    "Date" date,
    "Team" integer,
    "StateRegionName" text,
    "Tsp" text,
    "WardVillage" text,
    "WardCode" text,
    "Approach" text,
    "Visit_no" integer,
    "Sr_No" integer,
    "ReportingPeriod" text,
    "RegistrarDate" date,
    "TownshipTBRegNumber" text,
    "PatientID" text NOT NULL UNIQUE,
    "upi" text,                          -- DHIS2 Unique ID (UPI)
    "index_upi" text,                    -- DHIS2 Unique ID (UPI) - Index Case
    "org_unit_id" varchar(64),           -- DHIS2 OrgUnit UID
    "tracked_entity_instance" text,      -- DHIS2 TEI UID
    "enrollment_id" text,                -- DHIS2 Enrollment UID
    "Name" text,
    "Nationality" text,
    "Age" integer,
    "Sex" integer,
    "Address" text,
    "Ptstsp" text,
    "PhoneNo" text,
    "Origin" integer,
    "VOL" integer,
    "Referralfor" numeric,
    "VolunteerName" text,
    "Organization" text,
    "Cough" integer,
    "Fever" integer,
    "Wtloss" integer,
    "Nightsweat" integer,
    "Haemoptysis" integer,
    "Chestpain" integer,
    "Fatigue" integer,
    "Neckglands" integer,
    "TBcontact" integer,
    "MDRTBcontact" integer,
    "TBTreatmenthistory" integer,
    "Transferin" text,
    "TypeofPatients" text,
    "TypeofDisease" text,
    "SpecifyifEPSiteofEPTB" text,
    "Smoking" integer,
    "Reasonforexamination" numeric,
    "TypeofPatient" numeric,
    "PublicHealthCare1" integer,
    "TypeofPatient1" integer,
    "DM1" integer,
    "RBS" numeric,
    "HbA1c" numeric,
    "HT1" integer,
    "Systolic" numeric,
    "Diastolic" numeric,
    "DMHT1" numeric,
    "RTIAVI1" numeric,
    "Generalweakness1" numeric,
    "Other1" text,
    "HIVStatus" text,
    "CPT" date,
    "ART" date,
    "Cxrr" numeric,
    "CXRresult" numeric,
    "Cxr_others" text,
    "Sputum_request" numeric,
    "Micror" numeric,
    "Sputummicroscopyresult" numeric,
    "Genexpertrequested" numeric,
    "GeneXpertresult" numeric,
    "XDRResult" text,
    "Bact_status" numeric,
    "Case" numeric,
    "Treatmentreferral" numeric,
    "OLDTYPEOFTBTREATMENT" text,
    "TreatmentRegimen" numeric,
    "Modifiedregimen" text,
    "Placeforreferral" numeric,
    "Ref1" text,
    "CultureDSTresult" text,
    "Microscope_Result_2nd_mnth" text,
    "Xpert_Result_2nd_mnth" text,
    "Microscope_Result_3rd_mnth" text,
    "Xpert_Result_3rd_mnth" text,
    "Microscope_Result_5th_mnth" text,
    "Xpert_Result_5th_mnth" text,
    "EndofTxMicroscopeResult" text,
    "EndofTxXRayResult" text,
    "EndofTxXpertResult" text,
    "TreatmentOutcome1211" text,
    "Tx_Outcome_Date" date,
    "DOTvolName111" text,
    "VolunteerGender111" text,
    "VolunteerOrganization111" text,
    "ContactInvestigation111" text,
    "DOTSupervision111" text,
    "DOTStartedDate111" date,
    "DOTsupervisiontillTreatmentComp111" text,
    "Seeing1" numeric,
    "Hearing1" numeric,
    "Walking1" numeric,
    "Cognition1" numeric,
    "Selfcare1" numeric,
    "Communication1" numeric,
    "Disability1" numeric,
    "Remark" text,
    "MonthDiagnosis11" text,
    "Location11" text,
    "EPI11" text,
    "TB11" text,
    "Xray2ndReading11" numeric,
    "XrayRemark11" text,
    "ReportingTsp11" text,
    "CXRresult211" numeric,
    "XrayEQA11" text,
    "ReportingYear11" integer,
    "TPTregno" text,
    "RegnoofindexTBcase" text,
    "TPTregistrationdate" date,
    "TPTregimen" text,
    "DrugDose" text,
    "Drugpickup1" date,
    "Date_drug_pickup2" date,
    "Date_drug_pickup_3" date,
    "Date_drug_pickup_4" date,
    "Date_drug_pickup_5" date,
    "Date_drug_pickup_6" date,
    "Date_drug_pickup_7" date,
    "Date_drug_pickup_8" date,
    "Date_drug_pickup_9" date,
    "TPTdiscontinuationdate" date,
    "TPTTreatmentOutcome" text,
    "OutcomeDate" date,
    "Recstatus" text,
    "TypeofTBTreatment" numeric,
    "UniqueKey" bigint,
    "InitialStartedDate" date,
    "sync_status" varchar(20) DEFAULT 'pending',
    "last_synced_at" timestamptz,
    "created_by" uuid,
    "updated_by" uuid,
    "updated_at" timestamptz DEFAULT now(),
    CONSTRAINT ygntbpro_pkey PRIMARY KEY ("PatientID")
);

-- Non-destructive ALTER statements to add new DHIS2 & Sync columns to existing Supabase table
ALTER TABLE public.ygntbpro
    ADD COLUMN IF NOT EXISTS "upi" text,
    ADD COLUMN IF NOT EXISTS "index_upi" text,
    ADD COLUMN IF NOT EXISTS "org_unit_id" varchar(64),
    ADD COLUMN IF NOT EXISTS "tracked_entity_instance" text,
    ADD COLUMN IF NOT EXISTS "enrollment_id" text,
    ADD COLUMN IF NOT EXISTS "sync_status" varchar(20) DEFAULT 'pending',
    ADD COLUMN IF NOT EXISTS "last_synced_at" timestamptz,
    ADD COLUMN IF NOT EXISTS "created_by" uuid,
    ADD COLUMN IF NOT EXISTS "updated_by" uuid,
    ADD COLUMN IF NOT EXISTS "updated_at" timestamptz DEFAULT now();

-- ============================================================================
-- 3. PROJECT TARGETS TABLE: public.target
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.target (
    "ReportingDate" date,
    "Team" integer,
    "Tsp" text,
    "Indicator" text,
    "TargetCategory" text,
    "Group" text,
    "Target" real,
    "PatientID" text NOT NULL,
    "org_unit_id" varchar(64),
    "sync_status" varchar(20) DEFAULT 'synced',
    "updated_at" timestamptz DEFAULT now(),
    CONSTRAINT target_pkey PRIMARY KEY ("PatientID")
);

ALTER TABLE public.target
    ADD COLUMN IF NOT EXISTS "org_unit_id" varchar(64),
    ADD COLUMN IF NOT EXISTS "sync_status" varchar(20) DEFAULT 'synced',
    ADD COLUMN IF NOT EXISTS "updated_at" timestamptz DEFAULT now();

-- ============================================================================
-- 4. MULTI-USER COLLABORATION & RLS ROLE TABLE: public.user_roles
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.user_roles (
    user_id uuid NOT NULL,
    email text,
    role public.app_role NOT NULL DEFAULT 'viewer'::public.app_role,
    township_name text DEFAULT 'ALL',         -- Matches "Tsp" or township_org_units.short_tsp
    assigned_team integer,                    -- Matches "Team" (NULL = all teams in township)
    allowed_org_unit_ids text[] DEFAULT '{}', -- Matches DHIS2 org_unit_id
    created_at timestamptz DEFAULT now(),
    CONSTRAINT user_roles_pkey PRIMARY KEY (user_id),
    CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id) ON DELETE CASCADE
);

ALTER TABLE public.user_roles
    ADD COLUMN IF NOT EXISTS email text,
    ADD COLUMN IF NOT EXISTS township_name text DEFAULT 'ALL',
    ADD COLUMN IF NOT EXISTS assigned_team integer,
    ADD COLUMN IF NOT EXISTS allowed_org_unit_ids text[] DEFAULT '{}';

-- ============================================================================
-- 5. AUTOMATIC TIMESTAMP & NOCODB SYNC STATUS TRIGGER
-- ============================================================================
CREATE OR REPLACE FUNCTION public.update_updated_at_and_sync_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    IF TG_OP = 'UPDATE' THEN
        IF OLD.sync_status = 'synced' AND NEW.sync_status = 'synced' THEN
            NEW.sync_status = 'pending';
        END IF;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON public.ygntbpro;
CREATE TRIGGER set_updated_at
BEFORE INSERT OR UPDATE ON public.ygntbpro
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_and_sync_column();

DROP TRIGGER IF EXISTS set_target_updated_at ON public.target;
CREATE TRIGGER set_target_updated_at
BEFORE INSERT OR UPDATE ON public.target
FOR EACH ROW
EXECUTE FUNCTION public.update_updated_at_and_sync_column();

-- ============================================================================
-- 6. FAST FILTER DROPDOWN VIEW & PERFORMANCE INDEXES
-- ============================================================================
CREATE OR REPLACE VIEW public.ygntbpro_filter_options
WITH (security_invoker = true) AS
SELECT
    ARRAY_AGG(DISTINCT "Visit_no"::text ORDER BY "Visit_no"::text) FILTER (WHERE "Visit_no" IS NOT NULL) AS visit_no_list,
    ARRAY_AGG(DISTINCT "Sr_No"::text ORDER BY "Sr_No"::text) FILTER (WHERE "Sr_No" IS NOT NULL) AS sr_no_list,
    ARRAY_AGG(DISTINCT "Team"::text ORDER BY "Team"::text) FILTER (WHERE "Team" IS NOT NULL) AS team_list,
    ARRAY_AGG(DISTINCT "Tsp"::text ORDER BY "Tsp"::text) FILTER (WHERE "Tsp" IS NOT NULL) AS tsp_list,
    ARRAY_AGG(DISTINCT "Approach"::text ORDER BY "Approach"::text) FILTER (WHERE "Approach" IS NOT NULL) AS approach_list,
    ARRAY_AGG(DISTINCT "Case"::text ORDER BY "Case"::text) FILTER (WHERE "Case" IS NOT NULL) AS case_list
FROM public.ygntbpro;

CREATE INDEX IF NOT EXISTS idx_ygntbpro_patientid ON public.ygntbpro ("PatientID");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_upi ON public.ygntbpro ("upi");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_index_upi ON public.ygntbpro ("index_upi");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_org_unit_id ON public.ygntbpro ("org_unit_id");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_date ON public.ygntbpro ("Date");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_tsp ON public.ygntbpro ("Tsp");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_team ON public.ygntbpro ("Team");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_sync_status ON public.ygntbpro ("sync_status");

CREATE INDEX IF NOT EXISTS idx_target_tsp ON public.target ("Tsp");
CREATE INDEX IF NOT EXISTS idx_target_team ON public.target ("Team");
CREATE INDEX IF NOT EXISTS idx_target_date ON public.target ("ReportingDate");
