-- Line tax
ALTER TABLE ar ADD linetax INTEGER NOT NULL DEFAULT 0;
ALTER TABLE acc_trans ADD tax_chart_id INTEGER;
ALTER TABLE acc_trans ADD linetaxamount NUMERIC NOT NULL DEFAULT 0;

