CREATE OR REPLACE PACKAGE BODY "FW_SYS_STAT_SAS_TARGET_DB_PKG" 
AS

    PROCEDURE CREATE_PROJECT(p_proj_name in varchar2,
                             p_system_name in varchar2,
                             p_system_number  in number,
                             p_pmon_port in number,
                             p_data_port in number,
                             p_event_port in number,
                             p_dist_port in number,
                             p_redu_port in number,
                             p_split_port in number,
                             p_hostname in varchar2,
                             p_redu_hostname in varchar2,
                             p_is_redundant in boolean,
                             p_redu_peer in number,
                             p_responsible in varchar2,
                             p_pvss_version in varchar2,
                             p_created_by in varchar2,
                             p_service_account in varchar2,
                             p_jira_issue in varchar2)
    AS
        pragma autonomous_transaction;

        l_system_id  number;
        l_computer_id number := 1;
        l_redu_computer_id number := 1;
        l_project_id number;
        l_error_message varchar2(1000);
    BEGIN
        insert into fw_sys_stat_pvss_system(id, system_name, system_number, data_port, event_port, dist_port, valid_from, redu_port, split_port)
        values (fw_sys_stat_pvss_system_sq.nextval, p_system_name, p_system_number, p_data_port, p_event_port, p_dist_port, current_date, p_redu_port, p_split_port)
        returning id into l_system_id;

        l_computer_id := get_or_create_computer(p_hostname);
        if p_is_redundant then
            l_redu_computer_id := get_or_create_computer(p_redu_hostname);
        else
            l_redu_computer_id := l_computer_id;
        end if;

        insert into fw_sys_stat_pvss_project (id, computer_id, project_name, pmon_port, system_id, redu_computer_id, responsible, pvss_version, service_account, creation_jira_issue, created_by, status)
        values (fw_sys_stat_pvss_project_sq.nextval, l_computer_id, p_proj_name, p_pmon_port, l_system_id, l_redu_computer_id, p_responsible, p_pvss_version, p_service_account, p_jira_issue, p_created_by, 'CREATION_PENDING')
        returning id into l_project_id;

        insert into fw_sys_stat_project_status(id, project_id, computer_id, last_time_checked, need_synchronize)
        values (fw_sys_stat_project_status_sq.nextval, l_project_id, l_computer_id, sysdate, 'y');

        if p_is_redundant then
            insert into fw_sys_stat_project_status(id, project_id, computer_id, need_synchronize)
            values (fw_sys_stat_project_status_sq.nextval, l_project_id, l_redu_computer_id, 'y');
        end if;

        commit;
    END CREATE_PROJECT;
------------------------------------------------------------------------------------------------------

    PROCEDURE UPDATE_PROJECT_INFO(p_project_id in numeric,
                                  p_responsible in varchar2,
                                  p_status in varchar2,
                                  p_comment_text in varchar2,
                                  p_jira_issue in varchar2,
                                  p_wccoa_url in varchar2,
                                  p_info_url in varchar2,
                                  p_app_domain in varchar2,
                                  p_service_account in varchar2)
    AS
        l_domain_id number := null;
    BEGIN
        if length(p_app_domain) > 0 then
            begin
                select
                    id into l_domain_id 
                from
                    fw_sys_stat_application_domain 
                where
                    name = p_app_domain;
            exception
            when no_data_found then
                raise_application_error(-20000, 'Selected application domain "' || p_app_domain || '" cannot be found');
            end;
        end if;

        update
            fw_sys_stat_pvss_project proj
        set
            responsible = p_responsible,
            status = p_status,
            comment_text = p_comment_text,
            creation_jira_issue = p_jira_issue,
            wccoa_url = p_wccoa_url,
            info_url = p_info_url,
            application_domain_id = l_domain_id,
            service_account = p_service_account
        where
            proj.id = p_project_id;
    END UPDATE_PROJECT_INFO;
------------------------------------------------------------------------------------------------------

    PROCEDURE DELETE_PROJECT(p_project_id in numeric)
    AS
        -- l_computer_id number := -1;
        l_system_id number := -1;
    BEGIN
        select
            system_id into l_system_id 
        from
            fw_sys_stat_pvss_project 
        where
            id = p_project_id;
        
        delete from
            fw_sys_stat_pvss_project 
        where
            id = p_project_id;
        
        delete_system(l_system_id);
        -- delete_computer(l_computer_id);
    END DELETE_PROJECT;
