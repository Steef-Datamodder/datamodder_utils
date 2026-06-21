{% macro log_dbt_end() %}
    INSERT INTO compare_wh.compare_stats.runtimes (invocation_id
                                                 , project_name
                                                 , target_name
                                                 , run_ended_at
                                                 , stat)
    VALUES ('{{ invocation_id }}'
          , '{{ project_name }}'
          , '{{ target.name }}'
          , current_timestamp()
          , 'DBT Run ended');
{% endmacro %}