import streamlit as st
import snowflake.connector
import json
import keyring
import pandas as pd
from pathlib import Path

st.set_page_config(page_title="Analyze", layout="wide")
st.title("Analyze")

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

            cur.execute("show databases")
            all_dbs = [r[1] for r in cur.fetchall()]

            st.session_state["warehouses"]   = warehouses
            st.session_state["roles"]        = roles
            st.session_state["current_wh"]   = current_wh
            st.session_state["current_role"] = current_role
            st.session_state["databases"]    = all_dbs

            _save_config(account, user)
            _save_password(user, password)
            st.success("Connected")
        except Exception as e:
            st.error(str(e))
            st.session_state.pop("conn", None)

    if "conn" in st.session_state and "warehouses" in st.session_state:
        st.divider()

        def _clear_cache():
            for key in [k for k in st.session_state
                        if k.startswith(("src_schemas_", "src_tables_", "pits_"))]:
                del st.session_state[key]

        def on_warehouse_change():
            st.session_state["conn"].cursor().execute(
                f'use warehouse "{st.session_state["sel_wh"]}"')
            _clear_cache()

        def on_role_change():
            st.session_state["conn"].cursor().execute(
                f'use role "{st.session_state["sel_role"]}"')
            _clear_cache()

        whs  = st.session_state["warehouses"]
        rols = st.session_state["roles"]
        wh_idx   = whs.index(st.session_state["current_wh"])   if st.session_state.get("current_wh")   in whs  else 0
        role_idx = rols.index(st.session_state["current_role"]) if st.session_state.get("current_role") in rols else 0

        st.selectbox("Warehouse", whs,  index=wh_idx,   key="sel_wh",   on_change=on_warehouse_change)
        st.selectbox("Role",      rols, index=role_idx, key="sel_role", on_change=on_role_change)

        st.divider()
        st.caption("Target")
        target_db  = st.text_input("Database",    value="datamodder",  key="target_db")
        pit_schema = st.text_input("PIT schema",  value="analyze",     key="pit_schema")
        agg_schema = st.text_input("Agg schema",  value="analyzer_agg", key="agg_schema")

        st.divider()
        st.caption("Source")
        dbs = st.session_state.get("databases", [])
        src_db = st.selectbox("Database", dbs, key="src_db")

        src_schemas_key = f"src_schemas_{src_db}"
        if src_schemas_key not in st.session_state:
            try:
                cur2 = st.session_state["conn"].cursor()
                cur2.execute(f"show schemas in database {src_db}")
                st.session_state[src_schemas_key] = [
                    r[1] for r in cur2.fetchall() if r[1].upper() != "INFORMATION_SCHEMA"
                ]
            except Exception:
                st.session_state[src_schemas_key] = []
        src_schemas = st.session_state[src_schemas_key]
        src_schema = st.selectbox("Schema", src_schemas, key="src_schema")

        if src_schema:
            src_tables_key = f"src_tables_{src_db}_{src_schema}"
            if src_tables_key not in st.session_state:
                try:
                    cur3 = st.session_state["conn"].cursor()
                    cur3.execute(
                        f"select table_name from {src_db}.information_schema.tables "
                        f"where lower(table_schema) = lower('{src_schema}') "
                        f"and table_type = 'BASE TABLE' order by table_name"
                    )
                    st.session_state[src_tables_key] = [r[0] for r in cur3.fetchall()]
                except Exception:
                    st.session_state[src_tables_key] = []
            src_tables = st.session_state[src_tables_key]
            src_table = st.selectbox("Table", src_tables, key="src_table")
        else:
            src_table = None

# ── Main ───────────────────────────────────────────────────────────────────────

conn = st.session_state.get("conn")
if conn is None:
    st.info("Connect to Snowflake in the sidebar to get started.")
    st.stop()
target_db  = st.session_state.get("target_db",  "datamodder")
pit_schema = st.session_state.get("pit_schema", "analyze")
agg_schema = st.session_state.get("agg_schema", "analyzer_agg")

def run(sql: str) -> list:
    cur = conn.cursor()
    cur.execute(sql)
    return cur.fetchall()

def set_session_vars():
    cur = conn.cursor()
    cur.execute(f"set target_db_name = '{target_db}'")
    cur.execute(f"set pit_schema_name = '{pit_schema}'")
    cur.execute(f"set agg_schema_name = '{agg_schema}'")
    return cur

