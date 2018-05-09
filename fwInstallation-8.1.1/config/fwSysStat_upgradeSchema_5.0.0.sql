ALTER TABLE FW_SYS_STAT_PROJECT_MANAGER 
	ADD computer_id number;         
ALTER TABLE FW_SYS_STAT_PROJECT_MANAGER	
	ADD CONSTRAINT computer_project_manaer_fk
	FOREIGN KEY (computer_id)
	REFERENCES fw_sys_stat_computer(id) ON DELETE CASCADE;
UPDATE FW_SYS_STAT_PROJECT_MANAGER
SET FW_SYS_STAT_PROJECT_MANAGER.computer_id =  (select computer_id
			  from fw_sys_stat_pvss_project
			  where  fw_sys_stat_pvss_project.id = 	FW_SYS_STAT_PROJECT_MANAGER.project_id
);
COMMIT;

ALTER TABLE FW_SYS_STAT_PROJ_INST_LOG
	ADD computer_id number;
ALTER TABLE FW_SYS_STAT_PROJ_INST_LOG
	ADD CONSTRAINT computer_proj_inst_log_fk
	FOREIGN KEY (computer_id)
	REFERENCES fw_sys_stat_computer(id) ON DELETE CASCADE;
UPDATE FW_SYS_STAT_PROJ_INST_LOG
SET FW_SYS_STAT_PROJ_INST_LOG.computer_id =  (select computer_id
			  from fw_sys_stat_pvss_project
			  where  fw_sys_stat_pvss_project.id = 	FW_SYS_STAT_PROJ_INST_LOG.project_id
);
COMMIT;

ALTER TABLE FW_SYS_STAT_TOOL_UPGRADE
	ADD computer_id number;
ALTER TABLE FW_SYS_STAT_TOOL_UPGRADE
	ADD CONSTRAINT computer_tool_upgrade_fk
	FOREIGN KEY (computer_id)
	REFERENCES fw_sys_stat_computer(id) ON DELETE CASCADE;
UPDATE FW_SYS_STAT_TOOL_UPGRADE
SET FW_SYS_STAT_TOOL_UPGRADE.computer_id =  (select computer_id
			  from fw_sys_stat_pvss_project
			  where  fw_sys_stat_pvss_project.id = 	FW_SYS_STAT_TOOL_UPGRADE.project_id
);
COMMIT;

ALTER TABLE FW_SYS_STAT_FORCE_REINSTALL
	ADD computer_id number;
ALTER TABLE FW_SYS_STAT_FORCE_REINSTALL
	ADD CONSTRAINT computer_force_reinstall_fk
	FOREIGN KEY (computer_id)
	REFERENCES fw_sys_stat_computer(id) ON DELETE CASCADE;
UPDATE FW_SYS_STAT_FORCE_REINSTALL
SET FW_SYS_STAT_FORCE_REINSTALL.computer_id =  (select computer_id
			  from fw_sys_stat_pvss_project
			  where  fw_sys_stat_pvss_project.id = 	FW_SYS_STAT_FORCE_REINSTALL.project_id
);
COMMIT;

ALTER TABLE fw_sys_stat_pvss_system
	ADD redu_computer_id number;
ALTER TABLE fw_sys_stat_pvss_system
	ADD CONSTRAINT computer_redu_comp_id_fk
	FOREIGN KEY (redu_computer_id)
	REFERENCES fw_sys_stat_computer(id);	
UPDATE 	fw_sys_stat_pvss_system
	SET redu_computer_id = computer_id;
COMMIT;

CREATE TABLE fw_sys_stat_sys_curr_connect
			 (peer_1_id 			NUMBER,
			  peer_2_id 			NUMBER,
			  computer_id			NUMBER,
			  valid_from 			DATE default SYSDATE,
              valid_until			DATE,			  
			  CONSTRAINT c_peer_1_2_uq UNIQUE (peer_1_id, peer_2_id, computer_id));

ALTER TABLE fw_sys_stat_sys_curr_connect
	ADD CONSTRAINT c_system_peer_1_id_fk
	FOREIGN KEY (peer_1_id)
	REFERENCES fw_sys_stat_pvss_system(id);


ALTER TABLE fw_sys_stat_sys_curr_connect
	ADD CONSTRAINT c_system_peer_2_id_fk
	FOREIGN KEY (peer_2_id)
	REFERENCES fw_sys_stat_pvss_system(id);

