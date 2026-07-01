import streamlit as st
import snowflake.connector
import json
import keyring
import pandas as pd
from pathlib import Path

st.set_page_config(page_title="Timestamp tester", layout="wide")
st.title("Timestamp format tester")

_CONFIG_PATH = Path.home() / ".streamlit_sources.json"
_KEYRING_SVC = "streamlit-dbt-sources"

def _load_config() -> dict:
    try:
        return json.loads(_CONFIG_PATH.read_text(encoding="utf-8")) if _CONFIG_PATH.exists() else {}
    except Exception:
        return {}

def _save_config(account: str, user: str):
    try:
        cfg = _load_config()
        cfg.update({"account": account, "user": user})
        _CONFIG_PATH.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
    except Exception:
        pass

def _load_password(user: str) -> str:
    try:
        return keyring.get_password(_KEYRING_SVC, user) or ""
    except Exception:
        return ""

def _save_password(user: str, password: str):
    try:
        keyring.set_password(_KEYRING_SVC, user, password)
    except Exception:
        pass

# ── Format groups (mirrors to_timestamp.sql) ───────────────────────────────────

_FORMATS: dict[str, list[str]] = {
    "ISO": [
        "YYYY-MM-DD HH24:MI:SS.FF",
        "YYYY-MM-DD HH24:MI:SS",
        "YYYY-MM-DD",
        "YYYY/MM/DD HH24:MI:SS.FF",
        "YYYY/MM/DD HH24:MI:SS",
        "YYYY/MM/DD",
        "YYYY.MM.DD HH24:MI:SS",
        "YYYY.MM.DD",
    ],
    "European": [
        "DD-MM-YYYY HH24:MI:SS.FF",
        "DD-MM-YYYY HH24:MI:SS",
        "DD-MM-YYYY",
        "DD/MM/YYYY HH24:MI:SS.FF",
        "DD/MM/YYYY HH24:MI:SS",
        "DD/MM/YYYY",
        "DD.MM.YYYY HH24:MI:SS.FF",
        "DD.MM.YYYY HH24:MI:SS",
        "DD.MM.YYYY",
    ],
    "European (2-digit year)": [
        "DD-MM-YY HH24:MI:SS",
        "DD-MM-YY",
        "DD/MM/YY",
        "DD.MM.YY",
    ],
    "US": [
        "MM-DD-YYYY HH24:MI:SS.FF",
        "MM-DD-YYYY HH24:MI:SS",
        "MM-DD-YYYY",
        "MM/DD/YYYY HH24:MI:SS.FF",
        "MM/DD/YYYY HH24:MI:SS",
        "MM/DD/YYYY",
        "MM.DD.YYYY HH24:MI:SS",
        "MM.DD.YYYY",
    ],
    "US (2-digit year)": [
        "MM-DD-YY",
        "MM/DD/YY",
    ],
    "Compact": [
        "YYYYMMDDHH24MISS",
        "YYYYMMDD",
    ],
    "Oracle": [
        "YYYY-MM-DD HH24:MI:SS.FF6",
        "YYYY-MM-DD HH24:MI:SS",
        "YYYY-MM-DD",
        "DD/MM/YYYY HH24:MI:SS.FF6",
        "DD/MM/YYYY HH24:MI:SS",
        "DD/MM/YYYY",
        "DD-MM-YYYY HH24:MI:SS.FF6",
        "DD-MM-YYYY HH24:MI:SS",
        "DD-MM-YYYY",
    ],
    "MSSQL": [
        "MM/DD/YYYY HH24:MI:SS.FF",
        "MM/DD/YYYY HH24:MI:SS",
        "MM/DD/YYYY",
        "DD/MM/YYYY HH24:MI:SS.FF",
        "DD/MM/YYYY HH24:MI:SS",
        "DD/MM/YYYY",
        "YYYY-MM-DD HH24:MI:SS.FF",
        "YYYY-MM-DD HH24:MI:SS",
        "YYYY-MM-DD",
        "MON DD YYYY HH12:MIAM",
        "MON DD YYYY HH12:MI:SSAM",
        "MON DD YYYY HH12:MI:SS:FF3AM",
    ],
    "PostgreSQL": [
        "YYYY-MM-DD HH24:MI:SS.FF",
        "YYYY-MM-DD HH24:MI:SS",
        "YYYY-MM-DD",
    ],
    "MySQL / SAP": [
        "YYYY-MM-DD HH24:MI:SS",
        "YYYY-MM-DD",
        "YYYYMMDD",
        "YYYYMMDDHH24MISS",
    ],
    "Month names (DD-MON-YYYY)": [
        "DD-MON-YY HH24:MI:SS",
        "DD-MON-YY",
        "DD MON YY HH24:MI:SS",
        "DD MON YY",
        "DD-MON-YYYY HH24:MI:SS.FF",
        "DD-MON-YYYY HH24:MI:SS",
        "DD-MON-YYYY",
        "DD MON YYYY HH24:MI:SS.FF",
        "DD MON YYYY HH24:MI:SS",
        "DD MON YYYY",
        "DD/MON/YYYY HH24:MI:SS.FF",
        "DD/MON/YYYY HH24:MI:SS",
        "DD/MON/YYYY",
        "DD.MON.YYYY HH24:MI:SS",
        "DD.MON.YYYY",
    ],
    "Month names (MON DD, YYYY)": [
        "MON DD, YY",
        "MON DD YY",
        "MON DD, YYYY HH24:MI:SS.FF",
        "MON DD, YYYY HH24:MI:SS",
        "MON DD, YYYY",
        "MON DD YYYY HH24:MI:SS.FF",
        "MON DD YYYY HH24:MI:SS",
        "MON DD YYYY",
        "MON-DD-YYYY HH24:MI:SS.FF",
        "MON-DD-YYYY HH24:MI:SS",
        "MON-DD-YYYY",
        "MON/DD/YYYY HH24:MI:SS",
        "MON/DD/YYYY",
        "YYYY-MON-DD HH24:MI:SS",
        "YYYY-MON-DD",
    ],
}

