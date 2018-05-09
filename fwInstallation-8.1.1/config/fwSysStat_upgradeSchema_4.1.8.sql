--FW SYSTEM CONFIGURATION DATABASE: PATCH FOR SCHEMA VERSION 4.1.8
--Main modifications:
--  Added list of component files having issues in a project, e.g. file hash does not match the hash code of the file in the repository or overparameterized files:
CREATE TABLE fw_sys_stat_proj_f_issue_type
   		     (
   		        id			number,
   		      	issue_type	VARCHAR2(32) UNIQUE NOT NULL,
   		      	CONSTRAINT file_issue_type_pk PRIMARY KEY (id)
   		     );

CREATE SEQUENCE FW_SYS_STAT_PROJ_F_IS_TYPE_SQ
    MINVALUE 1
    MAXVALUE 100
    START WITH 1
    INCREMENT BY 1
    NOCACHE;

insert into fw_sys_stat_proj_f_issue_type(id, issue_type) values(FW_SYS_STAT_PROJ_F_IS_TYPE_SQ.nextval, 'OVERPARAMETERIZED');
insert into fw_sys_stat_proj_f_issue_type(id, issue_type) values(FW_SYS_STAT_PROJ_F_IS_TYPE_SQ.nextval, 'HASH');
insert into fw_sys_stat_proj_f_issue_type(id, issue_type) values(FW_SYS_STAT_PROJ_F_IS_TYPE_SQ.nextval, 'HASH_COMPARASION_NOT_POSSIBLE');

COMMIT;

CREATE TABLE fw_sys_stat_proj_file_issues
   		     (
   		     	project_id 		NUMBER,
   		      	computer_id 	NUMBER,
   		      	component_id 	NUMBER,
   		      	filename		VARCHAR2(1024),
   		      	issue_type_id	NUMBER,
			last_modification_date DATE
   		     );

ALTER TABLE fw_sys_stat_proj_file_issues
	ADD CONSTRAINT proj_f_issue_type_fk
	FOREIGN KEY (issue_type_id)
	REFERENCES fw_sys_stat_proj_f_issue_type(id) ON DELETE CASCADE;;

ALTER TABLE fw_sys_stat_proj_file_issues
	ADD CONSTRAINT proj_file_issue_fk
	FOREIGN KEY (project_id)
	REFERENCES fw_sys_stat_pvss_project(id) ON DELETE CASCADE;;

ALTER TABLE fw_sys_stat_proj_file_issues
	ADD CONSTRAINT computer_file_issue_fk
	FOREIGN KEY (computer_id)
	REFERENCES fw_sys_stat_computer(id) ON DELETE CASCADE;

ALTER TABLE fw_sys_stat_proj_file_issues
	ADD CONSTRAINT component_file_issue_fk
	FOREIGN KEY (component_id)
	REFERENCES fw_sys_stat_component(id) ON DELETE CASCADE;;

DROP TRIGGER fw_sys_stat_pvss_project_bc;
CREATE TRIGGER fw_sys_stat_pvss_project_bc
  BEFORE UPDATE OF COMPUTER_ID, REDU_COMPUTER_ID, CENTRALLY_MANAGED, SYSTEM_ID ON fw_SYS_STAT_PVSS_PROJECT
  FOR EACH ROW
BEGIN
	IF (NOT UPDATING('COMPUTER_ID')) THEN :new.NEED_SYNCHRONIZE := 'Y'; END IF;

	IF (:new.COMPUTER_ID != :old.COMPUTER_ID) THEN
		DELETE FROM  fw_sys_stat_proj_file_issues WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.COMPUTER_ID;
	END IF;
	IF (:new.REDU_COMPUTER_ID != :old.REDU_COMPUTER_ID) THEN
		DELETE FROM  fw_sys_stat_proj_file_issues WHERE PROJECT_ID = :old.ID AND COMPUTER_ID = :old.REDU_COMPUTER_ID;
	END IF ;
END;
/

CREATE OR REPLACE VIEW fw_sys_stat_schema (version) AS
	SELECT '4.1.8'
	FROM dual;
