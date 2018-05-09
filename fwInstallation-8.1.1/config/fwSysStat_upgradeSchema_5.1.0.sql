ALTER TABLE FW_SYS_STAT_SYS_CURR_CONNECT  DROP CONSTRAINT COMPUTER_COMP_ID_FK;
ALTER TABLE FW_SYS_STAT_SYS_CURR_CONNECT  DROP CONSTRAINT C_SYSTEM_PEER_1_ID_FK;
ALTER TABLE FW_SYS_STAT_SYS_CURR_CONNECT  DROP CONSTRAINT C_SYSTEM_PEER_2_ID_FK;
ALTER TABLE FW_SYS_STAT_SYS_CURR_CONNECT ADD (
	CONSTRAINT COMPUTER_COMP_ID_FK FOREIGN KEY (COMPUTER_ID) REFERENCES FW_SYS_STAT_COMPUTER (ID) ON DELETE CASCADE,
	CONSTRAINT C_SYSTEM_PEER_1_ID_FK FOREIGN KEY (PEER_1_ID) REFERENCES FW_SYS_STAT_PVSS_SYSTEM (ID) ON DELETE CASCADE,
	CONSTRAINT C_SYSTEM_PEER_2_ID_FK FOREIGN KEY (PEER_2_ID) REFERENCES FW_SYS_STAT_PVSS_SYSTEM (ID) ON DELETE CASCADE);

ALTER TABLE fw_sys_stat_project_status DROP CONSTRAINT COMPUTER_PROJECT_STATUS_FK;
ALTER TABLE fw_sys_stat_project_status DROP CONSTRAINT PROJECT_PROJECT_STATUS_FK;
ALTER TABLE fw_sys_stat_project_status ADD (
	CONSTRAINT COMPUTER_PROJECT_STATUS_FK FOREIGN KEY (COMPUTER_ID) REFERENCES FW_SYS_STAT_COMPUTER (ID) ON DELETE CASCADE,
	CONSTRAINT PROJECT_PROJECT_STATUS_FK FOREIGN KEY (PROJECT_ID) REFERENCES FW_SYS_STAT_PVSS_PROJECT (ID) ON DELETE CASCADE);

ALTER TABLE fw_sys_stat_pvss_project ADD EVENT char(1);

UPDATE fw_sys_stat_pvss_project p set EVENT = 'Y' where p.id in (SELECT proj.id FROM fw_sys_stat_pvss_system s, fw_sys_stat_pvss_project proj
																 WHERE  proj.system_id = s.id AND proj.computer_id = s.computer_id AND proj.redu_computer_id = s.redu_computer_id);
UPDATE fw_sys_stat_pvss_project p set EVENT = 'Y' where p.id in (SELECT proj.id FROM fw_sys_stat_pvss_system s, fw_sys_stat_pvss_project proj
																 WHERE  proj.system_id = s.id AND proj.computer_id = s.computer_id AND proj.redu_computer_id = s.redu_computer_id);
UPDATE fw_sys_stat_pvss_project p set EVENT = 'N' where EVENT is null;
COMMIT;
UPDATE   fw_sys_stat_pvss_project set redu_computer_id = computer_id where redu_computer_id is null or redu_computer_id = -1;
COMMIT;
ALTER TABLE fw_sys_stat_pvss_system DROP (computer_id, redu_computer_id);

ALTER TABLE fw_sys_stat_pvss_project DROP (is_project_ok, is_pvss_ok, is_patch_ok, is_host_ok, is_path_ok, is_manager_ok, is_component_ok, is_dist_peers_ok, last_time_checked, need_synchronize);

--CREATE OR REPLACE TRIGGER fw_sys_stat_pvss_project_ac
--  AFTER UPDATE OR INSERT OR DELETE ON fw_sys_stat_pvss_project
--  FOR EACH ROW
--BEGIN
--	put_need_synchronize();
--END;
--/

CREATE OR REPLACE TRIGGER fw_sys_stat_pvss_system_bc
  BEFORE UPDATE ON fw_sys_stat_pvss_system
  FOR EACH ROW
BEGIN
	set_need_synchronize(:new.id);
END;
/
CREATE OR REPLACE TRIGGER fw_sys_stat_pvss_system_ac
  AFTER UPDATE ON fw_sys_stat_pvss_system
BEGIN
	put_sys_need_synchronize();
END;
/
CREATE OR REPLACE TRIGGER fw_sys_stat_pvss_project_bc
  BEFORE UPDATE OR INSERT ON fw_sys_stat_pvss_project
  FOR EACH ROW
  DECLARE pID number;
BEGIN
	IF DELETING THEN
	    pID := :old.id;
	ELSE
	    pID := :new.id;
	END IF;
	set_need_synchronize(pID);

	IF (:new.COMPUTER_ID != :old.COMPUTER_ID) THEN
		DELETE FROM  fw_sys_stat_proj_file_issues WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.COMPUTER_ID;
		UPDATE fw_sys_stat_project_status SET computer_id = :new.computer_id WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.COMPUTER_ID;
	END IF;
	IF (:new.REDU_COMPUTER_ID != :old.REDU_COMPUTER_ID) THEN
		DELETE FROM  fw_sys_stat_proj_file_issues WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.REDU_COMPUTER_ID;
		UPDATE fw_sys_stat_project_status SET computer_id = :new.redu_computer_id WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.redu_computer_id;
	END IF ;

	IF (DELETING) THEN -- or (UPDATING('VALID_UNTIL') AND :new.valid_until is not null)) THEN
		DELETE FROM  fw_sys_stat_pvss_system where NOT EXISTS(SELECT * from fw_sys_stat_pvss_project where system_id = :old.system_id);
		DELETE FROM fw_sys_stat_project_status where project_id = :old.id  and computer_id in (:new.computer_id, :new.redu_computer_id);
	END IF;

END;
/
CREATE OR REPLACE TRIGGER fw_sys_stat_pvss_project_ac
  AFTER UPDATE OR INSERT ON fw_sys_stat_pvss_project
  FOR EACH ROW
BEGIN
	IF ((UPDATING('REDU_COMPUTER_ID') AND :new.REDU_COMPUTER_ID IS NULL) OR (UPDATING('COMPUTER_ID') AND :new.COMPUTER_ID IS NULL)) THEN
	  DBMS_OUTPUT.PUT_LINE('IGNORING UPDATE ON PROJECTS TABLE DUE TO COMPUTER_ID OR REDU_COMPUTER_ID BEING SET TO NULL');
	ELSE
	  put_need_synchronize();
	END IF;
END;
/

CREATE OR REPLACE TRIGGER FW_SYS_STAT_PROJCONF_UPDATE
   AFTER UPDATE OR INSERT OR DELETE ON FW_SYS_STAT_PROJ_CONFS
  FOR EACH ROW
DECLARE pID number;
BEGIN
dbms_output.put_line('Fired');
	IF DELETING THEN
	    pID := :old.project_id;
	ELSE
	    pID := :new.project_id;
	END IF;
	set_need_synchronize(pID);
	--update fw_sys_stat_pvss_project set need_synchronize = 'Y' where id = pId;
END;
/

--Upgrade Schema version
CREATE OR REPLACE VIEW fw_sys_stat_schema (version) AS
	SELECT '5.1.0'
	FROM dual;
COMMIT;