# Built-in test values (subset from _data.sql)
_TEST_VALUES = [
    "2026-06-14 16:00:00",
    "2026-06-14T16:00:00",
    "2026-06-14T16:00:00Z",
    "2026-06-14",
    "2026/06/14 16:00:00",
    "2026.06.14",
    "14-06-2026 16:00:00",
    "14/06/2026",
    "14.06.2026",
    "14-06-26",
    "06/14/2026 16:00:00",
    "06-14-2026",
    "20260614",
    "20260614160000",
    "2026-06-14 16:00:00.123456",
    "14 Jun 2026 16:00:00",
    "14 June 2026",
    "June 14, 2026",
    "Jun 14 2026",
    "Jun-14-2026",
    "14-Jun-2026",
    "14-Jun-26",
    "2026-Jun-14",
    "2024-02-29 11:00:00",
    "29-02-2024",
    "02/29/2024",
    "1936-01-01 23:00:00",
    "01-01-1936",
    "19360101",
]

# ── Credential helpers ─────────────────────────────────────────────────────────

if "creds_loaded" not in st.session_state:
    cfg = _load_config()
    saved_user = cfg.get("user", "")
    st.session_state["input_account"]  = cfg.get("account", "")
    st.session_state["input_user"]     = saved_user
    st.session_state["input_password"] = _load_password(saved_user) if saved_user else ""
    st.session_state["creds_loaded"]   = True

# ── Sidebar ────────────────────────────────────────────────────────────────────

with st.sidebar:
    st.header("Snowflake")
    account  = st.text_input("Account",  key="input_account",  placeholder="xy12345.eu-west-1")
    user     = st.text_input("User",     key="input_user")
    password = st.text_input("Password", key="input_password", type="password")

    if st.button("Connect", width="stretch"):
        try:
            conn = snowflake.connector.connect(
                account=account, user=user, password=password
            )
            for key in list(st.session_state):
                if key not in ("input_account", "input_user", "input_password", "creds_loaded"):
                    del st.session_state[key]
            st.session_state["conn"] = conn

            cur = conn.cursor()
            cur.execute("show warehouses")
            warehouses = [r[0] for r in cur.fetchall()]
            cur.execute("show roles")
            roles = sorted([r[1] for r in cur.fetchall()])
            cur.execute("select current_role(), current_warehouse()")
            row = cur.fetchone()
            current_role = row[0]
            current_wh   = row[1] or (warehouses[0] if warehouses else None)
            if current_wh:
                cur.execute(f'use warehouse "{current_wh}"')

            st.session_state["warehouses"]   = warehouses
            st.session_state["roles"]        = roles
            st.session_state["current_wh"]   = current_wh
            st.session_state["current_role"] = current_role

            _save_config(account, user)
            _save_password(user, password)
            st.success("Connected")
        except Exception as e:
            st.error(str(e))
            st.session_state.pop("conn", None)

    if "conn" in st.session_state and "warehouses" in st.session_state:
        st.divider()

        def on_warehouse_change():
            st.session_state["conn"].cursor().execute(
                f'use warehouse "{st.session_state["sel_wh"]}"')

        def on_role_change():
            st.session_state["conn"].cursor().execute(
                f'use role "{st.session_state["sel_role"]}"')

        whs  = st.session_state["warehouses"]
        rols = st.session_state["roles"]
        wh_idx   = whs.index(st.session_state["current_wh"])   if st.session_state.get("current_wh")   in whs  else 0
        role_idx = rols.index(st.session_state["current_role"]) if st.session_state.get("current_role") in rols else 0

        st.selectbox("Warehouse", whs,  index=wh_idx,   key="sel_wh",   on_change=on_warehouse_change)
        st.selectbox("Role",      rols, index=role_idx, key="sel_role", on_change=on_role_change)

        st.divider()
        st.caption("Format groups")
        selected_groups = []
        default_on = {"ISO", "European", "European (2-digit year)", "Compact"}
        for group in _FORMATS:
            if st.checkbox(group, value=(group in default_on), key=f"grp_{group}"):
                selected_groups.append(group)