ALTER TABLE fw_sys_stat_sys_curr_connect
	ADD CONSTRAINT computer_comp_id_fk
	FOREIGN KEY (computer_id)
	REFERENCES fw_sys_stat_computer(id);

INSERT INTO fw_sys_stat_sys_curr_connect(peer_1_id, peer_2_id, computer_id, valid_from, valid_until)
	SELECT a.peer_1_id, a.peer_2_id, b.computer_id, a.valid_from, a.valid_until
	FROM fw_sys_stat_system_connect a, fw_sys_stat_pvss_system b
	WHERE a.valid_until IS NULL AND a.peer_1_id = b.id;	
COMMIT;

CREATE TABLE fw_sys_stat_current_inst_path
             (id 					NUMBER,
              project_id				NUMBER,
              computer_id				NUMBER,
              path					VARCHAR2(1024),
			  valid_from 			DATE default SYSDATE,
              valid_until			DATE,
              CONSTRAINT c_installtion_path_id_pk PRIMARY KEY (id),
              CONSTRAINT c_computer_path_fk FOREIGN KEY (computer_id) REFERENCES fw_sys_stat_computer(id) ON DELETE CASCADE) ;
CREATE SEQUENCE fw_sys_stat_curr_inst_path_sq
    MINVALUE 1
    MAXVALUE 9999999
    START WITH 1
    INCREMENT BY 1
    NOCACHE;
INSERT INTO fw_sys_stat_current_inst_path(id, project_id, path, computer_id, valid_from, valid_until)
	SELECT fw_sys_stat_curr_inst_path_sq.nextVal, a.project_id, a.path, b.computer_id, a.valid_from, a.valid_until
	FROM fw_sys_stat_inst_path a, fw_sys_stat_pvss_project b
	WHERE a.valid_until IS NULL AND a.project_id = b.id;
COMMIT;

CREATE TABLE fw_sys_stat_project_status
             (id 						NUMBER,
              project_id				NUMBER,
              computer_id				NUMBER,
              is_project_ok				NUMBER,
              is_pvss_ok				NUMBER,
              is_patch_ok				NUMBER,
              is_host_ok				NUMBER,
              is_path_ok				NUMBER,
              is_manager_ok				NUMBER,
              is_component_ok			NUMBER,
              is_dist_peers_ok   		NUMBER,
              last_time_checked			DATE,
			  need_synchronize			CHAR(1),
              CONSTRAINT project_status_id_pk PRIMARY KEY (id),
              CONSTRAINT computer_project_status_fk FOREIGN KEY (computer_id) REFERENCES fw_sys_stat_computer(id) ON DELETE CASCADE,
              CONSTRAINT project_project_status_fk FOREIGN KEY (project_id) REFERENCES fw_sys_stat_pvss_project(id) ON DELETE CASCADE);	
CREATE SEQUENCE fw_sys_stat_project_status_sq
    MINVALUE 1
    MAXVALUE 9999999
    START WITH 1
    INCREMENT BY 1
    NOCACHE;			  
INSERT INTO fw_sys_stat_project_status (id, project_id, computer_id, is_project_ok, is_pvss_ok, is_patch_ok, is_manager_ok, is_component_ok, last_time_checked, is_dist_peers_ok, need_synchronize, is_host_ok, is_path_ok)
	SELECT fw_sys_stat_project_status_sq.nextVal, id, computer_id, is_project_ok, is_pvss_ok, is_patch_ok, is_manager_ok, is_component_ok, last_time_checked, is_dist_peers_ok, need_synchronize, is_host_ok, is_path_ok
	FROM fw_sys_stat_pvss_project;
COMMIT;
INSERT INTO fw_sys_stat_project_status (id, project_id, computer_id, is_project_ok, is_pvss_ok, is_patch_ok, is_manager_ok, is_component_ok, last_time_checked, is_dist_peers_ok, need_synchronize, is_host_ok, is_path_ok)
	SELECT fw_sys_stat_project_status_sq.nextVal, id, redu_computer_id, is_project_ok, is_pvss_ok, is_patch_ok, is_manager_ok, is_component_ok, last_time_checked, is_dist_peers_ok, need_synchronize, is_host_ok, is_path_ok
	FROM fw_sys_stat_pvss_project
	where redu_computer_id <> computer_id;
