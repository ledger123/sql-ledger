-- ============================================================== 
-- RMA SCHEMA UPGRADE TO SQL-LEDGER 3.2.12 
-- --------------------------------------------------------------
--  PART A — CHANGE REPORT
--  ----------------------
--  NEW TABLES (16)
--    acsrole, archive, archivedata, deduct, deduction,
--    deductionrate, employeededuction, employeewage, mimetype,
--    pay_trans, payrate, reference, wage  + helper sequences
--    (archiveid, referenceid, acsrole_id_seq, wage_id_seq)
--
--  COLUMNS ADDED TO EXISTING TABLES
--    bank.clearingnumber
--    business.rn
--    chart.closed
--    curr.prec               (rn now SMALLINT)
--    customer.prepayment_accno_id
--    department.rn
--    employee.payperiod, apid, paymentid, paymentmethod_id,
--             acsrole_id, acs
--    exchangerate.exchangerate
--    invoice.cost, vendor, vendor_id, kititem
--    orderitems.cost, vendor, vendor_id
--    oe.backorder
--    parts.lot, expires, checkinventory
--    paymentmethod.roundchange
--    vendor.prepayment_accno_id
--    warehouse.rn
--    shipto.shiptorecurring
--
--  TYPE / CONSTRAINT CHANGES
--    acc_trans.chart_id       NOT NULL → NULLABLE
--    curr.rn                  integer → smallint
--
--  NEW INDEXES (on new tables)
--    archivedata_archive_id_idx, deduct_trans_idx,
--    employeededuction_emp_idx, employeewage_emp_idx,
--    reference_code_idx, wage_chart_idx
--
--  NEW FOREIGN KEYS
--    archivedata.archive_id → archive.id   (CASCADE)
--    reference.archive_id  → archive.id   (CASCADE)
--    employee.acsrole_id   → acsrole.id   (SET NULL)
--
--  NOTHING IS DROPPED.  Objects that existed only in the old
--  schema stay exactly as they are.
-- --------------------------------------------------------------
--
--  PART B — EXECUTABLE DDL
--  -----------------------
--  • Safe to run more than once (IF [NOT] EXISTS everywhere).
--  • Adds sequences / tables / columns / indexes / FK links.
--  • Never drops or renames legacy objects.
-- ==============================================================


/* ---------- 1. New SEQUENCES ---------- */
CREATE SEQUENCE IF NOT EXISTS archiveid   START 1;
CREATE SEQUENCE IF NOT EXISTS referenceid START 1;
CREATE SEQUENCE IF NOT EXISTS acsrole_id_seq START 10000;
CREATE SEQUENCE IF NOT EXISTS wage_id_seq    START 10000;

/* ---------- 2. New TABLES ---------- */
CREATE TABLE IF NOT EXISTS acsrole (
    id          integer DEFAULT nextval('acsrole_id_seq') PRIMARY KEY,
    description text,
    acs         text,
    rn          smallint
);

CREATE TABLE IF NOT EXISTS archive (
    id       integer DEFAULT nextval('archiveid') PRIMARY KEY,
    filename text
);

CREATE TABLE IF NOT EXISTS archivedata (
    archive_id integer REFERENCES archive(id) ON DELETE CASCADE,
    bt         text,
    rn         integer
);

CREATE TABLE IF NOT EXISTS deduct (
    trans_id      integer,
    deduction_id  integer,
    withholding   boolean,
    percent       real
);

CREATE TABLE IF NOT EXISTS deduction (
    id                integer DEFAULT nextval('id') PRIMARY KEY,
    description       text,
    employee_accno_id integer,
    employeepays      real,
    employer_accno_id integer,
    employerpays      real,
    fromage           smallint,
    toage             smallint,
    agedob            boolean,
    basedon           integer
);

CREATE TABLE IF NOT EXISTS deductionrate (
    rn        smallint,
    trans_id  integer,
    rate      double precision,
    amount    double precision,
    above     double precision,
    below     double precision
);

CREATE TABLE IF NOT EXISTS employeededuction (
    id            integer,
    employee_id   integer,
    deduction_id  integer,
    exempt        double precision,
    maximum       double precision
);

CREATE TABLE IF NOT EXISTS employeewage (
    id          integer,
    employee_id integer,
    wage_id     integer
);

CREATE TABLE IF NOT EXISTS mimetype (
    extension    varchar(32)  PRIMARY KEY,
    contenttype  varchar(64)
);

CREATE TABLE IF NOT EXISTS pay_trans (
    trans_id integer,
    id       integer,
    glid     integer,
    qty      double precision,
    amount   double precision
);

CREATE TABLE IF NOT EXISTS payrate (
    trans_id integer,
    id       integer,
    rate     double precision,
    above    double precision
);

CREATE TABLE IF NOT EXISTS reference (
    id          integer DEFAULT nextval('referenceid') PRIMARY KEY,
    code        text,
    trans_id    integer,
    description text,
    archive_id  integer REFERENCES archive(id) ON DELETE CASCADE,
    login       text,
    formname    text,
    folder      text
);

