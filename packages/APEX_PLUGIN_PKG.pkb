create or replace PACKAGE BODY     "APEX_PLUGIN_PKG" AS

    gv_playground_host VARCHAR2(100) := 'PLAYGROUND';

    FUNCTION f_is_playground RETURN BOOLEAN IS
        v_ax_workspace VARCHAR2(200);
    BEGIN
        SELECT apex_util.find_workspace( (SELECT apex_application.get_security_group_id FROM dual) )
        INTO
            v_ax_workspace
        FROM dual;

        IF
            gv_playground_host = v_ax_workspace
        THEN
            RETURN true;
        ELSE
            RETURN false;
        END IF;
    END f_is_playground;

    PROCEDURE res_out ( p_clob CLOB ) IS
        v_char VARCHAR2(32000);
        v_clob CLOB := p_clob;
    BEGIN
        WHILE length(v_clob) > 0 LOOP
            BEGIN
                IF
                    length(v_clob) > 32000
                THEN
                    v_char := substr(v_clob,1,32000);
                    sys.htp.prn(v_char);
                    v_clob := substr(
                        v_clob,length(v_char) + 1
                    );
                ELSE
                    v_char := v_clob;
                    sys.htp.prn(v_char);
                    v_char := '';
                    v_clob := '';
                END IF;

            END;
        END LOOP;
    END res_out;

    FUNCTION esc ( p_txt VARCHAR2 ) RETURN VARCHAR2
        IS
    BEGIN
        RETURN sys.htf.escape_sc(p_txt);
    END esc;

    FUNCTION mapbox_zoom_to_adapter_render (
        p_dynamic_action IN apex_plugin.t_dynamic_action,p_plugin IN apex_plugin.t_plugin
    ) RETURN apex_plugin.t_dynamic_action_render_result IS

        v_exe_code CLOB;
        v_region_id VARCHAR2(200);
        v_bbox_aitem VARCHAR2(200);
        v_zlevel_aitem VARCHAR2(200);
        v_ax_plg apex_plugin.t_dynamic_action_render_result;
    BEGIN
        apex_debug.info(' mapbox_zoom_to_adapter_render : %s',TO_CHAR(current_timestamp) );
        v_region_id := p_dynamic_action.attribute_01;
        v_zlevel_aitem := p_dynamic_action.attribute_02;
        IF
            f_is_playground = false
        THEN
            apex_javascript.add_library(
                p_name             => 'mapbox.zoomto.adapter',p_directory        => p_plugin.file_prefix,p_version          => NULL,p_skip_extension   => false
            );
        END IF;

        v_exe_code := 'window.apex.plugins.mapbox.zoomToAdapter = new apex.plugins.mapbox.MapBoxZoomToAdapter' ||'({ mapRegionId   :"' ||v_region_id ||'",' ||'   zoomLevelItem :"' ||v_zlevel_aitem ||'",' ||' });';

        apex_debug.info(' mapbox_zoom_to_adapter_render v_exe_code: %s',v_exe_code);
        apex_javascript.add_onload_code(
            p_code   => v_exe_code
        );
        v_ax_plg.javascript_function := 'window.apex.plugins.mapbox.zoomToAdapter.zoomTo()';
        RETURN v_ax_plg;
    END mapbox_zoom_to_adapter_render;

    FUNCTION mapbox_loadgeom_adapter_render (
        p_dynamic_action IN apex_plugin.t_dynamic_action,p_plugin IN apex_plugin.t_plugin
    ) RETURN apex_plugin.t_dynamic_action_render_result IS

        v_exe_code CLOB;
        v_region_id VARCHAR2(200);
        v_apex_item VARCHAR2(200);
        v_geom_style VARCHAR2(3000);
        v_zoom_to_g VARCHAR2(10) := 'false';
        v_ax_plg apex_plugin.t_dynamic_action_render_result;
    BEGIN
        v_region_id := p_dynamic_action.attribute_01;
        v_apex_item := p_dynamic_action.attribute_02;
        v_geom_style := p_dynamic_action.attribute_03;
        IF
            p_dynamic_action.attribute_04 = 'Y'
        THEN
            v_zoom_to_g := 'true';
        END IF;
        IF
            f_is_playground = false
        THEN
          apex_javascript.add_library(  p_name => 'mapbox.load.geometry.adapter',
										p_directory => p_plugin.file_prefix,
										p_version => NULL,
										p_skip_extension => FALSE );

            apex_debug.info(' mapbox_map_render f_is_playground: %s','false');
        END IF;

        v_exe_code := 'window.apex.plugins.mapbox.loadGeometryAdapter = new apex.plugins.mapbox.MapBoxLoadGeometryAdapter' ||'({ mapRegionId   :"' ||v_region_id ||'",' ||'   apexItem      :"' ||v_apex_item ||'",' ||'   zoomTo        : ' ||v_zoom_to_g ||' ,' ||'   style         : ' ||v_geom_style ||' ,' ||'   ajaxIdentifier:"' ||apex_plugin.get_ajax_identifier ||'" });';

        apex_debug.info(' mapbox_map_render v_exe_code: %s',v_exe_code);
        apex_javascript.add_onload_code(
            p_code   => v_exe_code
        );
        v_ax_plg.javascript_function := 'function(){window.apex.plugins.mapbox.loadGeometryAdapter.loadFromAjax()}';
        RETURN v_ax_plg;
    END mapbox_loadgeom_adapter_render;

    FUNCTION mapbox_loadgeom_adapter_ajax (
        p_dynamic_action IN apex_plugin.t_dynamic_action,p_plugin IN apex_plugin.t_plugin
    ) RETURN apex_plugin.t_dynamic_action_ajax_result IS

        v_result apex_plugin.t_dynamic_action_ajax_result;
        v_geojson CLOB;
        v_data_type VARCHAR2(200);
        ex_invalid_type EXCEPTION;
        v_cursor SYS_REFCURSOR;
            --
        v_id VARCHAR2(32000) := wwv_flow.g_x01;
        v_owner VARCHAR2(40) := p_dynamic_action.attribute_05;
        v_table VARCHAR2(40) := p_dynamic_action.attribute_06;
        v_column VARCHAR2(40) := p_dynamic_action.attribute_07;
        v_col_name_pk VARCHAR2(40) := p_dynamic_action.attribute_08;
        v_col_is_gjson VARCHAR2(1) := p_dynamic_action.attribute_09;
        v_query_sdo VARCHAR2(32000) := 'select ora2geojson.sdo2geojson(''select * from #USER#.#TABLE#''
                                       ,rowid
                                       ,#COLUMN#) geom
                       from #USER#.#TABLE# t'
