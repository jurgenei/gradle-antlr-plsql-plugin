create or replace PROCEDURE process_legal_entity_hierarchy (
    reference_sync IN VARCHAR2 DEFAULT 'N'
) AS

    v_step                NUMBER(10) := 0;
    v_proc                VARCHAR(255) := 'process_legal_entity_hierarchy';
    v_err                 NUMBER(10);
    v_max_key             NUMBER(10);
    v_max_date            DATE;
    v_translation_id      NUMBER(10);
    v_from_character      VARCHAR2(10);
    v_to_character        VARCHAR2(10);
    v_search_string       VARCHAR2(10);
    v_in_process          CHAR(1);
    v_max_level           NUMBER(10);
    v_level               NUMBER(10);
    v_entity_code         CHAR(10);
    v_entity_key          NUMBER(10);
    v_noingentity_key     NUMBER(10);
    v_noingentity_code    CHAR(10);
    v_noingentity_descr   VARCHAR(100);
    v_changed_entity      CHAR(1);
    v_grid_expired        CHAR(1);
    v_level_parent        NUMBER(5);
    v_level_child         NUMBER(5);
    v_reference_sync      VARCHAR2(10) := reference_sync;
    v_debug_msg           VARCHAR2(2000);
BEGIN
    v_debug_msg := $$plsql_line
    || ' of plsql unit '
    || $$plsql_unit
    || ' Start';
    utilities.show_debug(v_debug_msg);
    
    BEGIN
        INSERT  INTO tt_tmp_ing_legal_entity (
            ing_legal_entity_key,
            ing_legal_entity_code,
            ing_legal_entity_descr,
            ing_legal_entity_descr_xml,
            search_name,
            search_name_xml,
            customer_id,
            record_valid_from,
            record_valid_until
        )
            ( SELECT
                entity_key,
                code,
                substr(description,0,100),
                nvl(
                    description_xml,
                    description
                ),
                substr(upper(description),0,100),
                upper(nvl(description_xml,description) ),
                CAST(code AS NUMBER(10,0) ),
                record_valid_from,
                record_valid_until
              FROM
                entity e
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    BEGIN
        WHILE ( v_in_process = 'Y' ) LOOP
            BEGIN
                MERGE INTO (select cus_record_valid_from, customer_id from tt_tmp_ing_legal_entity) e 
                USING ( SELECT
                    ddc.customer_id,
                    ddc.record_valid_from
                    FROM grid_derived_customer ddc )
                src ON ( e.cus_record_valid_from IS NULL
                    AND e.customer_id = src.customer_id )
                WHEN MATCHED THEN UPDATE SET e.cus_record_valid_from = src.record_valid_from;

                v_debug_msg := $$plsql_line
                || ' of plsql unit '
                || $$plsql_unit
                || '  MERGE INTO tt_tmp_ing_legal_entity'
                || SQL%rowcount;

                utilities.show_debug(v_debug_msg);

                MERGE INTO (select cus_record_valid_from,customer_id,basic_customer_key,customer_key_nr
                from tt_tmp_ing_legal_entity WHERE customer_key_nr IS NULL) e 
                USING ( SELECT
                    dc.record_valid_from,
                    dc.customer_key_nr,
                    dc.customer_id,
                    dc.basic_customer_key
                    FROM grid_derived_customer dc )
                src ON ( e.cus_record_valid_from = src.record_valid_from 
                    AND e.customer_id = src.customer_id )
                WHEN MATCHED THEN UPDATE SET e.customer_key_nr = src.customer_key_nr,
                                             e.basic_customer_key = src.basic_customer_key;

                v_debug_msg := $$plsql_line
                || ' of plsql unit '
                || $$plsql_unit
                || '  MERGE INTO tt_tmp_ing_legal_entity'
                || SQL%rowcount;

                utilities.show_debug(v_debug_msg);
                COMMIT;
                MERGE INTO (select customer_id,higher_level_cust_id from tt_tmp_ing_legal_entity
                            WHERE higher_level_cust_id IS NULL) e 
                    USING ( SELECT
                        c.customer_id,
                        c.legal_imm_parent_id
                    FROM grid_basic_customer c )
                src ON ( e.customer_id = src.customer_id )
                WHEN MATCHED THEN UPDATE SET e.higher_level_cust_id = src.legal_imm_parent_id;

                v_debug_msg := $$plsql_line
                || ' of plsql unit '
                || $$plsql_unit
                || '   MERGE INTO tt_tmp_ing_legal_entity'
                || SQL%rowcount;
                utilities.show_debug(v_debug_msg);
                commit;
                
                INSERT  INTO tt_tmp_ing_legal_entity (
                    customer_id,
                    ing_legal_entity_code,
                    record_valid_from,
                    record_valid_until
                )
                    ( SELECT
                        tmp.higher_level_cust_id,
                        CAST(tmp.higher_level_cust_id AS VARCHAR2(4000) ),
                        MIN(tmp.record_valid_from),
                        MAX(nvl(tmp.record_valid_until,'31-12-9999') )
                      FROM
                        tt_tmp_ing_legal_entity tmp
                      WHERE NOT EXISTS
                        (
                            SELECT
                                1
                            FROM
                                tt_tmp_ing_legal_entity tmp1
                            WHERE tmp1.customer_id = tmp.higher_level_cust_id
                        )
                      GROUP BY
                        higher_level_cust_id
                    );

                v_debug_msg := $$plsql_line
                || ' of plsql unit '
                || $$plsql_unit
                || 'INSERT INTO tt_tmp_ing_legal_entity'
                || SQL%rowcount;
                utilities.show_debug(v_debug_msg);
                COMMIT;
                IF
                    SQL%rowcount = 0
                THEN
                    v_in_process := 'N';
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;
        END LOOP;
    END;

    BEGIN
        WHILE ( v_in_process = 'Y' ) LOOP
            BEGIN
                INSERT  INTO tt_legal_entity_until (
                    customer_id,
                    record_valid_from,
                    record_valid_until
                )
                    ( SELECT
                        e1.customer_id,
                        MAX(e1.record_valid_from) record_valid_from,
                        MAX(nvl( e2.record_valid_until,'31-12-9999') ) record_valid_until
                      FROM tt_tmp_ing_legal_entity e1
                      JOIN tt_tmp_ing_legal_entity e2
                      ON e1.customer_id = e2.higher_level_cust_id
                        AND   nvl(
                            e1.record_valid_until,
                            '31-12-9999'
                        ) < nvl(
                            e2.record_valid_until,
                            '31-12-9999'
                        )
                      GROUP BY
                        e1.customer_id
                    );

                v_debug_msg := $$plsql_line
                || ' of plsql unit '
                || $$plsql_unit
                || 'INSERT INTO tt_legal_entity_until'
                || SQL%rowcount;
                utilities.show_debug(v_debug_msg);
                MERGE INTO tt_tmp_ing_legal_entity e1 USING ( SELECT
                    e1.rowid row_id,
                    e2.record_valid_until
                FROM tt_tmp_ing_legal_entity e1
                JOIN tt_legal_entity_until e2
                ON e1.customer_id = e2.customer_id
                    AND   e1.record_valid_from = e2.record_valid_from
                    AND   e1.record_valid_until IS NOT NULL
                    AND   NOT EXISTS (
                        SELECT
                            1
                        FROM
                            tt_tmp_ing_legal_entity
                        WHERE
                            customer_id = e1.customer_id
                            AND   (
                                record_valid_until > e2.record_valid_until
                                OR    record_valid_until IS NULL
                            )
                    )
                )
                src ON ( e1.rowid = src.row_id )
                WHEN MATCHED THEN UPDATE SET record_valid_until = src.record_valid_until;

                v_debug_msg := $$plsql_line
                || ' of plsql unit '
                || $$plsql_unit
                || '   MERGE INTO tt_tmp_ing_legal_entity'
                || SQL%rowcount;

                utilities.show_debug(v_debug_msg);
                IF
                    SQL%rowcount = 0
                THEN
                    v_in_process := 'N';
                END IF;
                DELETE tt_legal_entity_until;

            END;
        END LOOP;
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    UPDATE tt_tmp_ing_legal_entity
        SET
            record_valid_until = NULL
    WHERE
        record_valid_until = to_date('31-12-9999','yyyymmdd');

    v_debug_msg := $$plsql_line
    || ' of plsql unit '
    || $$plsql_unit
    || ' UPDATE tt_tmp_ing_legal_entity'
    || SQL%rowcount;
    utilities.show_debug(v_debug_msg);

    BEGIN
        INSERT  INTO tt_legal_entity_from (
            customer_id,
            record_valid_from
        )
            ( SELECT
                e1.customer_id,
                MIN(e1.record_valid_from) record_valid_from
              FROM
                tt_tmp_ing_legal_entity e1
            GROUP BY
                e1.customer_id
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;

    BEGIN
        MERGE INTO (select record_valid_from,customer_id from tt_tmp_ing_legal_entity) e1 USING ( SELECT
           distinct  e2.customer_id,
            e2.record_valid_from,
            to_date('19950101','yyyymmdd')
            FROM tt_legal_entity_from e2
        )
        src ON ( e1.customer_id = src.customer_id )
        WHEN MATCHED THEN UPDATE SET record_valid_from = to_date('19950101','yyyymmdd')
        WHERE e1.record_valid_from = src.record_valid_from;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;

    utilities.truncate_table('tt_legal_entity_until');
    BEGIN
        INSERT  INTO tt_legal_entity_until (
            customer_id,
            record_valid_from,
            record_valid_until
        )
            ( SELECT
                e1.customer_id,
                e1.record_valid_from,
                MIN(e2.record_valid_from) record_valid_until
              FROM tt_tmp_ing_legal_entity e1
              JOIN tt_tmp_ing_legal_entity e2
              ON e1.customer_id = e2.customer_id
              AND   e2.record_valid_from > e1.record_valid_from
              GROUP BY
                e1.customer_id,
                e1.record_valid_from
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;

    BEGIN
        MERGE INTO (select record_valid_until,record_valid_from, customer_id from  tt_tmp_ing_legal_entity) e1 
        USING ( SELECT
            e2.record_valid_from,
            e2.record_valid_until,
            e2.customer_id
            FROM tt_legal_entity_until e2 )
        src ON ( e1.customer_id = src.customer_id )
        WHEN MATCHED THEN UPDATE SET record_valid_until = src.record_valid_until
        WHERE
            e1.record_valid_from = src.record_valid_from;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;

    BEGIN
        INSERT INTO tt_dmi_system_configuration (
            name,
            value
        )
            ( SELECT
                'EXTENTITY',
                'Outside ING Groep N.V. tree'
              FROM
                dual
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    BEGIN
        INSERT INTO tt_dmi_system_configuration (
            name,
            value
        )
            ( SELECT
                'HIGHEST_LEGAL_ENTITY',
                '36004387'
              FROM
                dual
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    BEGIN
        INSERT INTO tt_dmi_system_configuration (
            name,
            value
        )
            ( SELECT
                'HIGHEST_LEGAL_ENTITY_2',
                '36007795'
              FROM
                dual
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    v_noingentity_code := 'EXTENTITY';
    BEGIN
        SELECT
            value
        INTO
            v_noingentity_descr
        FROM
            tt_dmi_system_configuration
        WHERE
            name = rtrim(v_noingentity_code);

    EXCEPTION
        WHEN OTHERS THEN
            NULL;
    END;

    BEGIN
        SELECT
            MAX(ing_legal_entity_key) + 1
        INTO
            v_max_key
        FROM
            tt_tmp_ing_legal_entity;

    EXCEPTION
        WHEN OTHERS THEN
            v_max_key := 0;
    END;
    COMMIT;
    BEGIN
        INSERT  INTO tt_tmp_ing_legal_entity (
            ing_legal_entity_key,
            ing_legal_entity_code,
            ing_legal_entity_descr,
            ing_legal_entity_descr_xml,
            hierarchy_level,
            higher_level_key,
            highest_level_key,
            record_valid_from,
            record_valid_until,
            customer_id,
            city,
            ctry_of_residence_key,
            search_name,
            search_name_xml,
            branch_indicator,
            customer_type_key
        ) VALUES (
            TO_CHAR(v_max_key),
            v_noingentity_code,
            v_noingentity_descr,
            v_noingentity_descr,
            1,
            v_max_key,
            v_max_key,
            TO_DATE('19950101','YYYYMMDD'),
            NULL,
            0,
            ' ',
            202,
            upper(v_noingentity_descr),
            upper(v_noingentity_descr),
            'N',
            261
        );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;

    BEGIN
        INSERT  INTO tt_ing_entity_exceptions ( exception_customer_id )
            ( SELECT
                CAST(value AS NUMBER(10) )
              FROM
                tt_dmi_system_configuration
              WHERE
                name LIKE 'HIGHEST_LEGAL_ENTITY%'
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    BEGIN
        UPDATE tt_tmp_ing_legal_entity tmp
            SET
                tmp.higher_level_cust_id = 0
        WHERE
            tmp.higher_level_cust_id IS NULL
            OR    (
                tmp.customer_id = tmp.higher_level_cust_id
                AND   
                NOT EXISTS (
                    SELECT
                        1
                    FROM
                        tt_ing_entity_exceptions
                    WHERE 
                        tt_ing_entity_exceptions.exception_customer_id = tmp.customer_id
                )
            );
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    COMMIT;
    BEGIN
        UPDATE tt_tmp_ing_legal_entity
            SET
                highest_level_cust_id = customer_id,
                hierarchy_level = 1
        WHERE
            customer_id = higher_level_cust_id;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    BEGIN
        WHILE SQL%rowcount > 0 LOOP
            BEGIN
                MERGE INTO tt_tmp_ing_legal_entity e1 USING ( SELECT
                  distinct  e2.customer_id,
                    e2.highest_level_cust_id,
                    e2.hierarchy_level + 1 AS pos_3
                                                      FROM
                    tt_tmp_ing_legal_entity e2
                                                      WHERE
                    e2.highest_level_cust_id IS NOT NULL
                )
                src ON ( src.customer_id = e1.higher_level_cust_id )
                WHEN MATCHED THEN UPDATE SET highest_level_cust_id = src.highest_level_cust_id,
                hierarchy_level = pos_3
                WHERE
                    e1.highest_level_cust_id IS NULL;

            EXCEPTION
                WHEN OTHERS THEN
                    utils.handleerror(
                        sqlcode,
                        sqlerrm
                    );
            END;
        END LOOP;
    END;
    COMMIT;
    BEGIN
        WHILE ( v_in_process = 'Y' ) LOOP
            BEGIN
                BEGIN
                    SELECT
                        MAX(ing_legal_entity_key)
                    INTO
                        v_max_key
                    FROM
                        tt_tmp_ing_legal_entity;

                EXCEPTION
                    WHEN OTHERS THEN
                        NULL;
                END;

                BEGIN
                    UPDATE tt_tmp_ing_legal_entity
                        SET
                            ing_legal_entity_key = v_max_key + 1
                    WHERE
                        ing_legal_entity_key IS NULL;

                EXCEPTION
                    WHEN OTHERS THEN
                        utils.handleerror(
                            sqlcode,
                            sqlerrm
                        );
                END;

                IF
                    SQL%rowcount = 0
                THEN
                    v_in_process := 'N';
                END IF;
            END;
        END LOOP;
    END;
    COMMIT;
    BEGIN
        MERGE INTO tt_tmp_ing_legal_entity t1 USING ( SELECT
         distinct   t2.customer_id,
            t2.record_valid_from,
            t2.record_valid_until,
            t2.ing_legal_entity_key
            FROM tt_tmp_ing_legal_entity t2 )
        src ON (
            src.customer_id = t1.higher_level_cust_id
            AND nvl(src.record_valid_from,'31-12-9999') < t1.record_valid_until
            AND (src.record_valid_until >= t1.record_valid_until OR src.record_valid_until IS NULL
            OR ( t1.record_valid_until IS NULL AND src.record_valid_until IS NULL ) )
        )
        WHEN MATCHED THEN UPDATE SET higher_level_key = src.ing_legal_entity_key;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    BEGIN
        MERGE INTO tt_tmp_ing_legal_entity t1 USING ( SELECT
            t2.customer_id,
            t2.record_valid_from,
            t2.record_valid_until,
            t2.ing_legal_entity_key
                                                      FROM
            tt_tmp_ing_legal_entity t2
        )
        src ON (
            src.customer_id = t1.highest_level_cust_id
            AND nvl( src.record_valid_from ,'31-12-9999' ) < t1.record_valid_until
            AND (
                src.record_valid_until >= t1.record_valid_until
                OR src.record_valid_until IS NULL
                OR (
                    t1.record_valid_until IS NULL
                    AND src.record_valid_until IS NULL
                )
            )
        )
        WHEN MATCHED THEN UPDATE SET highest_level_key = src.ing_legal_entity_key;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;

    BEGIN
        UPDATE tt_tmp_ing_legal_entity
            SET
                ing_entity = 'Y'
        WHERE
            highest_level_cust_id IN (
                SELECT
                    tt_ing_entity_exceptions.exception_customer_id
                FROM
                    tt_ing_entity_exceptions
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    BEGIN
        UPDATE tt_tmp_ing_legal_entity
            SET
                ing_entity = 'N'
        WHERE
            ing_entity IS NULL;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;

    BEGIN
        MERGE INTO tt_tmp_ing_legal_entity ee USING ( SELECT
            bc.customer_id,
            bc.customer_name,
            bc.city,
            upper(
                bc.customer_name
            ) AS pos_6,
            upper(
                bc.customer_name
            ) AS pos_7,
            bc.branch_indicator
                                                      FROM
            grid_basic_customer bc
        )
        src ON ( src.customer_id = ee.customer_id )
        WHEN MATCHED THEN UPDATE SET ee.ing_legal_entity_descr = src.customer_name,
        ee.ing_legal_entity_descr_xml = src.customer_name,
        ee.city = src.city,
        ee.city_xml = src.city,
        ee.search_name = pos_6,
        ee.search_name_xml = pos_7,
        ee.branch_indicator = src.branch_indicator;

    EXCEPTION
        WHEN no_data_found THEN
            dbms_output.put_line('ERROR 7777----->'
            || substr(
                sqlerrm,
                1,
                500
            ) );
    END;
    COMMIT;
    BEGIN
        MERGE INTO (select customer_key_nr,ctry_of_residence_key,customer_type_key from tt_tmp_ing_legal_entity) e 
        USING ( SELECT
            dc.customer_key_nr,
            dc.ctry_of_residence_key,
            dc.customer_type_key
            FROM grid_derived_customer dc )
        src ON ( src.customer_key_nr = e.customer_key_nr )
        WHEN MATCHED THEN UPDATE SET ctry_of_residence_key = src.ctry_of_residence_key,
        customer_type_key = src.customer_type_key;

    EXCEPTION
        WHEN OTHERS THEN
            RAISE;
    END;
    COMMIT;
    BEGIN
        MERGE INTO (select higher_level_key,parent_code from tt_tmp_ing_legal_entity) t1 
        USING ( SELECT
            t2.ing_legal_entity_key,
            t2.ing_legal_entity_code
            FROM tt_tmp_ing_legal_entity t2 )
        src ON ( t1.higher_level_key = src.ing_legal_entity_key )
        WHEN MATCHED THEN UPDATE SET parent_code = src.ing_legal_entity_code;
        
    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;

    BEGIN
        MERGE INTO (select ing_legal_entity_code,exclude_from_solo from tt_tmp_ing_legal_entity 
        where record_valid_until IS NULL) t1 
        USING ( SELECT
            t2.record_valid_until,
            t2.code,
            t2.exclude_from_solo
            FROM entity t2 
            WHERE t2.record_valid_until IS NULL)
        src ON ( t1.ing_legal_entity_code = src.code )
        WHEN MATCHED THEN UPDATE SET exclude_from_solo = src.exclude_from_solo;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    BEGIN
        INSERT  INTO tt_entity_tree
            ( SELECT
                par.ing_legal_entity_code parent_code,
                chd.ing_legal_entity_code child_code,
                par.ing_legal_entity_key parent_key,
                chd.ing_legal_entity_key child_key,
                1 level_parent,
                chd.hierarchy_level level_child
              FROM tt_tmp_ing_legal_entity chd
              JOIN tt_tmp_ing_legal_entity par
              ON chd.ing_legal_entity_key <> chd.highest_level_key
                AND   chd.highest_level_key = par.ing_legal_entity_key
                AND   par.hierarchy_level = 1
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    BEGIN
        INSERT  INTO tt_entity_tree (
            parent_code,
            child_code,
            parent_key,
            child_key,
            level_parent,
            level_child
        )
            ( SELECT
                ing_legal_entity_code,
                ing_legal_entity_code,
                ing_legal_entity_key,
                ing_legal_entity_key,
                hierarchy_level,
                hierarchy_level
              FROM
                tt_tmp_ing_legal_entity
            );

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    BEGIN
        SELECT
            MAX(hierarchy_level)
        INTO
            v_max_level
        FROM
            tt_tmp_ing_legal_entity;

        v_level_parent := 2;
    EXCEPTION
        WHEN OTHERS THEN
            v_max_level := 0;
    END;

    BEGIN
        WHILE v_level_parent <= v_max_level LOOP
            BEGIN
                v_level_child := v_level_parent;
                WHILE v_level_child <= v_max_level LOOP
                    BEGIN
                        INSERT  INTO tt_entity_tree (
                            parent_key,
                            child_key,
                            parent_code,
                            child_code,
                            level_parent,
                            level_child
                        )
                            ( SELECT
                                tr.parent_key parent_key,
                                src.ing_legal_entity_key child_key,
                                tr.parent_code parent_code,
                                src.ing_legal_entity_code child_code,
                                tr.level_parent level_parent,
                                src.hierarchy_level level_child
                              FROM
                                tt_tmp_ing_legal_entity src
                                JOIN tt_entity_tree tr
                                 ON src.higher_level_key = tr.child_key
                                                           AND tr.level_parent = v_level_parent
                                                           AND tr.level_child = v_level_child
                            );

                        v_level_child := v_level_child + 1;

                    END;
                END LOOP;

                v_level_parent := v_level_parent + 1;

            END;
        END LOOP;
    END;
    COMMIT;

    BEGIN
        INSERT  INTO entity_hierarchy
            ( SELECT
                lent.ing_legal_entity_key,
                lent.ing_legal_entity_code,
                lent.ing_legal_entity_descr,
                lent.ing_legal_entity_descr_xml,
                lent.record_valid_from,
                lent.record_valid_until,
                lent.higher_level_key,
                lent.highest_level_key,
                lent.higher_level_cust_id,
                lent.highest_level_cust_id,
                lent.hierarchy_level,
                et.level_parent level_parent,
                et.parent_key parent_ing_legal_entity_key,
                et.parent_code parent_ing_legal_entity_code,
                lent.basic_customer_key,
                lent.customer_key_nr,
                lent.customer_id,
                lent.city,
                lent.city_xml,
                lent.ctry_of_residence_key,
                lent.search_name,
                lent.search_name_xml,
                lent.branch_indicator,
                lent.customer_type_key,
                lent.cus_record_valid_from,
                lent.ing_entity,
                lent.recent,
                lent.parent_code,
                lent.exclude_from_solo
              FROM
                tt_entity_tree et
                JOIN tt_tmp_ing_legal_entity lent ON et.child_key = lent.ing_legal_entity_key
            );

        v_debug_msg := $$plsql_line
        || ' of plsql unit '
        || $$plsql_unit
        || ' INSERT INTO entity_hierarchy'
        || SQL%rowcount;

    EXCEPTION
        WHEN OTHERS THEN
            utils.handleerror(
                sqlcode,
                sqlerrm
            );
    END;
    COMMIT;
    utilities.truncate_table('tt_tmp_ing_legal_entity');
    utilities.truncate_table('tt_legal_entity_until');
    utilities.truncate_table('tt_legal_entity_from');
    utilities.truncate_table('tt_dmi_system_configuration');
    utilities.truncate_table('tt_ing_entity_exceptions');
    utilities.truncate_table('tt_entity_tree');
EXCEPTION
    WHEN OTHERS THEN
        utils.handleerror(
            sqlcode,
            sqlerrm
        );
END;
/
show errors;