------------------------------------------------------------------------------------------------------

    PROCEDURE DELETE_SYSTEM(p_system_id in numeric)
    AS
    BEGIN
        delete from
            fw_sys_stat_pvss_system 
        where
            id = p_system_id 
            and not exists (
                select
                    1
                from
                    fw_sys_stat_pvss_project
                where
                    system_id = p_system_id
            );
    END DELETE_SYSTEM;
------------------------------------------------------------------------------------------------------
	
    PROCEDURE INVALIDATE_PROJECT(p_project_id in numeric)
    AS
        l_system_id number := -1;
    BEGIN
        select
            system_id into l_system_id 
        from
            fw_sys_stat_pvss_project 
        where
            id = p_project_id;
        
        update
          fw_sys_stat_pvss_project 
        set
          valid_until = sysdate 
        where
          id = p_project_id;
        
        invalidate_system(l_system_id);
    END INVALIDATE_PROJECT;
------------------------------------------------------------------------------------------------------

    PROCEDURE INVALIDATE_SYSTEM(p_system_id in numeric)
    AS
    BEGIN
        update
            fw_sys_stat_pvss_system 
        set
            valid_until = sysdate
        where
            id = p_system_id 
            and not exists (
                select 1
                from
                    fw_sys_stat_pvss_project
                where
                    valid_until is null
                    and system_id = p_system_id
            );
    END INVALIDATE_SYSTEM;
------------------------------------------------------------------------------------------------------

    FUNCTION GET_OR_CREATE_COMPUTER(p_computer_hostname in varchar2) RETURN number
    AS
        l_computer_count number := 0;
        l_computer_id number := 0;
    BEGIN
        select
            count(id) into l_computer_count 
        from
            fw_sys_stat_computer computer 
        where
            upper(computer.hostname) = upper(p_computer_hostname) 
            and valid_until is null;
          
        if l_computer_count = 0 then
            insert into fw_sys_stat_computer (id, hostname)
            values (fw_sys_stat_computer_sq.nextval, upper(p_computer_hostname))
            returning id into l_computer_id;
        else
            select
                id into l_computer_id 
            from
                fw_sys_stat_computer computer 
            where
                upper(computer.hostname) = upper(p_computer_hostname) 
                and valid_until is null;
        end if;
        
        RETURN l_computer_id;

    END GET_OR_CREATE_COMPUTER;
------------------------------------------------------------------------------------------------------

    PROCEDURE UPDATE_COMPUTER_INFO(p_computer_id in numeric,
                                   p_wccoa_install_pkg in varchar2,
                                   p_responsible in varchar2,
                                   p_memory_info in varchar2,
                                   p_cpu_info in varchar2,
                                   p_description in varchar2,
                                   p_status in varchar2,
                                   p_comment_text in varchar2)
    AS
    BEGIN
        update
            fw_sys_stat_computer comp
        set
            wccoa_install_pkg = p_wccoa_install_pkg,
            responsible = p_responsible,
            memory_info = p_memory_info,
            cpu_info = p_cpu_info,
            description = p_description,
            status = p_status,
            comment_text = p_comment_text
        where
            comp.id = p_computer_id;
     END UPDATE_COMPUTER_INFO;              
------------------------------------------------------------------------------------------------------

    PROCEDURE DELETE_COMPUTER(p_computer_id in numeric)
    AS
    BEGIN
        delete from
            fw_sys_stat_computer 
        where
            id = p_computer_id 
            and not exists(
                select 1
                from
                    fw_sys_stat_pvss_project
                where
                    computer_id = p_computer_id
            ) 
            and not exists (
                select 1
                from
                    fw_sys_stat_pvss_project
                where
                    redu_computer_id = p_computer_id
            );
    END DELETE_COMPUTER;
------------------------------------------------------------------------------------------------------
    
    PROCEDURE INVALIDATE_COMPUTER(p_computer_id in numeric)
    AS
    BEGIN
        update
            fw_sys_stat_computer 
        set
            valid_until = sysdate
        where
            id = p_computer_id 
            and not exists (
                select 1
                from
                    fw_sys_stat_pvss_project
                where
                    valid_until is null
                    and computer_id = p_computer_id
            );
    END INVALIDATE_COMPUTER;
