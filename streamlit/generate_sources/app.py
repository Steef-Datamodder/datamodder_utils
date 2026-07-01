import streamlit as st
import snowflake.connector
import json
import keyring
from pathlib import Path
from collections import defaultdict

try:
    import tkinter as tk
    from tkinter import filedialog
    _HAS_TK = True
except ImportError:
    _HAS_TK = False

st.set_page_config(page_title="dbt Sources Generator", layout="wide")
st.title("dbt Sources Generator")

_CONFIG_PATH = Path.home() / ".streamlit_sources.json"
_KEYRING_SVC = "streamlit-dbt-sources"

def _load_config() -> dict:
    try:
        return json.loads(_CONFIG_PATH.read_text(encoding="utf-8")) if _CONFIG_PATH.exists() else {}
    except Exception:
        return {}

def _save_config(account: str, user: str, dbt_path: str = ""):
    try:
        cfg = _load_config()
        cfg.update({"account": account, "user": user})
        if dbt_path:
            cfg["dbt_path"] = dbt_path
        _CONFIG_PATH.write_text(json.dumps(cfg, indent=2), encoding="utf-8")
    except Exception:
        pass

def _save_password(user: str, password: str):
    try:
        keyring.set_password(_KEYRING_SVC, user, password)
    except Exception:
        pass

def _load_password(user: str) -> str:
    try:
        return keyring.get_password(_KEYRING_SVC, user) or ""
    except Exception:
        return ""

def _browse_folder():
    root = tk.Tk()
    root.withdraw()
    root.attributes("-topmost", True)
    folder = filedialog.askdirectory(title="Select dbt project folder")
    root.destroy()
    if folder:
        st.session_state["input_dbt_path"] = folder

if "creds_loaded" not in st.session_state:
    cfg = _load_config()
    saved_user = cfg.get("user", "")
    st.session_state["input_account"]  = cfg.get("account", "")
    st.session_state["input_user"]     = saved_user
    st.session_state["input_password"] = _load_password(saved_user) if saved_user else ""
    st.session_state["input_dbt_path"] = cfg.get("dbt_path", r"c:\git\dbt\my_project")
    st.session_state["creds_loaded"]   = True

# ── Sidebar ────────────────────────────────────────────────────────────────────

