# Timestamp format tester

Tests timestamp strings against Snowflake's `TRY_TO_TIMESTAMP_NTZ` and `TRY_TO_TIMESTAMP_TZ` functions to determine which format string (if any) can parse each value. Format groups mirror the `macros/to_timestamp.sql` macro.

## Starting the app

```
streamlit\timestamps\start.cmd
```

Or manually (from the repo root with the venv active):

```
streamlit run streamlit\timestamps\app.py
```

## Connection

Enter your Snowflake account identifier, username and password in the sidebar and click **Connect**. Credentials are saved between sessions: account and username in `~/.streamlit_sources.json`, password in Windows Credential Manager (via the `keyring` package).

After connecting, select a warehouse and role from the dropdowns.

## Format groups

Select which format groups to test in the sidebar. Default groups: **ISO**, **European**, **European (2-digit year)**, **Compact**.

| Group | Example formats |
|---|---|
| ISO | `YYYY-MM-DD HH24:MI:SS`, `YYYY/MM/DD`, `YYYY.MM.DD` |
| European | `DD-MM-YYYY`, `DD/MM/YYYY`, `DD.MM.YYYY` |
| European (2-digit year) | `DD-MM-YY`, `DD/MM/YY`, `DD.MM.YY` |
| US | `MM-DD-YYYY`, `MM/DD/YYYY`, `MM.DD.YYYY` |
| US (2-digit year) | `MM-DD-YY`, `MM/DD/YY` |
| Compact | `YYYYMMDDHH24MISS`, `YYYYMMDD` |
| Oracle | ISO and European formats with FF6 microsecond precision |
| MSSQL | US/EU/ISO formats plus `MON DD YYYY HH12:MI:SSAM` |
| PostgreSQL | ISO subset |
| MySQL / SAP | ISO subset plus compact |
| Month names (DD-MON-YYYY) | `14-Jun-2026`, `14 Jun 2026`, `14/Jun/2026` |
| Month names (MON DD, YYYY) | `Jun 14, 2026`, `Jun-14-2026`, `2026-Jun-14` |

Compact formats (`YYYYMMDD`, `YYYYMMDDHH24MISS`) are always tested first to prevent an 8-digit number from being misread as a Unix epoch by `TRY_TO_TIMESTAMP_TZ`.

## Test values

Enter one timestamp string per line in the text area, or click **Use test values** to load 29 built-in examples covering common real-world formats.

## Running the test

Click **Test** to send all values to Snowflake in a single query. The query evaluates each value against all selected formats in order and returns the first match.

ISO-style values containing a `T` separator or a trailing `Z` are also tested with preprocessing (T → space, Z stripped) as a fallback.

## Results

The results table has three columns:

| Column | Description |
|---|---|
| `value` | The original input string |
| `matched_as` | Format string that first matched, or `null` |
| `result` | Parsed timestamp cast to text |

Rows are green (matched) or red (not matched). Any unmatched values are also shown separately below the table.

## Dependencies

```
pip install streamlit snowflake-connector-python keyring pandas
```

See `requirements.txt` for pinned versions.
