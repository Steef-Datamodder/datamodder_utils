{% macro log_dbt_start() %}
    INSERT INTO compare_wh.compare_stats.runtimes (invocation_id
                                                 , project_name
                                                 , target_name
                                                 , run_started_at
                                                 , stat)
    VALUES ('{{ invocation_id }}'
          , '{{ project_name }}'
          , '{{ target.name }}'
          , '{{ run_started_at }}'::TIMESTAMP_TZ
          , 'DBT Run started');
{% endmacro %}