CREATE TABLE IF NOT EXISTS wage (
    id          integer DEFAULT nextval('wage_id_seq') PRIMARY KEY,
    description text,
    amount      double precision,
    defer       integer,
    exempt      boolean DEFAULT false,
    chart_id    integer
);

/* ---------- 3. ALTER existing TABLES – add / change columns ---------- */

/* 3.1 acc_trans: relax NOT NULL on chart_id if still present */
DO $$BEGIN
  IF EXISTS (SELECT 1
               FROM information_schema.columns
              WHERE table_schema = current_schema
                AND table_name   = 'acc_trans'
                AND column_name  = 'chart_id'
                AND is_nullable  = 'NO') THEN
      ALTER TABLE acc_trans ALTER COLUMN chart_id DROP NOT NULL;
  END IF;
END$$;

/* 3.2 bank */
ALTER TABLE bank
    ADD COLUMN IF NOT EXISTS clearingnumber text;

/* 3.3 business */
ALTER TABLE business
    ADD COLUMN IF NOT EXISTS rn integer;

/* 3.4 chart */
ALTER TABLE chart
    ADD COLUMN IF NOT EXISTS closed boolean DEFAULT false;

/* 3.5 curr */
ALTER TABLE curr
    ADD COLUMN IF NOT EXISTS prec smallint;
ALTER TABLE curr
    ALTER COLUMN rn TYPE smallint;

/* 3.6 customer */
ALTER TABLE customer
    ADD COLUMN IF NOT EXISTS prepayment_accno_id integer;

/* 3.7 department */
ALTER TABLE department
    ADD COLUMN IF NOT EXISTS rn integer;

/* 3.8 employee */
ALTER TABLE employee
    ADD COLUMN IF NOT EXISTS payperiod        smallint,
    ADD COLUMN IF NOT EXISTS apid             integer,
    ADD COLUMN IF NOT EXISTS paymentid        integer,
    ADD COLUMN IF NOT EXISTS paymentmethod_id integer,
    ADD COLUMN IF NOT EXISTS acsrole_id       integer,
    ADD COLUMN IF NOT EXISTS acs              text;

/* 3.9 exchangerate */
ALTER TABLE exchangerate
    ADD COLUMN IF NOT EXISTS exchangerate double precision;

/* 3.10 invoice */
ALTER TABLE invoice
    ADD COLUMN IF NOT EXISTS cost      double precision,
    ADD COLUMN IF NOT EXISTS vendor    text,
    ADD COLUMN IF NOT EXISTS vendor_id integer,
    ADD COLUMN IF NOT EXISTS kititem   boolean DEFAULT false;

/* 3.11 orderitems */
ALTER TABLE orderitems
    ADD COLUMN IF NOT EXISTS cost      double precision,
    ADD COLUMN IF NOT EXISTS vendor    text,
    ADD COLUMN IF NOT EXISTS vendor_id integer;

/* 3.12 oe */
ALTER TABLE oe
    ADD COLUMN IF NOT EXISTS backorder boolean DEFAULT false;

/* 3.13 parts */
ALTER TABLE parts
    ADD COLUMN IF NOT EXISTS lot            text,
    ADD COLUMN IF NOT EXISTS expires        date,
    ADD COLUMN IF NOT EXISTS checkinventory boolean DEFAULT false;

/* 3.14 paymentmethod */
ALTER TABLE paymentmethod
    ADD COLUMN IF NOT EXISTS roundchange real;

/* 3.15 vendor */
ALTER TABLE vendor
    ADD COLUMN IF NOT EXISTS prepayment_accno_id integer;

/* 3.16 warehouse */
ALTER TABLE warehouse
    ADD COLUMN IF NOT EXISTS rn integer;

/* 3.17 shipto */
ALTER TABLE shipto
    ADD COLUMN IF NOT EXISTS shiptorecurring boolean DEFAULT false;

/* ---------- 4. New INDEXES ---------- */
CREATE INDEX IF NOT EXISTS archivedata_archive_id_idx  ON archivedata(archive_id);
CREATE INDEX IF NOT EXISTS deduct_trans_idx            ON deduct(trans_id);
CREATE INDEX IF NOT EXISTS employeededuction_emp_idx   ON employeededuction(employee_id);
CREATE INDEX IF NOT EXISTS employeewage_emp_idx        ON employeewage(employee_id);
CREATE INDEX IF NOT EXISTS reference_code_idx          ON reference(code);
CREATE INDEX IF NOT EXISTS wage_chart_idx              ON wage(chart_id);

/* ---------- 5. Foreign‑key helper link ---------- */
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
          FROM pg_constraint
         WHERE conname = 'employee_acsrole_fkey'
    ) THEN
        ALTER TABLE employee
            ADD CONSTRAINT employee_acsrole_fkey
            FOREIGN KEY (acsrole_id)
            REFERENCES acsrole(id)
            ON DELETE SET NULL;
    END IF;
END$$;

UPDATE defaults SET fldvalue='3.2.4' WHERE fldname='version';

/* =======================  END OF SCRIPT  ======================= */