with st.sidebar:
    st.header("Snowflake")
    account  = st.text_input("Account",  key="input_account",  placeholder="xy12345.eu-west-1")
    user     = st.text_input("User",     key="input_user")
    password = st.text_input("Password", key="input_password", type="password")

    if st.button("Connect", use_container_width=True):
        try:
            conn = snowflake.connector.connect(
                account=account, user=user, password=password
            )
            for key in list(st.session_state):
                if key not in ("input_account", "input_user", "input_password",
                               "creds_loaded", "input_dbt_path"):
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

            # Fetch all databases, find the one with the most schemas
            cur.execute("show databases")
            all_dbs = [r[1] for r in cur.fetchall()]
            user_dbs = [db for db in all_dbs if not db.upper().startswith("SNOWFLAKE")]

            schema_counts: dict[str, int] = {}
            for db in user_dbs:
                try:
                    cur.execute(f"show schemas in database {db}")
                    schema_counts[db] = sum(
                        1 for r in cur.fetchall() if r[1].upper() != "INFORMATION_SCHEMA"
                    )
                except Exception:
                    schema_counts[db] = 0

            sorted_dbs = sorted(schema_counts, key=lambda db: -schema_counts[db])
            default_db = sorted_dbs[0] if sorted_dbs else (all_dbs[0] if all_dbs else None)

            st.session_state["warehouses"]   = warehouses
            st.session_state["roles"]        = roles
            st.session_state["current_wh"]   = current_wh
            st.session_state["current_role"] = current_role
            st.session_state["databases"]    = all_dbs
            st.session_state["default_db"]   = default_db

            _save_config(account, user)
            _save_password(user, password)
            st.success("Connected")
        except Exception as e:
            st.error(str(e))
            st.session_state.pop("conn", None)

    if "conn" in st.session_state and "warehouses" in st.session_state:
        st.divider()

        def _clear_meta():
            for key in [k for k in st.session_state
                        if k.startswith(("meta_", "schemas_")) or k == "databases"]:
                del st.session_state[key]

        def on_warehouse_change():
            wh = st.session_state["sel_wh"]
            st.session_state["conn"].cursor().execute(f'use warehouse "{wh}"')
            _clear_meta()

        def on_role_change():
            role = st.session_state["sel_role"]
            st.session_state["conn"].cursor().execute(f'use role "{role}"')
            _clear_meta()

        whs   = st.session_state["warehouses"]
        roles = st.session_state["roles"]

        wh_idx = (whs.index(st.session_state["current_wh"])
                  if st.session_state.get("current_wh") in whs else 0)
        role_idx = (roles.index(st.session_state["current_role"])
                    if st.session_state.get("current_role") in roles else 0)

        st.selectbox("Warehouse", whs,   index=wh_idx,   key="sel_wh",   on_change=on_warehouse_change)
        st.selectbox("Role",      roles, index=role_idx, key="sel_role", on_change=on_role_change)

        st.divider()

        # Database
        dbs = st.session_state.get("databases", [])
        if "databases" not in st.session_state:
            conn_obj = st.session_state["conn"]
            cur2 = conn_obj.cursor()
            cur2.execute("show databases")
            dbs = [r[1] for r in cur2.fetchall()]
            st.session_state["databases"] = dbs

        default_db = st.session_state.get("default_db")
        db_idx = dbs.index(default_db) if default_db in dbs else 0
        database = st.selectbox("Database", dbs, index=db_idx, key="sel_database")

        # Schemas
        schemas_cache_key = f"schemas_{database}"
        if schemas_cache_key not in st.session_state:
            conn_obj = st.session_state["conn"]
            cur3 = conn_obj.cursor()
            cur3.execute(f"show schemas in database {database}")
            st.session_state[schemas_cache_key] = [
                r[1] for r in cur3.fetchall() if r[1].upper() != "INFORMATION_SCHEMA"
            ]
        all_schemas = st.session_state[schemas_cache_key]

        selected_schemas = st.multiselect(
            "Schemas", all_schemas, default=all_schemas,
            key=f"sel_schemas_{database}"
        )

        st.divider()

        # Output options
        st.caption("Output")
        gen_sources = st.checkbox("sources.yml",           value=True, key="opt_sources")
        if gen_sources:
            sources_combined = st.radio(
                "sources_mode", ["Per schema", "Gecombineerd"],
                key="opt_sources_mode", label_visibility="collapsed"
            ) == "Gecombineerd"
        else:
            sources_combined = False
        gen_staging = st.checkbox("Staging models",        value=True, key="opt_staging")
        gen_dbt     = st.checkbox("dbt_project.yml snippet", value=True, key="opt_dbt")

        st.divider()

        # dbt project path
        st.text_input("dbt project path", key="input_dbt_path",
                      placeholder=r"c:\git\dbt\my_project")

        if _HAS_TK:
            if st.button("Browse...", use_container_width=True):
                _browse_folder()
                st.rerun()

        dbt_path = st.session_state.get("input_dbt_path", "")

        if dbt_path and selected_schemas:
            if st.button("Write files", type="primary", use_container_width=True):
                st.session_state["do_write"] = True

# ── Main area ──────────────────────────────────────────────────────────────────

if "conn" not in st.session_state:
    st.info("Connect to Snowflake in the sidebar to get started.")
    st.stop()

if not st.session_state.get("sel_database") or not selected_schemas:
    st.stop()

conn = st.session_state["conn"]
database = st.session_state["sel_database"]

def query(sql: str) -> list:
    cur = conn.cursor()
    cur.execute(sql)
    return cur.fetchall()

# ── Fetch metadata ─────────────────────────────────────────────────────────────

meta_key = f"meta_{database}_{'_'.join(sorted(s.lower() for s in selected_schemas))}"
if meta_key not in st.session_state:
    schema_list = ", ".join(f"'{s.lower()}'" for s in selected_schemas)
    with st.spinner("Fetching metadata..."):
        st.session_state[meta_key] = query(f"""
            select lower(c.table_schema)
                 , lower(c.table_name)
                 , lower(c.column_name)
                 , lower(c.data_type)
              from {database}.information_schema.columns c
              join {database}.information_schema.tables  t
                on  t.table_catalog = c.table_catalog
               and  t.table_schema  = c.table_schema
               and  t.table_name    = c.table_name
             where lower(c.table_schema) in ({schema_list})
               and t.table_type = 'BASE TABLE'
             order by c.table_schema, c.table_name, c.ordinal_position
        """)

data: dict = defaultdict(lambda: defaultdict(list))
for schema, table, col, dtype in st.session_state[meta_key]:
    data[schema][table].append((col, dtype))

if not data:
    st.warning("No tables found in the selected schemas.")
    st.stop()

