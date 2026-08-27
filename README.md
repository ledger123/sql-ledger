# SQL-Ledger

A maintenance continuation of [SQL-Ledger](https://sql-ledger.com) ERP, the
double-entry accounting and ERP system written by Dieter Simader of DWS
Systems.

Upstream's last release, **3.2.12**, was published on 2023-01-03. The first
commit of this repository is that release, extracted unmodified, so anything
that follows can be read as a diff against untouched upstream:

    git diff b682ff1..HEAD

## Intent

Stability first. This is bookkeeping software that people close their books
with, so the working rule is that an upgrade must never surprise anyone:
fixes over features, no gratuitous refactoring, no schema change without an
upgrade script, and nothing merged that has not been exercised on a real
dataset.

## What it is

Plain Perl 5 CGI, no build step, no dependency manager. PostgreSQL via
DBI/DBD::Pg. Requests go from a root dispatcher (`ar.pl`, `gl.pl`, ...) to a
UI module under `bin/mozilla/` to an `SL/*.pm` module holding the SQL.

Install by copying `sql-ledger.conf.default` to `sql-ledger.conf`, pointing a
CGI-enabled Apache directory at the tree, and creating a dataset through
`admin.pl`. **`admin.pl` on a fresh install has no password and grants
dataset create and drop to any visitor — deny it at the web-server level
until a password is set.**
