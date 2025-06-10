-- Line tax
ALTER TABLE ar ADD linetax INTEGER NOT NULL DEFAULT 0;
ALTER TABLE ap ADD linetax INTEGER NOT NULL DEFAULT 0;
ALTER TABLE acc_trans ADD tax_chart_id INTEGER;
ALTER TABLE acc_trans ADD linetaxamount NUMERIC NOT NULL DEFAULT 0;

-- alltaxes report
CREATE TABLE invoicetax (
    trans_id integer NOT NULL,
    invoice_id integer NOT NULL,
    chart_id integer NOT NULL,
    taxamount double precision NOT NULL,
    amount double precision NOT NULL
);

CREATE INDEX idx_invoicetax_trans_id ON invoicetax (trans_id);