total_tables = sum(len(t) for t in data.values())
st.caption(f"{len(data)} schema(s) · {total_tables} table(s)")

# ── Generate ───────────────────────────────────────────────────────────────────

def gen_sources_yml_split(db: str, schema: str, tables: dict) -> str:
    lines = [
        "version: 2", "",
        "sources:",
        f"  - name: {schema}",
        f"    database: {db.lower()}",
        f"    schema: {schema}",
        "    tables:",
    ]
    for table, columns in tables.items():
        lines += [f"      - name: {table}", "        columns:"]
        for col, dtype in columns:
            lines += [f"          - name: {col}", f"            data_type: {dtype}"]
    return "\n".join(lines)

def gen_sources_yml_combined(db: str, data: dict) -> str:
    lines = ["version: 2", "", "sources:"]
    for schema, tables in data.items():
        lines += [
            f"  - name: {schema}",
            f"    database: {db.lower()}",
            f"    schema: {schema}",
            "    tables:",
        ]
        for table, columns in tables.items():
            lines += [f"      - name: {table}", "        columns:"]
            for col, dtype in columns:
                lines += [f"          - name: {col}", f"            data_type: {dtype}"]
    return "\n".join(lines)

def gen_staging_model(schema: str, table: str) -> str:
    return f"select * from {{{{ source('{schema}', '{table}') }}}}"

def gen_dbt_snippet(schemas) -> str:
    lines = ["    staging:"]
    for schema in sorted(schemas):
        lines += [f"      {schema}:", "        +enabled: false"]
    return "\n".join(lines)

# ── Tabs ───────────────────────────────────────────────────────────────────────

gen_sources      = st.session_state.get("opt_sources",      True)
sources_combined = st.session_state.get("opt_sources_mode", "Per schema") == "Gecombineerd"
gen_staging      = st.session_state.get("opt_staging",      True)
gen_dbt          = st.session_state.get("opt_dbt",          True)

tab_labels = (
    (["sources.yml"] if gen_sources else [])
    + (["Staging models"] if gen_staging else [])
    + (["dbt_project.yml"] if gen_dbt else [])
)

if not tab_labels:
    st.info("Selecteer minstens één output-optie in de linkerbalk.")
    st.stop()

tabs = st.tabs(tab_labels)
tab_idx = 0

if gen_sources:
    with tabs[tab_idx]:
        if sources_combined:
            st.caption("models/staging/sources/sources.yml")
            st.code(gen_sources_yml_combined(database, data), language="yaml")
        else:
            for schema, tables in data.items():
                st.caption(f"models/staging/sources/{schema}.yml")
                st.code(gen_sources_yml_split(database, schema, tables), language="yaml")
    tab_idx += 1

if gen_staging:
    with tabs[tab_idx]:
        for schema, tables in data.items():
            for table in tables:
                st.caption(f"models/staging/{schema}/{table}.sql")
                st.code(gen_staging_model(schema, table), language="sql")
    tab_idx += 1

if gen_dbt:
    with tabs[tab_idx]:
        st.caption("Plak dit onder `models:` in dbt_project.yml")
        st.code(gen_dbt_snippet(data.keys()), language="yaml")

# ── Write files ────────────────────────────────────────────────────────────────

if st.session_state.pop("do_write", False):
    dbt_path = st.session_state.get("input_dbt_path", "")
    root = Path(dbt_path)
    if not root.exists():
        st.error(f"Path does not exist: {dbt_path}")
    else:
        written = []
        sources_dir = root / "models" / "staging" / "sources"

        if gen_sources:
            sources_dir.mkdir(parents=True, exist_ok=True)
            if sources_combined:
                p = sources_dir / "sources.yml"
                p.write_text(gen_sources_yml_combined(database, data), encoding="utf-8")
                written.append(p.relative_to(root))
            else:
                for schema, tables in data.items():
                    p = sources_dir / f"{schema}.yml"
                    p.write_text(gen_sources_yml_split(database, schema, tables), encoding="utf-8")
                    written.append(p.relative_to(root))

        if gen_staging:
            for schema, tables in data.items():
                staging_dir = root / "models" / "staging" / schema
                staging_dir.mkdir(parents=True, exist_ok=True)
                for table in tables:
                    p = staging_dir / f"{table}.sql"
                    p.write_text(gen_staging_model(schema, table), encoding="utf-8")
                    written.append(p.relative_to(root))

        _save_config(account, user, dbt_path)
        st.success(f"{len(written)} files written:")
        for f in written:
            st.write(f"`{f}`")
