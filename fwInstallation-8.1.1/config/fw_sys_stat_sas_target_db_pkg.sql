CREATE OR REPLACE PACKAGE "FW_SYS_STAT_SAS_TARGET_DB_PKG" AS

    TYPE fw_proj_param_type_row IS RECORD ( param_id fw_sys_stat_proj_param_types.id%TYPE, param_name fw_sys_stat_proj_param_types.name%TYPE);
    TYPE fw_proj_param_type_array IS TABLE OF fw_proj_param_type_row;
  
    
    PROCEDURE CREATE_PROJECT(p_proj_name in varchar2,
                             p_system_name in varchar2,
                             p_system_number in number,
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
                             p_jira_issue in varchar2);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Creates new WINCCOA projects
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE UPDATE_PROJECT_INFO(p_project_id in numeric,
                                  p_responsible in varchar2,
                                  p_status in varchar2,
                                  p_comment_text in varchar2,
                                  p_jira_issue in varchar2,
                                  p_wccoa_url in varchar2,
                                  p_info_url in varchar2,
                                  p_app_domain in varchar2,
                                  p_service_account in varchar2);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Updates WinCC OA projects
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE DELETE_PROJECT(p_project_id in numeric);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Deletes a project
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE DELETE_SYSTEM(p_system_id in numeric);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Deletes a system
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE INVALIDATE_PROJECT(p_project_id in numeric);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Invalidates a project
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE INVALIDATE_SYSTEM(p_system_id in numeric);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Invalidates a system
------------------------------------------------------------------------------------------------------------------------

    FUNCTION GET_OR_CREATE_COMPUTER(p_computer_hostname in varchar2) RETURN number;
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Returns existing or creates a new computer
------------------------------------------------------------------------------------------------------------------------
  
    PROCEDURE UPDATE_COMPUTER_INFO(p_computer_id in numeric,
                                   p_wccoa_install_pkg in varchar2,
                                   p_responsible in varchar2,
                                   p_memory_info in varchar2,
                                   p_cpu_info in varchar2,
                                   p_description in varchar2,
                                   p_status in varchar2,
                                   p_comment_text in varchar2);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Updates information about computers
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE DELETE_COMPUTER(p_computer_id in numeric);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Deletes a computer
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE INVALIDATE_COMPUTER(p_computer_id in numeric);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Invalidates a computer
------------------------------------------------------------------------------------------------------------------------

    FUNCTION IS_DOMAIN_RESPONSIBLE(p_username in varchar2, p_project_id in numeric) RETURN boolean;
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Checks if the username is set as responsible for a domain the project belongs to
------------------------------------------------------------------------------------------------------------------------

    FUNCTION GET_NEW_SYSTEM_NUMBER RETURN number;
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Returns first available system number
------------------------------------------------------------------------------------------------------------------------
  
    FUNCTION GET_PROJECT_PARAM_TYPES (p_param_family in varchar2) RETURN fw_proj_param_type_array;
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Returns parameter types belonging to a parameter family
------------------------------------------------------------------------------------------------------------------------

    FUNCTION GET_PROJECT_PARAM_QUERY (p_param_family in varchar2, p_dblink_name in varchar2) RETURN varchar2;
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Generates a query to retrieve projects parameter setting
------------------------------------------------------------------------------------------------------------------------
  
    PROCEDURE CREATE_APP_DOMAIN(p_name in varchar2,
                                p_description in varchar2,
                                p_contact in varchar2);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Creates new application domain
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE UPDATE_APP_DOMAIN(p_id in numeric,
                                p_name in varchar2,
                                p_description in varchar2,
                                p_contact in varchar2);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Updates application domain
------------------------------------------------------------------------------------------------------------------------

    PROCEDURE DELETE_APP_DOMAIN(p_id in numeric);
------------------------------------------------------------------------------------------------------------------------
--  Description:
--     Deletes application domain by provided ID
------------------------------------------------------------------------------------------------------------------------

END FW_SYS_STAT_SAS_TARGET_DB_PKG;
