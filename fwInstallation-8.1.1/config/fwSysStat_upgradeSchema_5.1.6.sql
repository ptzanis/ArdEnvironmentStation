
--Adding/modifying foreign keys, adding ON DELETE CASCADE option (FWINS-1925)
-- 1. fw_sys_stat_current_inst_path table
-- delete all records with project_id that doesn't exist in fw_sys_stat_pvss_project table (otherwise adding foreign key will fail)
DELETE FROM fw_sys_stat_current_inst_path
WHERE
project_id not in (select id from fw_sys_stat_pvss_project);
-- add foreign key 
ALTER TABLE fw_sys_stat_current_inst_path
  ADD CONSTRAINT C_INST_PATH_PROJECT_ID_FK
  FOREIGN KEY (project_id)
  REFERENCES fw_sys_stat_pvss_project(id)
  ON DELETE CASCADE;
  
-- 2. fw_sys_stat_fsm_types table	
DELETE FROM fw_sys_stat_fsm_types
WHERE
system_id not in (select id from fw_sys_stat_pvss_system); --????

ALTER TABLE fw_sys_stat_fsm_types
  ADD CONSTRAINT FSM_TYPES_SYSTEM_ID_FK
  FOREIGN KEY (system_id)
  REFERENCES fw_sys_stat_pvss_system(id)
  ON DELETE CASCADE;

-- 3. fw_sys_stat_tool_upgrade	
-- drop old constraint
ALTER TABLE fw_sys_stat_tool_upgrade
  DROP CONSTRAINT PROJECT_TOOL_ID_FK;
-- add new one with on delete cascade enabled
ALTER TABLE fw_sys_stat_tool_upgrade
  ADD CONSTRAINT PROJECT_TOOL_ID_FK
  FOREIGN KEY (project_id)
  REFERENCES fw_sys_stat_pvss_project(id)
  ON DELETE CASCADE;
  
--Modify fw_sys_stat_wccoa_devices table - add new column MOON_INFO (FWINS-1973)
ALTER TABLE fw_sys_stat_wccoa_devices
  ADD MOON_INFO varchar2(800); 

--Creating/Replacing fw_sys_stat_devices view (FWINS-2025)
CREATE OR REPLACE VIEW fw_sys_stat_devices AS
	SELECT
		p.project_name,
		h.hostname,
		rh.hostname as redu_hostname,
		a.name as application_name,
		d.name as device_name,
		dt.name as device_type,
		d."COMMENT" as comments,
		d.moon_info
	FROM
		fw_sys_stat_pvss_project p
		join fw_sys_stat_computer h on (h.id = p.computer_id)
		join fw_sys_stat_computer rh on (rh.id = p.redu_computer_id)
		join FW_SYS_STAT_WCCOA_APPLICATIONS a on (a.project_id = p.id)
		join FW_SYS_STAT_WCCOA_DEVICES d on (d.application_id = a.id and d.project_id = p.id)
		join FW_SYS_STAT_WCCOA_DEVICE_TYPES dt on (dt.id = d.device_type_id)
	WHERE
		p.valid_until is null
		and h.valid_until is null
		and rh.valid_until is null
		and a.valid_until is null
		and d.valid_until is null;
		
--Modify view FW_SYS_STAT_PROJ_COMPS
--Project_id column was added
CREATE OR REPLACE FORCE VIEW FW_SYS_STAT_PROJ_COMPS AS
	SELECT
		P.ID as PROJECT_ID,
		PC.HOSTNAME,
		P.PROJECT_NAME,
		C.COMPONENT_NAME,
		P.CENTRALLY_MANAGED,
		C.COMPONENT_VERSION,
		C.IS_SUBCOMPONENT,
		C.IS_PATCH,
		GC.DESCRIPTION_FILE,
		PG.OVERWRITE_FILES,
		PG.FORCE_REQUIRED,
		PG.IS_SILENT,
		GC.VALID_FROM as M_VALID_FROM,
		PG.RESTART_PROJECT
	FROM 
		FW_SYS_STAT_PVSS_PROJECT p 
		join FW_SYS_STAT_PROJECT_GROUPS pg on pg.PROJECT_ID = p.ID
		join FW_SYS_STAT_GROUP_OF_COMP g on g.ID = pg.GROUP_ID
		join FW_SYS_STAT_COMP_IN_GROUPS GC on GC.GROUP_ID = g.ID 
		join FW_SYS_STAT_COMPONENT c on c.ID = GC.FW_COMPONENT_ID 
		join FW_SYS_STAT_COMPUTER pc on (PC.ID = P.COMPUTER_ID OR PC.ID = P.REDU_COMPUTER_ID) 
	WHERE
		p.valid_until is null
		and pg.VALID_UNTIL is null
		and GC.VALID_UNTIL is null
		and c.VALID_UNTIL is null
		AND PC.VALID_UNTIL IS NULL;

--Update schema version
CREATE OR REPLACE VIEW fw_sys_stat_schema (version) AS
	SELECT '5.1.6'
	FROM dual;
	
COMMIT;