# ── Main ───────────────────────────────────────────────────────────────────────

conn = st.session_state.get("conn")
if conn is None:
    st.info("Connect to Snowflake in the sidebar to get started.")
    st.stop()

# ── Input ──────────────────────────────────────────────────────────────────────

col_in, col_btn = st.columns([5, 1])
with col_in:
    raw_input = st.text_area(
        "Values (one per line)",
        height=200,
        placeholder="2026-06-14 16:00:00\n14/06/2026\n20260614",
        key="ts_input"
    )
with col_btn:
    st.write("")
    st.write("")
    if st.button("Use test\nvalues", width="stretch"):
        st.session_state["ts_input"] = "\n".join(_TEST_VALUES)
        st.rerun()

values = [v.strip() for v in st.session_state.get("ts_input", "").splitlines() if v.strip()]

if not values:
    st.stop()

selected_groups = [g for g in _FORMATS if st.session_state.get(f"grp_{g}", g in {"ISO", "European", "European (2-digit year)", "Compact"})]
if not selected_groups:
    st.warning("Select at least one format group.")
    st.stop()

# Build deduplicated format list (compact first to avoid YYYYMMDD being read as Unix timestamp)
seen: set[str] = set()
formats: list[str] = []
compact_fmts = _FORMATS.get("Compact", []) + _FORMATS.get("MySQL / SAP", [])

for fmt in compact_fmts:
    if "Compact" in selected_groups or "MySQL / SAP" in selected_groups:
        if fmt not in seen:
            seen.add(fmt)
            formats.append(fmt)

for grp in selected_groups:
    for fmt in _FORMATS[grp]:
        if fmt not in seen:
            seen.add(fmt)
            formats.append(fmt)

if st.button("Test", type="primary"):
    # Build VALUES clause
    escaped = [v.replace("'", "''") for v in values]
    vals_sql = ", ".join(f"('{v}')" for v in escaped)

    # CASE: which format matched first?
    whens = [
        "when try_to_timestamp_tz(v) is not null then 'auto (try_to_timestamp_tz)'"
    ]
    coalesce_parts = ["try_to_timestamp_tz(v)"]

    for fmt in formats:
        whens.append(
            f"when try_to_timestamp_ntz(v, '{fmt}') is not null then '{fmt}'"
        )
        coalesce_parts.append(f"try_to_timestamp_ntz(v, '{fmt}')")

    # Also test with T→space and Z-strip preprocessing
    iso_fmts = ["YYYY-MM-DD HH24:MI:SS.FF", "YYYY-MM-DD HH24:MI:SS"]
    for fmt in iso_fmts:
        whens.append(
            f"when try_to_timestamp_ntz(replace(v, 'T', ' '), '{fmt}') is not null "
            f"then '{fmt} (after T→space)'"
        )
        coalesce_parts.append(f"try_to_timestamp_ntz(replace(v, 'T', ' '), '{fmt}')")
        whens.append(
            f"when try_to_timestamp_ntz(replace(replace(v, 'T', ' '), 'Z', ''), '{fmt}') is not null "
            f"then '{fmt} (after T→space, Z-strip)'"
        )
        coalesce_parts.append(
            f"try_to_timestamp_ntz(replace(replace(v, 'T', ' '), 'Z', ''), '{fmt}')"
        )

    case_sql     = " ".join(whens)
    coalesce_sql = "\n         , ".join(coalesce_parts)

    sql = f"""
with vals as (select column1::text as v from values {vals_sql})
select v                                            as value
     , case when {case_sql} else null end           as matched_as
     , coalesce({coalesce_sql})::text               as result
from vals
"""
    try:
        with st.spinner("Testing..."):
            cur = conn.cursor()
            cur.execute(sql)
            rows = cur.fetchall()
        st.session_state["ts_results"] = rows
    except Exception as e:
        st.error(str(e))

# ── Results ────────────────────────────────────────────────────────────────────

if "ts_results" in st.session_state:
    rows = st.session_state["ts_results"]
    df = pd.DataFrame(rows, columns=["value", "matched_as", "result"])

    matched   = df["matched_as"].notna().sum()
    unmatched = df["matched_as"].isna().sum()
    st.caption(f"{matched} matched · {unmatched} not matched")

    def _color(row):
        if pd.isna(row["matched_as"]):
            return ["background-color: #f8d7da"] * 3
        return ["background-color: #d1e7dd"] * 3

    styled = df.style.apply(_color, axis=1)
    st.dataframe(styled, width="stretch", hide_index=True)

    if unmatched > 0:
        st.subheader("Not matched")
        st.dataframe(
            df[df["matched_as"].isna()][["value"]],
            width="stretch", hide_index=True
        )