;
        v_query_json VARCHAR2(32000) := 'select #COLUMN#
                       from #USER#.#TABLE# t';
        v_where VARCHAR2(200) := ' where t.#COLUMN_ID# = :pk_id';
    BEGIN
        IF v_col_name_pk IS NOT NULL
        THEN
            v_query_json := v_query_json || v_where;
            v_query_sdo := v_query_sdo || v_where;
        END IF;

        SELECT atc.data_type
        INTO
            v_data_type
        FROM all_tab_columns atc
            LEFT JOIN all_synonyms s ON ( atc.owner = s.table_owner
                AND atc.table_name = s.table_name
            )
        WHERE 1 = 1
            AND atc.table_name = v_table
            AND atc.column_name = v_column
            AND ( atc.owner = v_owner
                OR s.owner = v_owner
            )
        ORDER BY
            atc.owner,atc.table_name;

        IF v_col_name_pk IS NOT NULL
        THEN
            IF
                v_data_type = 'SDO_GEOMETRY' AND v_col_is_gjson = 'N'
            THEN
                v_query_sdo := replace(v_query_sdo,'#USER#',v_owner);
                v_query_sdo := replace(v_query_sdo,'#TABLE#',v_table);
                v_query_sdo := replace(v_query_sdo,'#COLUMN#',v_column);
                v_query_sdo := replace(v_query_sdo,'#COLUMN_ID#',v_col_name_pk);
                EXECUTE IMMEDIATE v_query_sdo INTO
                    v_geojson
                    USING v_id;
            ELSIF v_col_is_gjson = 'Y' AND v_data_type != 'SDO_GEOMETRY' THEN
                v_query_json := replace(v_query_json,'#USER#',v_owner);
                v_query_json := replace(v_query_json,'#TABLE#',v_table);
                v_query_json := replace(v_query_json,'#COLUMN#',v_column);
                v_query_json := replace(v_query_json,'#COLUMN_ID#',v_col_name_pk);
                EXECUTE IMMEDIATE v_query_json INTO
                    v_geojson
                    USING v_id;
            ELSIF v_col_is_gjson = 'N' THEN
                RAISE ex_invalid_type;
            END IF;

            res_out(v_geojson);
        ELSE
            IF
                v_data_type = 'SDO_GEOMETRY' AND v_col_is_gjson = 'N'
            THEN
                v_query_sdo := replace(v_query_sdo,'#USER#',v_owner);
                v_query_sdo := replace(v_query_sdo,'#TABLE#',v_table);
                v_query_sdo := replace(v_query_sdo,'#COLUMN#',v_column);
                OPEN v_cursor FOR v_query_sdo;

            ELSIF v_col_is_gjson = 'Y' AND v_data_type != 'SDO_GEOMETRY' THEN
                v_query_json := replace(v_query_json,'#USER#',v_owner);
                v_query_json := replace(v_query_json,'#TABLE#',v_table);
                v_query_json := replace(v_query_json,'#COLUMN#',v_column);
                OPEN v_cursor FOR v_query_json;

            ELSIF v_col_is_gjson = 'N' THEN
                RAISE ex_invalid_type;
            END IF;

            LOOP
                FETCH v_cursor INTO v_geojson;
                EXIT WHEN v_cursor%notfound;
                res_out(v_geojson);
            END LOOP;

        END IF;

        RETURN v_result;
    END mapbox_loadgeom_adapter_ajax;

    FUNCTION mapbox_map_render (
        p_region IN apex_plugin.t_region,p_plugin IN apex_plugin.t_plugin,p_is_printer_friendly IN BOOLEAN
    ) RETURN apex_plugin.t_region_render_result IS

        v_map_name VARCHAR2(2000);
        v_exe_code CLOB;
        v_width VARCHAR2(200);
        v_height VARCHAR2(200);
        v_init_view VARCHAR2(3000);
        v_region_id VARCHAR2(200);
        v_ax_plg apex_plugin.t_region_render_result;
    BEGIN
        apex_debug.info('mapbox_map_render: %s',TO_CHAR(current_timestamp) );
        v_map_name := p_region.attribute_01;
        v_width := p_region.attribute_02;
        v_height := p_region.attribute_03;
        v_init_view := p_region.attribute_04;
        v_region_id := p_region.static_id;
        IF v_region_id IS NULL
        THEN
            v_region_id := 'R' || p_region.id;
        END IF;
        IF
            f_is_playground = false
        THEN
            apex_javascript.add_library( p_name => 'mapbox.map',p_directory => p_plugin.file_prefix,p_version => NULL,p_skip_extension => false);
            apex_css.add_file(p_name => 'mapbox.map',p_directory   => p_plugin.file_prefix);
        END IF;
        v_exe_code := 'window.apex.plugins.mapbox.map = new apex.plugins.mapbox.mapBoxMap' ||'({ mapRegionContainer:"' ||v_region_id ||' .t-Region-body",' ||' 
        mapRegionId:"' ||v_region_id ||'",' ||'   mapName    :"' ||v_map_name ||'",' ||'   width      :"' ||v_width ||'",' ||'   height     :"' ||v_height ||'",' 
        ||'   initalView : ' ||v_init_view ||' });';
        apex_javascript.add_onload_code(
            p_code   => v_exe_code
        );
        RETURN v_ax_plg;
    END mapbox_map_render;

    FUNCTION mapbox_include (
        p_item IN apex_plugin.t_page_item,p_plugin IN apex_plugin.t_plugin,p_value IN VARCHAR2,p_is_readonly IN BOOLEAN,p_is_printer_friendly IN BOOLEAN
    ) RETURN apex_plugin.t_page_item_render_result IS
        --
        v_api_key VARCHAR2(2000);
        v_ax_plg apex_plugin.t_page_item_render_result;
        --
    BEGIN
        v_api_key := p_item.attribute_01;
        IF
            f_is_playground = false
        THEN
            apex_javascript.add_library( p_name => 'mapbox.init',p_directory => p_plugin.file_prefix,p_version => NULL,p_skip_extension   => false );
        END IF;

        apex_debug.info('mapbox_include v3.1.1: %s',TO_CHAR(current_timestamp) );
        res_out('<script src="https://api.mapbox.com/mapbox.js/v3.1.1/mapbox.js"></script>');
        res_out('<link href="https://api.mapbox.com/mapbox.js/v3.1.1/mapbox.css" rel="stylesheet" />');
        --Leaflet Draw plugin        
        res_out('<script src="https://api.mapbox.com/mapbox.js/plugins/leaflet-draw/v0.4.10/leaflet.draw.js"></script>');
        res_out('<link href="https://api.mapbox.com/mapbox.js/plugins/leaflet-draw/v0.4.10/leaflet.draw.css" rel="stylesheet" />');
        --
        
      	res_out('<script>');
        res_out('L.mapbox.accessToken = "' || v_api_key || '";');
        res_out('</script>');
        RETURN v_ax_plg;
    END mapbox_include;

    PROCEDURE update_geometry ( p_wkt VARCHAR2,p_id NUMBER ) IS
        l_user VARCHAR(2000);
    BEGIN
        l_user := v('USER');
        IF
                p_id IS NOT NULL
            AND p_wkt IS NOT NULL
        THEN
            UPDATE dbr.geometry_data
                SET
                    sdo_geom = mdsys.sdo_util.from_wktgeometry(p_wkt)
            WHERE id = p_id;

        END IF;

    END update_geometry;

END apex_plugin_pkg;
