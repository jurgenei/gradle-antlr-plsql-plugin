create or replace PROCEDURE fix_limit_fbstart_date_ref (
    v_batch_id        IN NUMBER DEFAULT NULL,
    v_system_id        IN pkg_subtype.systemid,
    v_reporting_date    IN pkg_subtype.reportingdate,
    v_table_name IN VARCHAR2 DEFAULT NULL
) AS
    v_msg   pkg_subtype.debug_msg;
    v_txt   VARCHAR2(100);
BEGIN

BEGIN
  DELETE FROM w_limit_fbstart_date_ref
WHERE rowid NOT IN (SELECT min(rowid) from w_limit_fbstart_date_ref
group by SYSTEM_ID, FACILITY_ID,HIGHER_LEVEL_FACILITY_ID);
  
 COMMIT ;
  
 EXCEPTION
        WHEN OTHERS THEN
            v_txt := 'error in delete';
            RAISE exception_util.err_delete;
    END;

    v_msg := $$plsql_line
    || ' of plsql unit '
    || $$plsql_unit
    || ' rows deleted from w_limit_fbstart_date_ref '
    || SQL%rowcount;


    BEGIN
        DELETE limit_fbstart_date_ref
        WHERE
            ROWID IN (
                SELECT
                    limit_fbstart_date_ref.rowid
                FROM
                    limit_fbstart_date_ref,
                    w_limit_fbstart_date_ref
                WHERE
                    limit_fbstart_date_ref.facility_id = w_limit_fbstart_date_ref.facility_id
                    AND  limit_fbstart_date_ref.higher_level_facility_id = w_limit_fbstart_date_ref.higher_level_facility_id
                    AND   limit_fbstart_date_ref.system_id = w_limit_fbstart_date_ref.system_id
            );
            
    COMMIT;

    EXCEPTION
        WHEN OTHERS THEN
            v_txt := 'error in delete';
            RAISE exception_util.err_delete;
    END;

    v_msg := $$plsql_line
    || ' of plsql unit '
    || $$plsql_unit
    || ' rows deleted from limit_fbstart_date_ref '
    || SQL%rowcount;

    utilities.show_debug(v_msg);

    BEGIN
        INSERT INTO limit_fbstart_date_ref (
            SYSTEM_ID ,
	FACILITY_ID ,
    HIGHER_LEVEL_FACILITY_ID ,
	FORBEARANCE_START_DATE ,
    PROBATION_DATE ,
	IN_FORBEARANCE ,
    LATEST_FBSTDT,
    CHANGED_INDICATOR
        )
            ( SELECT
                SYSTEM_ID ,
	FACILITY_ID ,
    HIGHER_LEVEL_FACILITY_ID ,
	FORBEARANCE_START_DATE ,
    PROBATION_DATE ,
	IN_FORBEARANCE ,
    LATEST_FBSTDT,
    CHANGED_INDICATOR
              FROM
                w_limit_fbstart_date_ref
            );

    EXCEPTION
        WHEN OTHERS THEN
            v_txt := 'facility data';
            RAISE ;
    END;

    v_msg := $$plsql_line
    || ' of plsql unit '
    || $$plsql_unit
    || ' rows inserted into limit_fbstart_date_ref '
    || SQL%rowcount;

     utils.commit_transaction;

      utilities.truncate_table('w_limit_fbstart_date_ref');
     
EXCEPTION
    WHEN OTHERS THEN
        ROLLBACK;
      RAISE;
END;

/
show error;