------------------------------------------------------------------------------------------------------

    FUNCTION IS_DOMAIN_RESPONSIBLE(p_username in varchar2, p_project_id in numeric) RETURN boolean
    AS
        l_responsible fw_sys_stat_application_domain.contact_person%type := '';
    BEGIN
        begin
            select
                domain.contact_person into l_responsible
            from
                fw_sys_stat_pvss_project project,
                fw_sys_stat_application_domain domain 
            where
                project.application_domain_id = domain.id 
                and project.id = p_project_id;
        exception
        when no_data_found then
            l_responsible := '';
        end;
        RETURN upper(l_responsible)=upper(p_username);
    END IS_DOMAIN_RESPONSIBLE;
------------------------------------------------------------------------------------------------------

    FUNCTION GET_NEW_SYSTEM_NUMBER RETURN number
    AS
        l_system_nr number := -1;
    BEGIN
        select
            min(r) into l_system_nr
        from (
            select
                rownum r
            from
                dual
            connect by
                rownum <= 2048
            )
        where
            r not in (
                select
                    system_number
                from
                    fw_sys_stat_pvss_system
            );
        RETURN l_system_nr;
    END GET_NEW_SYSTEM_NUMBER;
------------------------------------------------------------------------------------------------------

    FUNCTION GET_PROJECT_PARAM_TYPES (p_param_family in varchar2) RETURN fw_proj_param_type_array
    AS
        l_params fw_proj_param_type_array;
    BEGIN
        select
            id, name bulk collect into l_params
        from
            fw_sys_stat_proj_param_types
        where
            family = p_param_family
        order by
            id;
            
        RETURN l_params;
    END GET_PROJECT_PARAM_TYPES;
------------------------------------------------------------------------------------------------------

    FUNCTION GET_PROJECT_PARAM_QUERY (p_param_family in varchar2, p_dblink_name in varchar2) RETURN varchar2
    AS
        l_ret varchar2(10000) := '';
        l_projtable varchar2(10) := 'p';
        l_paramtypetable varchar2(10) := 'pt';

        l_param_alias varchar2(100);
        l_selectcolumns varchar2(1000) := '';
        l_jointables varchar2(10000) := '';
        
        l_dblink varchar2(100);

        l_counter numeric := 1;
        
        l_params fw_proj_param_type_array;
    BEGIN
        l_selectcolumns := l_projtable || '.project_name ';
        if length(p_dblink_name) > 0 then
            l_dblink := '@' || p_dblink_name;
        end if;
      
        l_params := fw_sys_stat_sas_target_db_pkg.get_project_param_types(p_param_family);
        for i in nvl(l_params.first, 0) .. nvl(l_params.last, -1) loop
            l_param_alias := 'param' || l_counter;
            l_selectcolumns := l_selectcolumns || ', ' || l_param_alias || '.value "' || l_params(i).param_name || '"';
            l_jointables := l_jointables || ' left join fw_sys_stat_project_params' || l_dblink || ' ' || l_param_alias || ' on ' || l_param_alias || '.project_id = ' || l_projtable || '.id and ' || l_param_alias || '.param_type_id = ' || l_params(i).param_id;
            l_counter := l_counter + 1;
        end loop;
        RETURN 'select ' || l_selectcolumns || ' from fw_sys_stat_pvss_project' || l_dblink || ' ' || l_projtable || l_jointables;
    END GET_PROJECT_PARAM_QUERY;
------------------------------------------------------------------------------------------------------

    PROCEDURE CREATE_APP_DOMAIN(p_name in varchar2,
                                p_description in varchar2,
                                p_contact in varchar2)
    AS
    BEGIN
        insert into fw_sys_stat_application_domain (id, name, description, contact_person)
        values (fw_sys_stat_app_domain_sq.nextval, p_name, p_description, p_contact);
    END CREATE_APP_DOMAIN;
------------------------------------------------------------------------------------------------------

    PROCEDURE UPDATE_APP_DOMAIN(p_id in numeric,
                                p_name in varchar2,
                                p_description in varchar2,
                                p_contact in varchar2)
    AS
    BEGIN
        update
            fw_sys_stat_application_domain
        set
            name = p_name,
            description = p_description,
            contact_person = p_contact
        where
            id = p_id;
    END UPDATE_APP_DOMAIN;
------------------------------------------------------------------------------------------------------

    PROCEDURE DELETE_APP_DOMAIN(p_id in numeric)
    AS
    BEGIN
        update
            fw_sys_stat_pvss_project
        set
            application_domain_id = null
        where
            application_domain_id = p_id;

        delete from
            fw_sys_stat_application_domain
        where
            id = p_id;
    END DELETE_APP_DOMAIN;

END FW_SYS_STAT_SAS_TARGET_DB_PKG;