COMMIT;	
CREATE OR REPLACE TRIGGER fw_sys_stat_pvss_project_ac
  AFTER UPDATE OF  last_time_checked, need_synchronize  ON fw_sys_stat_pvss_project
  FOR EACH ROW
BEGIN
	UPDATE fw_sys_stat_project_status SET
	is_project_ok = :new.is_project_ok,
	is_pvss_ok = :new.is_pvss_ok,
	is_patch_ok = :new.is_patch_ok,
	is_host_ok = :new.is_host_ok,
	is_path_ok = :new.is_path_ok,
	is_manager_ok = :new.is_manager_ok,
	is_component_ok = :new.is_component_ok,
	last_time_checked = :new.last_time_checked,
	is_dist_peers_ok = :new.is_dist_peers_ok,
	need_synchronize = :new.need_synchronize
	WHERE  fw_sys_stat_project_status.project_id = :new.id AND  fw_sys_stat_project_status.computer_id = :new.computer_id ;
END;
/
CREATE OR REPLACE TRIGGER fw_sys_stat_pvss_project_bc
  BEFORE UPDATE OF COMPUTER_ID, REDU_COMPUTER_ID, CENTRALLY_MANAGED, SYSTEM_ID ON fw_SYS_STAT_PVSS_PROJECT
  FOR EACH ROW
BEGIN
	IF (NOT UPDATING('COMPUTER_ID')) THEN 
		UPDATE fw_sys_stat_project_status SET need_synchronize = 'Y' WHERE PROJECT_ID = :old.ID; /* might be multiple rows */
	END IF;

	IF (:new.COMPUTER_ID != :old.COMPUTER_ID) THEN
		DELETE FROM  fw_sys_stat_proj_file_issues WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.COMPUTER_ID;
		UPDATE fw_sys_stat_project_status SET computer_id = :new.computer_id WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.COMPUTER_ID;
	END IF;
	IF (:new.REDU_COMPUTER_ID != :old.REDU_COMPUTER_ID) THEN
		DELETE FROM  fw_sys_stat_proj_file_issues WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.REDU_COMPUTER_ID;
		UPDATE fw_sys_stat_project_status SET computer_id = :new.redu_computer_id WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.redu_computer_id;
	END IF ;
END;
/	
CREATE OR REPLACE PROCEDURE put_need_synchronize AS
BEGIN
	UPDATE fw_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
	WHERE fw_SYS_STAT_PROJECT_STATUS.project_id IN (SELECT project_id FROM need_synchronize_4091);

	DELETE FROM need_synchronize_4091;
END;
/
CREATE OR REPLACE PROCEDURE put_sys_need_synchronize AS
BEGIN
	UPDATE fw_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
	WHERE project_id IN (
		SELECT p.id as project_id FROM fw_SYS_STAT_PVSS_PROJECT p, need_synchronize_4091 ns
		WHERE p.system_id = ns.project_id
	);

	DELETE FROM need_synchronize_4091;
END;
/
CREATE OR REPLACE PROCEDURE put_group_need_synchronize AS
BEGIN
	UPDATE fw_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
	WHERE PROJECT_ID IN (
		SELECT PROJECT_ID FROM FW_SYS_STAT_PROJECT_GROUPS WHERE GROUP_ID IN (
			SELECT project_id AS group_id FROM need_synchronize_4091
		)
	);

	DELETE FROM need_synchronize_4091;
END;
/

ALTER TABLE FW_SYS_STAT_PROJ_INST_LOG DROP CONSTRAINT FW_SYS_STAT_PROJ_LOG_FK;
ALTER TABLE FW_SYS_STAT_PROJ_INST_LOG ADD CONSTRAINT FW_SYS_STAT_PROJ_LOG_FK FOREIGN KEY (PROJECT_ID) REFERENCES FW_SYS_STAT_PVSS_PROJECT (ID) ON DELETE CASCADE;

ALTER TABLE fw_sys_stat_pvss_project
ADD INSTALL_ONLY_IN_SPLIT NUMBER DEFAULT 0;

ALTER TABLE fw_sys_stat_pvss_project
ADD RESTORE_REDUNDANCY_AFTER_INST NUMBER DEFAULT 0;

ALTER SEQUENCE FW_SYS_STAT_PROJ_INST_LOG_SQ NOMAXVALUE;

CREATE OR REPLACE VIEW fw_sys_stat_schema (version) AS
	SELECT '5.0.0'
	FROM dual;
COMMIT;