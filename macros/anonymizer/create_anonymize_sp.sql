{% macro create_anonymizer_sp() %}
{% if execute %}
{%- set schema_ref = target.database ~ '.' ~ _datamodder_schema() -%}
{%- set test_table_sql %}
    create table if not exists {{ schema_ref }}.test_anonymize_customer as
    select *
    from snowflake_sample_data.tpch_sf1.customer
    limit 100
{%- endset -%}
{%- do run_query(test_table_sql) -%}
{%- set sql %}
create or replace procedure {{ schema_ref }}.anonymize(table_name varchar, pk varchar, columns variant)
returns varchar
language sql
as
$$
declare
    i           integer default 0;
    n           integer;
    j           integer;
    k           integer;
    m           integer;
    col_config  variant;
    col_name    varchar;
    method      varchar;
    pattern     varchar;
    pattern_sql varchar;
    ch          varchar;
    sql_stmt    varchar;
    select_cols  varchar;
    set_cols     varchar;
    c            varchar;
    source_table varchar;
    source_col   varchar;
    distinct_kw  varchar;
begin
    n := array_size(columns);
    while (i < n) do
        col_config := columns[i];
        method     := col_config['method']::varchar;

        if (method = 'shuffle') then
            if (is_array(col_config['column'])) then
                select_cols := '';
                set_cols    := '';
                k           := 0;
                m           := array_size(col_config['column']);
                while (k < m) do
                    c := col_config['column'][k]::varchar;
                    if (k > 0) then
                        select_cols := select_cols || ', ';
                        set_cols    := set_cols    || ', ';
                    end if;
                    select_cols := select_cols || c;
                    set_cols    := set_cols    || c || ' = src.' || c;
                    k := k + 1;
                end while;
            else
                c           := col_config['column']::varchar;
                select_cols := c;
                set_cols    := c || ' = src.' || c;
            end if;

            sql_stmt :=
                'update ' || table_name || ' as t ' ||
                'set ' || set_cols || ' ' ||
                'from (' ||
                    'select row_number() over (order by ' || pk || ') as rn, ' || pk ||
                    ' from ' || table_name ||
                ') as ids ' ||
                'join (' ||
                    'select row_number() over (order by random()) as rn, ' || select_cols ||
                    ' from ' || table_name ||
                ') as src on ids.rn = src.rn ' ||
                'where t.' || pk || ' = ids.' || pk;
            execute immediate sql_stmt;

        elseif (method = 'random_string') then
            col_name    := col_config['column']::varchar;
            pattern     := col_config['pattern']::varchar;
            pattern_sql := '';
            j           := 1;
            while (j <= length(pattern)) do
                ch := substr(pattern, j, 1);
                if (length(pattern_sql) > 0) then
                    pattern_sql := pattern_sql || ' || ';
                end if;
                if (ch = 'A') then
                    pattern_sql := pattern_sql || 'chr(65 + uniform(0, 26, random())::integer)';
                elseif (ch = 'a') then
                    pattern_sql := pattern_sql || 'chr(97 + uniform(0, 26, random())::integer)';
                elseif (ch = '#') then
                    pattern_sql := pattern_sql || 'to_varchar(uniform(0, 9, random())::integer)';
                else
                    pattern_sql := pattern_sql || '''' || ch || '''';
                end if;
                j := j + 1;
            end while;

            sql_stmt := 'update ' || table_name || ' set ' || col_name  || ' = ' || pattern_sql;
            execute immediate sql_stmt;

        elseif (method = 'shift_housenumber') then
            col_name := col_config['column']::varchar;
            sql_stmt :=
                'update ' || table_name || ' set ' || col_name || ' = ' ||
                'case uniform(1, 5, random())::integer ' ||
                    'when 1 then to_varchar(greatest(1, try_to_number(regexp_substr(' || col_name || ', ''^[0-9]+'')) + 4)) || regexp_replace(' || col_name || ', ''^[0-9]+'', '''') ' ||
                    'when 2 then to_varchar(greatest(1, try_to_number(regexp_substr(' || col_name || ', ''^[0-9]+'')) + 2)) || regexp_replace(' || col_name || ', ''^[0-9]+'', '''') ' ||
                    'when 3 then ' || col_name || ' ' ||
                    'when 4 then to_varchar(greatest(1, try_to_number(regexp_substr(' || col_name || ', ''^[0-9]+'')) - 2)) || regexp_replace(' || col_name || ', ''^[0-9]+'', '''') ' ||
                    'when 5 then to_varchar(greatest(1, try_to_number(regexp_substr(' || col_name || ', ''^[0-9]+'')) - 4)) || regexp_replace(' || col_name || ', ''^[0-9]+'', '''') ' ||
                'end';
            execute immediate sql_stmt;

        elseif (method = 'random_lookup') then
            col_name     := col_config['column']::varchar;
            source_table := col_config['source']::varchar;
            source_col   := col_config['source_column']::varchar;
            if (col_config['uniform'] is null or col_config['uniform']::boolean = true) then
                distinct_kw := 'distinct ';
            else
                distinct_kw := '';
            end if;
            sql_stmt :=
                'update ' || table_name || ' as t ' ||
                'set ' || col_name || ' = src.' || source_col || ' ' ||
                'from (' ||
                    'select ' || pk || ', ' || source_col || ' ' ||
                    'from (' ||
                        'select t.' || pk || ', s.' || source_col || ', ' ||
                        'row_number() over (partition by t.' || pk || ' order by random()) as rn ' ||
                        'from ' || table_name || ' t ' ||
                        'cross join (select ' || distinct_kw || source_col || ' from ' || source_table || ') s' ||
                    ') where rn = 1' ||
                ') src ' ||
                'where t.' || pk || ' = src.' || pk;
            execute immediate sql_stmt;

        elseif (method = 'shuffle_name') then
            col_name := col_config['column']::varchar;

            -- step 1: parse each name into voornaam + achternaam_deel
            -- infix detection: longest-first regex on space-padded lowercase name
            -- rule 1: two words, no infix   → word 1 = voornaam, word 2 = achternaam
            -- rule 2/3: infix found         → everything before = voornaam, from infix = achternaam
            -- rule 4: hyphens               → treated as single token, no split
            -- rule 5: no infix, 3+ words   → word 1 = voornaam, last word = achternaam (middle discarded)
            -- initials: single-letter voornaam gets a dot appended
            sql_stmt :=
                'create or replace temporary table _tmp_name_parts as ' ||
                'with padded as (' ||
                    'select ' || pk || ', trim(' || col_name || ') as naam, ' ||
                    '       '' '' || lower(trim(' || col_name || ')) || '' '' as lpad ' ||
                    'from ' || table_name ||
                '), with_pos as (' ||
                    'select ' || pk || ', naam, ' ||
                    'regexp_instr(lpad, '' (van den|van der|van de|van het|in den|in de|in het|op den|op de|op het|von und zu|de la|de los|de las|van|von|zu|den|der|het|ter|ten|bij|over|onder|voor|aan|uit|tot|della|degli|delle|dalla|dal|del|di|du|des|mac|bint|ould|bou|bin|ben|la|le|el|al|ou|af|of|mc|de|in|op|te) '') as ipos, ' ||
                    'array_size(strtok_to_array(naam, '' '')) as wc ' ||
                    'from padded' ||
                ') ' ||
                'select ' || pk || ', ' ||
                'case ' ||
                    'when ipos > 1 then ' ||
                        'iff(regexp_like(trim(substr(naam, 1, ipos - 1)), ''[A-Za-z]''), ' ||
                            'iff(length(trim(substr(naam, 1, ipos - 1))) = 1, ' ||
                                'upper(trim(substr(naam, 1, ipos - 1))) || ''.'', ' ||
                                'trim(substr(naam, 1, ipos - 1))), ' ||
                            'trim(substr(naam, 1, ipos - 1))) ' ||
                    'when wc = 1 then naam ' ||
                    'else strtok(naam, '' '', 1) ' ||
                'end as voornaam, ' ||
                'case ' ||
                    'when ipos > 1 then trim(substr(naam, ipos)) ' ||
                    'when wc <= 1 then null ' ||
                    'when wc = 2 then strtok(naam, '' '', 2) ' ||
                    'else strtok(naam, '' '', wc) ' ||
                'end as achternaam_deel ' ||
                'from with_pos';
            execute immediate sql_stmt;

            -- step 2: shuffle voornamen independently
            sql_stmt :=
                'create or replace temporary table _tmp_vn as ' ||
                'with ranked as (' ||
                    'select ' || pk || ', voornaam, ' ||
                    'row_number() over (order by hash(' || pk || ', current_timestamp(), ''vn'')) as src_rn, ' ||
                    'row_number() over (order by ' || pk || ') as tgt_rn ' ||
                    'from _tmp_name_parts where voornaam is not null' ||
                ') ' ||
                'select t.' || pk || ' as tpk, s.voornaam as new_voornaam ' ||
                'from ranked t join ranked s on t.tgt_rn = s.src_rn';
            execute immediate sql_stmt;

            -- step 3: shuffle achternaam_deel independently (different salt)
            sql_stmt :=
                'create or replace temporary table _tmp_an as ' ||
                'with ranked as (' ||
                    'select ' || pk || ', achternaam_deel, ' ||
                    'row_number() over (order by hash(' || pk || ', current_timestamp(), ''an'')) as src_rn, ' ||
                    'row_number() over (order by ' || pk || ') as tgt_rn ' ||
                    'from _tmp_name_parts where achternaam_deel is not null' ||
                ') ' ||
                'select t.' || pk || ' as tpk, s.achternaam_deel as new_achternaam_deel ' ||
                'from ranked t join ranked s on t.tgt_rn = s.src_rn';
            execute immediate sql_stmt;

            -- step 4: combine and write back
            sql_stmt :=
                'update ' || table_name || ' as t ' ||
                'set ' || col_name || ' = ' ||
                    'case ' ||
                        'when an.new_achternaam_deel is null then vn.new_voornaam ' ||
                        'when vn.new_voornaam is null then an.new_achternaam_deel ' ||
                        'else vn.new_voornaam || '' '' || an.new_achternaam_deel ' ||
                    'end ' ||
                'from _tmp_vn vn ' ||
                'left join _tmp_an an on vn.tpk = an.tpk ' ||
                'where t.' || pk || ' = vn.tpk';
            execute immediate sql_stmt;

        elseif (method = 'shuffle_phone') then
            col_name := col_config['column']::varchar;

            -- prefix shuffle via temp tabel: hash(pk, timestamp, salt) is per rij uniek en varieert per run
            sql_stmt :=
                'create or replace temporary table _tmp_pfx as ' ||
                'with pool as (' ||
                    'select ' || pk || ', split_part(' || col_name || ', ''-'', 1) as pfx, len(split_part(' || col_name || ', ''-'', 1)) as plen ' ||
                    'from ' || table_name ||
                '), ranked as (' ||
                    'select ' || pk || ', pfx, plen, ' ||
                    'row_number() over (partition by plen order by hash(' || pk || ', current_timestamp(), ''pfx'')) as src_rn, ' ||
                    'row_number() over (partition by plen order by ' || pk || ') as tgt_rn ' ||
                    'from pool' ||
                ') ' ||
                'select t.' || pk || ' as tpk, s.pfx as new_prefix ' ||
                'from ranked t join ranked s on t.plen = s.plen and t.tgt_rn = s.src_rn';
            execute immediate sql_stmt;

            sql_stmt :=
                'update ' || table_name || ' as t ' ||
                'set ' || col_name || ' = tmp.new_prefix || ''-'' || split_part(t.' || col_name || ', ''-'', 2) ' ||
                'from _tmp_pfx tmp where t.' || pk || ' = tmp.tpk';
            execute immediate sql_stmt;

            -- suffix shuffle: onafhankelijk via andere salt
            sql_stmt :=
                'create or replace temporary table _tmp_sfx as ' ||
                'with pool as (' ||
                    'select ' || pk || ', split_part(' || col_name || ', ''-'', 2) as sfx, len(split_part(' || col_name || ', ''-'', 2)) as slen ' ||
                    'from ' || table_name ||
                '), ranked as (' ||
                    'select ' || pk || ', sfx, slen, ' ||
                    'row_number() over (partition by slen order by hash(' || pk || ', current_timestamp(), ''sfx'')) as src_rn, ' ||
                    'row_number() over (partition by slen order by ' || pk || ') as tgt_rn ' ||
                    'from pool' ||
                ') ' ||
                'select t.' || pk || ' as tpk, s.sfx as new_suffix ' ||
                'from ranked t join ranked s on t.slen = s.slen and t.tgt_rn = s.src_rn';
            execute immediate sql_stmt;

            sql_stmt :=
                'update ' || table_name || ' as t ' ||
                'set ' || col_name || ' = split_part(t.' || col_name || ', ''-'', 1) || ''-'' || tmp.new_suffix ' ||
                'from _tmp_sfx tmp where t.' || pk || ' = tmp.tpk';
            execute immediate sql_stmt;
        end if;

        i := i + 1;
    end while;

    return 'done';
end;
$$
{%- endset -%}
{%- do run_query(sql) -%}
{% endif %}
{% endmacro %}