# ── Actions ────────────────────────────────────────────────────────────────────

col1, col2, col3 = st.columns(3)

with col1:
    src_db_val     = st.session_state.get("src_db", "")
    src_schema_val = st.session_state.get("src_schema", "")
    src_table_val  = st.session_state.get("src_table", "")
    can_create = bool(src_db_val and src_schema_val and src_table_val)

    if st.button("Create PIT", width="stretch", disabled=not can_create,
                 help=f"{src_db_val}.{src_schema_val}.{src_table_val}"):
        try:
            cur = set_session_vars()
            cur.execute(
                f"call {target_db}.{pit_schema}.create_pit("
                f"'{src_db_val}', '{src_schema_val}', '{src_table_val}')"
            )
            st.success(f"PIT created for {src_table_val}")
            for key in [k for k in st.session_state if k.startswith("pits_")]:
                del st.session_state[key]
        except Exception as e:
            st.error(str(e))

with col2:
    if st.button("Register PITs", width="stretch"):
        try:
            cur = set_session_vars()
            cur.execute(f"call {target_db}.{pit_schema}.register_pits()")
            st.success("PITs registered")
        except Exception as e:
            st.error(str(e))

with col3:
    if st.button("Update statistics", width="stretch"):
        try:
            cur = set_session_vars()
            cur.execute(f"call {target_db}.{pit_schema}.update_statistics()")
            st.success("Statistics updated")
        except Exception as e:
            st.error(str(e))

st.divider()

# ── PIT list ───────────────────────────────────────────────────────────────────

pits_key = f"pits_{target_db}_{pit_schema}"
if pits_key not in st.session_state:
    try:
        rows = run(
            f"select table_name, created "
            f"from {target_db}.information_schema.tables "
            f"where lower(table_schema) = lower('{pit_schema}') "
            f"and regexp_like(table_name, '.*_[0-9]{{8}}_[0-9]{{6}}$') "
            f"order by created desc"
        )
        st.session_state[pits_key] = rows
    except Exception:
        st.session_state[pits_key] = []

pits = st.session_state[pits_key]

if not pits:
    st.info("No PITs found. Select a source table and click Create PIT.")
    st.stop()

pit_names = [r[0] for r in pits]
selected_pit = st.selectbox(
    f"PIT  ({len(pit_names)} available)",
    pit_names,
    format_func=lambda n: f"{n}  ({next(r[1] for r in pits if r[0] == n)})"
)

if st.button("Refresh PIT list"):
    del st.session_state[pits_key]
    st.rerun()

# ── Statistics ─────────────────────────────────────────────────────────────────

st.subheader(f"Statistics — {selected_pit}")

stats_key = f"stats_{target_db}_{agg_schema}_{selected_pit}"
if stats_key not in st.session_state:
    try:
        st.session_state[stats_key] = run(
            f"select col_nr, col_name, stat_ts, null_count, distinct_count, "
            f"       min_val, max_val, under_min_count, above_max_count "
            f"from {target_db}.{agg_schema}.statistics "
            f"where pit_name = '{selected_pit}' "
            f"order by col_nr"
        )
    except Exception as e:
        st.warning(f"No statistics available: {e}")
        st.session_state[stats_key] = []

rows = st.session_state.get(stats_key, [])
if not rows:
    st.info("No statistics for this PIT. Click Register PITs and Update statistics.")
    st.stop()

df = pd.DataFrame(rows, columns=[
    "col_nr", "col_name", "stat_ts",
    "null_count", "distinct_count",
    "min_val", "max_val",
    "under_min_count", "above_max_count"
])

def _color_row(row):
    styles = [""] * len(row)
    idx = list(row.index)
    if row.get("null_count", 0) and row["null_count"] > 0:
        styles[idx.index("null_count")] = "background-color: #fff3cd"
    if row.get("under_min_count", 0) and row["under_min_count"] > 0:
        styles[idx.index("under_min_count")] = "background-color: #f8d7da"
    if row.get("above_max_count", 0) and row["above_max_count"] > 0:
        styles[idx.index("above_max_count")] = "background-color: #f8d7da"
    return styles

styled = df.style.apply(_color_row, axis=1)
st.dataframe(styled, width="stretch", hide_index=True)

if st.button("Refresh statistics"):
    del st.session_state[stats_key]
    st.rerun()
