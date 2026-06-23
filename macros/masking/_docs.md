# masking

> **Test environments:** consider using the `anonymizer` instead. The anonymizer shuffles and replaces real data, which makes test data look and behave more realistically. The downside is that it requires more setup per table. Masking is the faster option when you only need to hide data from certain roles, without changing the underlying values.

> **Requires Snowflake Enterprise edition or higher.**
> Tag-based masking policies are not available on Standard edition.

Macros to set up tag-based masking in Snowflake. Columns tagged with a PII tag are automatically masked at query time for roles that are not on the allowlist. No data is modified — masking happens in the query layer.


---

## Setup

Run once after `setup.sql`:

```bash
dbt run-operation create_masking_setup
```

This creates the following tags and masking policies in the `datamodder` schema, and links each policy to its tag.

| Tag | Masked value |
|-----|-------------|
| `pii_name` | `***** *****` |
| `pii_email` | `*****@*****.***` |
| `pii_phone` | `**-********` |
| `pii_address` | `***** ****` |
| `pii_date` | `1900-01-01` |
| `pii` | `*****` / `1900-01-01` / `0` (per data type) |

The `pii` tag supports varchar, date, and number columns. The specific tags (`pii_name`, `pii_email`, etc.) are varchar only.

---

## Configuration

By default, only `SYSADMIN` can see unmasked values. Override via `dbt_project.yml`:

```yaml
vars:
  masking_unmasked_roles:
    - SYSADMIN
    - ANALYST_ROLE
```

---

## Applying tags to columns

```bash
dbt run-operation apply_masking_tag --args '{"table": "mydb.myschema.customers", "column": "email", "tag": "pii_email"}'
```

Or from a dbt macro or model:

```sql
{{ apply_masking_tag('mydb.myschema.customers', 'email', 'pii_email') }}
{{ apply_masking_tag('mydb.myschema.customers', 'naam', 'pii_name') }}
{{ apply_masking_tag('mydb.myschema.customers', 'geboortedatum', 'pii_date') }}
```

---

## How it works

Once a tag is applied to a column, Snowflake enforces the masking policy automatically for every query on that column:

| Role | `SELECT email FROM customers` |
|------|-------------------------------|
| SYSADMIN | `jan@example.com` |
| any other role | `*****@*****.***` |

The masking is transparent to the application — no query changes needed.

---

## Re-running setup

`create_masking_setup` is safe to re-run. Tags are created with `IF NOT EXISTS`. Masking policies use `CREATE OR REPLACE`, which automatically removes the old tag association before the policy is replaced and re-linked.
