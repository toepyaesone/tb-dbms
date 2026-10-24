
CREATE TABLE public.ygntbpro (
  Date date,
  Team integer,
  StateRegionName text,
  Tsp text,
  WardVillage text,
  WardCode text,
  Approach text,
  Visit_no integer,
  Sr_No integer,
  ReportingPeriod text,
  RegistrarDate date,
  TownshipTBRegNumber text,
  PatientID text NOT NULL UNIQUE,
  Name text,
  Nationality text,
  Age integer,
  Sex integer,
  Address text,
  Ptstsp text,
  PhoneNo text,
  Origin integer,
  VOL integer,
  Referralfor numeric,
  VolunteerName text,
  Organization text,
  Cough integer,
  Fever integer,
  Wtloss integer,
  Nightsweat integer,
  Haemoptysis integer,
  Chestpain integer,
  Fatigue integer,
  Neckglands integer,
  TBcontact integer,
  MDRTBcontact integer,
  TBTreatmenthistory integer,
  Transferin text,
  TypeofPatients text,
  TypeofDisease text,
  SpecifyifEPSiteofEPTB text,
  Smoking integer,
  Reasonforexamination numeric,
  TypeofPatient numeric,
  PublicHealthCare1 integer,
  TypeofPatient1 integer,
  DM1 integer,
  RBS numeric,
  HbA1c numeric,
  HT1 integer,
  Systolic numeric,
  Diastolic numeric,
  DMHT1 numeric,
  RTIAVI1 numeric,
  Generalweakness1 numeric,
  Other1 text,
  HIVStatus text,
  CPT date,
  ART date,
  Cxrr numeric,
  CXRresult numeric,
  Cxr_others text,
  Sputum_request numeric,
  Micror numeric,
  Sputummicroscopyresult numeric,
  Genexpertrequested numeric,
  GeneXpertresult numeric,
  XDRResult text,
  Bact_status numeric,
  Case numeric,
  Treatmentreferral numeric,
  OLDTYPEOFTBTREATMENT text,
  TreatmentRegimen numeric,
  Modifiedregimen text,
  Placeforreferral numeric,
  Ref1 text,
  CultureDSTresult text,
  Microscope_Result_2nd_mnth text,
  Xpert_Result_2nd_mnth text,
  Microscope_Result_3rd_mnth text,
  Xpert_Result_3rd_mnth text,
  Microscope_Result_5th_mnth text,
  Xpert_Result_5th_mnth text,
  EndofTxMicroscopeResult text,
  EndofTxXRayResult text,
  EndofTxXpertResult text,
  TreatmentOutcome1211 text,
  Tx_Outcome_Date date,
  DOTvolName111 text,
  VolunteerGender111 text,
  VolunteerOrganization111 text,
  ContactInvestigation111 text,
  DOTSupervision111 text,
  DOTStartedDate111 date,
  DOTsupervisiontillTreatmentComp111 text,
  Seeing1 numeric,
  Hearing1 numeric,
  Walking1 numeric,
  Cognition1 numeric,
  Selfcare1 numeric,
  Communication1 numeric,
  Disability1 numeric,
  Remark text,
  MonthDiagnosis11 text,
  Location11 text,
  EPI11 text,
  TB11 text,
  Xray2ndReading11 numeric,
  XrayRemark11 text,
  ReportingTsp11 text,
  CXRresult211 numeric,
  XrayEQA11 text,
  ReportingYear11 integer,
  TPTregno text,
  RegnoofindexTBcase text,
  TPTregistrationdate date,
  TPTregimen text,
  DrugDose text,
  Drugpickup1 date,
  Date_drug_pickup2 date,
  Date_drug_pickup_3 date,
  Date_drug_pickup_4 date,
  Date_drug_pickup_5 date,
  Date_drug_pickup_6 date,
  Date_drug_pickup_7 date,
  Date_drug_pickup_8 date,
  Date_drug_pickup_9 date,
  TPTdiscontinuationdate date,
  TPTTreatmentOutcome text,
  OutcomeDate date,
  Recstatus text,
  TypeofTBTreatment numeric,
  UniqueKey bigint,
  InitialStartedDate date,
  updated_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ygntbpro_pkey PRIMARY KEY (PatientID)
);
CREATE TABLE public.target (
  ReportingDate date,
  Team integer,
  Tsp text,
  Indicator text,
  TargetCategory text,
  Group text,
  Target real,
  PatientID text NOT NULL,
  CONSTRAINT target_pkey PRIMARY KEY (PatientID)
);
CREATE TABLE public.user_roles (
  user_id uuid NOT NULL,
  role USER-DEFINED NOT NULL DEFAULT 'viewer'::app_role,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT user_roles_pkey PRIMARY KEY (user_id),
  CONSTRAINT user_roles_user_id_fkey FOREIGN KEY (user_id) REFERENCES auth.users(id)
);

ALTER TABLE public."ygntbpro" 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();

CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
   IF (TG_OP = 'UPDATE' OR TG_OP = 'INSERT') THEN
      NEW.updated_at = NOW();
      RETURN NEW;
   END IF;
   RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS set_updated_at ON public."ygntbpro";

CREATE TRIGGER set_updated_at
BEFORE UPDATE ON public."ygntbpro"
FOR EACH ROW
EXECUTE FUNCTION update_updated_at_column();

-- Create a fast lookup view for distinct filter dropdown values
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

-- Add indexes on frequently filtered and sorted columns for instant server-side pagination
CREATE INDEX IF NOT EXISTS idx_ygntbpro_patientid ON public.ygntbpro ("PatientID");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_date ON public.ygntbpro ("Date");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_tsp ON public.ygntbpro ("Tsp");
CREATE INDEX IF NOT EXISTS idx_ygntbpro_team ON public.ygntbpro ("Team");