create or replace procedure DATAMODDER_UTILS.PROFILE_PII(
    DATABASE_NAME   string,
    SCHEMA_NAME     string,
    SAMPLE_ROWS     number,
    MATCH_THRESHOLD float  default 0.1,
    UTILS_DATABASE  string default null,
    UTILS_SCHEMA    string default null
)
returns variant
language python
runtime_version = '3.11'
packages = ('snowflake-snowpark-python')
handler = 'profile_pii'
execute as caller
as
$$
import uuid


def q_ident(identifier: str) -> str:
    return '"' + str(identifier).replace('"', '""') + '"'


def q_name(db: str, sch: str, obj: str) -> str:
    return q_ident(db) + '.' + q_ident(sch) + '.' + q_ident(obj)


def profile_pii(
    session,
    database_name: str,
    schema_name: str,
    sample_rows: int,
    match_threshold: float = 0.1,
    utils_database: str = None,
    utils_schema: str = None,
):
    scan_id = str(uuid.uuid4())
    db = database_name.upper()
    sch = schema_name.upper()
    sample_rows = sample_rows or 1000

    utils_db = (utils_database or session.get_current_database()).upper().strip('"')
    utils_sch = (utils_schema or session.get_current_schema()).upper().strip('"')

    rules_table = q_name(utils_db, utils_sch, 'PII_REGEX_RULES')
    results_table = q_name(utils_db, utils_sch, 'PII_SCAN_RESULTS')

    candidates_sql = f"""
        select c.table_name
             , c.column_name
             , c.data_type
             , r.pii_type
             , r.rule_name
             , r.column_name_regex
             , r.value_regex
             , r.confidence_name_match
             , r.confidence_value_match
             , r.suggested_action
             , case when r.column_name_regex is not null
                    then regexp_like(c.column_name, r.column_name_regex, 'i')
                    else false end as name_matched
          from {q_ident(db)}.information_schema.columns c
          join {q_ident(db)}.information_schema.tables t
            on  t.table_schema = c.table_schema
           and  t.table_name   = c.table_name
         cross join {rules_table} r
         where c.table_schema = ?
           and t.table_type   = 'BASE TABLE'
           and r.is_active    = true
           and (r.data_type_regex is null
                or regexp_like(c.data_type, r.data_type_regex, 'i'))
         order by c.table_name, c.ordinal_position, r.pii_type, r.rule_name
    """

    candidates = session.sql(candidates_sql, params=[sch]).collect()

    scanned_columns = session.sql(
        f"select count(*) from {q_ident(db)}.information_schema.columns c"
        f"  join {q_ident(db)}.information_schema.tables t"
        f"    on t.table_schema = c.table_schema and t.table_name = c.table_name"
        f" where c.table_schema = ? and t.table_type = 'BASE TABLE'",
        params=[sch],
    ).collect()[0][0]

    findings = []

    for cand in candidates:
        table_name = cand['TABLE_NAME']
        column_name = cand['COLUMN_NAME']
        data_type = cand['DATA_TYPE']
        pii_type = cand['PII_TYPE']
        rule_name = cand['RULE_NAME']
        value_regex = cand['VALUE_REGEX']
        conf_name = cand['CONFIDENCE_NAME_MATCH'] or 0.0
        conf_value = cand['CONFIDENCE_VALUE_MATCH'] or 0.0
        suggested_action = cand['SUGGESTED_ACTION']
        name_matched = bool(cand['NAME_MATCHED'])

        detection_reasons = []
        value_matched = False
        matched_sample_count = 0
        actual_sample_size = 0

        if name_matched:
            detection_reasons.append(f"Column name matched regex: {cand['COLUMN_NAME_REGEX']}")

        if value_regex:
            try:
                sample_sql = f"""
                    select count(*)                                                          as sample_size
                         , count_if(regexp_like(to_varchar({q_ident(column_name)}), ?, 'i')) as matched_count
                      from (
                          select {q_ident(column_name)}
                            from {q_name(db, sch, table_name)}
                           where {q_ident(column_name)} is not null
                           limit ?
                      )
                """
                row = session.sql(sample_sql, params=[value_regex, sample_rows]).collect()[0]
                actual_sample_size = row['SAMPLE_SIZE']
                matched_sample_count = row['MATCHED_COUNT']
                match_ratio = matched_sample_count / actual_sample_size if actual_sample_size > 0 else 0.0
                value_matched = match_ratio >= match_threshold

                if value_matched:
                    detection_reasons.append(
                        f"Sample values matched regex: {value_regex} "
                        f"({matched_sample_count}/{actual_sample_size}, {match_ratio:.0%})"
                    )

            except Exception as err:
                detection_reasons.append(f"Value scan failed: {str(err)}")

        if not (name_matched or value_matched):
            continue

        confidence = min(
            (conf_name if name_matched else 0.0)
            + (conf_value if value_matched else 0.0),
            1.0,
        )

        findings.append((
            scan_id, db, sch, table_name, column_name, data_type,
            pii_type, rule_name, confidence,
            ' | '.join(detection_reasons),
            matched_sample_count, actual_sample_size, suggested_action,
        ))

    insert_sql = f"""
        insert into {results_table}
            (scan_id, scanned_at, database_name, schema_name, table_name,
             column_name, data_type, pii_type, rule_name, confidence,
             detection_reason, matched_sample_count, sample_size, suggested_action)
        select ?, current_timestamp(), ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?
    """

    for finding in findings:
        session.sql(insert_sql, params=list(finding)).collect()

    return {
        'scan_id': scan_id,
        'database_name': db,
        'schema_name': sch,
        'sample_rows': sample_rows,
        'match_threshold': match_threshold,
        'scanned_columns': scanned_columns,
        'findings': len(findings),
    }
$$;
