-- New fields
ALTER TABLE FW_SYS_STAT_PVSS_PROJECT ADD http_port number;
ALTER TABLE FW_SYS_STAT_COMPUTER ADD cpu_info VARCHAR(100);
ALTER TABLE FW_SYS_STAT_COMPUTER ADD memory_info VARCHAR(100);
ALTER TABLE FW_SYS_STAT_COMPUTER ADD network_info VARCHAR(500);
ALTER TABLE FW_SYS_STAT_COMPUTER ADD fmc_install_pkg VARCHAR(150);
ALTER TABLE FW_SYS_STAT_WCCOA_APPLICATIONS ADD default_panel VARCHAR(256);
ALTER TABLE FW_SYS_STAT_WCCOA_APPLICATIONS ADD alarm_overview_panel VARCHAR(256);

-- New tables
CREATE TABLE FW_SYS_STAT_PROJ_PARAM_TYPES
(
  id               NUMBER NOT NULL,
  family           VARCHAR2 (100) NOT NULL,
  name             VARCHAR2 (100) NOT NULL,
  datatype         VARCHAR2 (100) NOT NULL,
  description      VARCHAR2 (1000),
  CONSTRAINT       PROJ_PARAM_TYPES_ID_PK PRIMARY KEY(id)
);
CREATE SEQUENCE FW_SYS_STAT_PROJ_PARAM_TYPE_SQ
  MINVALUE 1
  START WITH 1
  INCREMENT BY 1
  NOCACHE;

CREATE TABLE FW_SYS_STAT_PROJECT_PARAMS
(
  id               NUMBER NOT NULL,
  project_id       NUMBER NOT NULL,
  param_type_id    NUMBER NOT NULL,
  value            VARCHAR2(1000),
  updated          DATE NOT NULL,
  CONSTRAINT       ID_PK PRIMARY KEY(id),
  CONSTRAINT       PROJ_PARAM_PROJECT_ID_FK FOREIGN KEY (project_id) REFERENCES fw_sys_stat_pvss_project (id) ON DELETE CASCADE,
  CONSTRAINT       PROJ_PARAM_PARAM_TYPE_ID_FK FOREIGN KEY (param_type_id) REFERENCES fw_sys_stat_proj_param_types (id) ON DELETE CASCADE
);
CREATE SEQUENCE FW_SYS_STAT_PROJECT_PARAMS_SQ
  MINVALUE 1
  START WITH 1
  INCREMENT BY 1
  NOCACHE;

CREATE TABLE FW_SYS_STAT_APPLICATION_DOMAIN
(
  id               NUMBER NOT NULL,
  name             VARCHAR2 (100) NOT NULL,
  description      VARCHAR2 (1000),
  contact_person   VARCHAR2 (100),
  CONSTRAINT       APPLICATION_DOMAIN_ID_PK PRIMARY KEY(id),
  CONSTRAINT       APPLICATION_DOMAIN_UQ UNIQUE(name)
);
CREATE SEQUENCE FW_SYS_STAT_APP_DOMAIN_SQ
  MINVALUE 1
  START WITH 1
  INCREMENT BY 1
  NOCACHE;

ALTER TABLE FW_SYS_STAT_PVSS_PROJECT ADD application_domain_id number CONSTRAINT application_domain_id REFERENCES FW_SYS_STAT_APPLICATION_DOMAIN(id);

INSERT INTO FW_SYS_STAT_APPLICATION_DOMAIN (id, name)
WITH DATA AS
(
  SELECT distinct application_domain
  FROM FW_SYS_STAT_PVSS_PROJECT
  WHERE application_domain is not null
)
SELECT FW_SYS_STAT_APP_DOMAIN_SQ.nextval, application_domain
FROM DATA;

UPDATE FW_SYS_STAT_PVSS_PROJECT project SET project.APPLICATION_DOMAIN_ID = (SELECT id FROM FW_SYS_STAT_APPLICATION_DOMAIN where name = project.APPLICATION_DOMAIN);

ALTER TABLE FW_SYS_STAT_PVSS_PROJECT DROP COLUMN APPLICATION_DOMAIN;

--- Procedures moved to a package

DROP PROCEDURE put_group_need_synchronize;
DROP PROCEDURE put_need_synchronize;
DROP PROCEDURE put_sys_need_synchronize;
DROP PROCEDURE set_need_synchronize;

CREATE OR REPLACE PACKAGE fw_sys_stat_pkg AS
  PROCEDURE put_need_synchronize (project_id FW_SYS_STAT_PROJECT_STATUS.project_id%type);
  PROCEDURE put_group_need_synchronize (group_id FW_SYS_STAT_PROJECT_GROUPS.group_id%type);
  PROCEDURE put_sys_need_synchronize(system_id FW_SYS_STAT_PVSS_PROJECT.system_id%type);
end fw_sys_stat_pkg;
/

CREATE OR REPLACE PACKAGE BODY fw_sys_stat_pkg AS

PROCEDURE put_need_synchronize(project_id FW_SYS_STAT_PROJECT_STATUS.project_id%type) AS
BEGIN
  UPDATE FW_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
  WHERE FW_SYS_STAT_PROJECT_STATUS.project_id = put_need_synchronize.project_id;
END put_need_synchronize;

PROCEDURE put_group_need_synchronize(group_id FW_SYS_STAT_PROJECT_GROUPS.group_id%type) AS
BEGIN
  UPDATE FW_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
  WHERE FW_SYS_STAT_PROJECT_STATUS.PROJECT_ID IN (
    SELECT PROJECT_ID FROM FW_SYS_STAT_PROJECT_GROUPS
    WHERE GROUP_ID = put_group_need_synchronize.group_id
  );
END put_group_need_synchronize;

PROCEDURE put_sys_need_synchronize(system_id FW_SYS_STAT_PVSS_PROJECT.system_id%type) AS
BEGIN
  UPDATE FW_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
  WHERE project_id IN (
    SELECT p.id as project_id FROM FW_SYS_STAT_PVSS_PROJECT p
    WHERE p.system_id = put_sys_need_synchronize.system_id
  );
END put_sys_need_synchronize;

END fw_sys_stat_pkg;
/

--- New set of triggers

create or replace TRIGGER fw_sys_stat_comp_in_groups_ac
AFTER INSERT OR UPDATE OR DELETE ON fw_sys_stat_comp_in_groups
FOR EACH ROW
DECLARE
  group_id fw_sys_stat_comp_in_groups.group_id%type;
BEGIN
  IF DELETING THEN
    group_id := :old.group_id;
  ELSE
    group_id := :new.group_id;
  END IF;
  fw_sys_stat_pkg.put_group_need_synchronize(group_id);
END;
/
DROP TRIGGER fw_sys_stat_comp_in_groups_bc;
/
create or replace TRIGGER FW_SYS_STAT_COMPUTER_AC
AFTER UPDATE OF VALID_UNTIL ON FW_SYS_STAT_COMPUTER
FOR EACH ROW
DECLARE
  cID fw_sys_stat_computer.id%type;
BEGIN
  cID := :old.id;
  IF (UPDATING('VALID_UNTIL') AND :new.valid_until is not null) THEN
    UPDATE  fw_sys_stat_pvss_project SET redu_computer_id = null
    WHERE id in (SELECT id FROM fw_sys_stat_pvss_project where redu_computer_id=cID);

    UPDATE  fw_sys_stat_pvss_project SET computer_id = null
    WHERE id in (SELECT id FROM fw_sys_stat_pvss_project where computer_id=cID);
  END IF;
END;
/
create or replace TRIGGER fw_sys_stat_force_reinstall_ac
AFTER UPDATE OR INSERT OR DELETE ON fw_sys_stat_force_reinstall
FOR EACH ROW
DECLARE
  project_id fw_sys_stat_pvss_project.id%type;
BEGIN
  IF DELETING THEN
    project_id := :old.project_id;
  ELSE
    project_id := :new.project_id;
  END IF;
  fw_sys_stat_pkg.put_need_synchronize(project_id);
END;
/
DROP TRIGGER fw_sys_stat_force_reinstall_bc;
/
create or replace TRIGGER fw_sys_stat_inst_path_ac
AFTER INSERT OR UPDATE OR DELETE ON fw_sys_stat_inst_path
FOR EACH ROW
DECLARE
  project_id fw_sys_stat_pvss_project.id%type;
BEGIN
  IF DELETING THEN
    project_id := :old.project_id;
  ELSE
    project_id := :new.project_id;
  END IF;
  fw_sys_stat_pkg.put_need_synchronize(project_id);
END;
/
DROP TRIGGER fw_sys_stat_inst_path_bc;
/
create or replace TRIGGER FW_SYS_STAT_PROJCONF_UPDATE_AC
AFTER UPDATE OR INSERT OR DELETE ON FW_SYS_STAT_PROJ_CONFS
FOR EACH ROW
DECLARE
  project_id fw_sys_stat_pvss_project.id%type;
BEGIN
  IF DELETING THEN
    project_id := :old.project_id;
  ELSE
    project_id := :new.project_id;
  END IF;
  fw_sys_stat_pkg.put_need_synchronize(project_id);
END;
/
DROP TRIGGER FW_SYS_STAT_PROJCONF_UPDATE;
/
create or replace TRIGGER fw_sys_stat_project_groups_ac
AFTER UPDATE OR INSERT OR DELETE ON fw_sys_stat_project_groups
FOR EACH ROW
DECLARE
  project_id fw_sys_stat_pvss_project.id%type;
BEGIN
  IF DELETING THEN
    project_id := :old.project_id;
  ELSE
    project_id := :new.project_id;
  END IF;
  fw_sys_stat_pkg.put_need_synchronize(project_id);
END;
/
DROP TRIGGER fw_sys_stat_project_groups_bc;
/
create or replace TRIGGER fw_sys_stat_pvss_project_ac
AFTER UPDATE OR INSERT ON fw_sys_stat_pvss_project
FOR EACH ROW
DECLARE
  project_id fw_sys_stat_pvss_project.id%type;
BEGIN
  IF DELETING THEN
    project_id := :old.id;
  ELSE
    project_id := :new.id;
  END IF;

  IF ((UPDATING('REDU_COMPUTER_ID') AND :new.REDU_COMPUTER_ID IS NULL) OR (UPDATING('COMPUTER_ID') AND :new.COMPUTER_ID IS NULL)) THEN
    DBMS_OUTPUT.PUT_LINE('IGNORING UPDATE ON PROJECTS TABLE DUE TO COMPUTER_ID OR REDU_COMPUTER_ID BEING SET TO NULL');
  ELSE
    fw_sys_stat_pkg.put_need_synchronize(project_id);
  END IF;
END;
/
create or replace TRIGGER fw_sys_stat_pvss_project_bc
BEFORE UPDATE OR INSERT ON fw_sys_stat_pvss_project
FOR EACH ROW
BEGIN

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
create or replace TRIGGER fw_sys_stat_pvss_system_ac
AFTER UPDATE ON fw_sys_stat_pvss_system
FOR EACH ROW
BEGIN
  fw_sys_stat_pkg.put_sys_need_synchronize(:new.id);
END;
/
DROP TRIGGER fw_sys_stat_pvss_system_bc;
/
create or replace TRIGGER fw_sys_stat_system_connect_ac
AFTER UPDATE OR INSERT OR DELETE ON fw_sys_stat_system_connect
FOR EACH ROW
DECLARE
  system_id_1 fw_sys_stat_pvss_system.id%type;
  system_id_2 fw_sys_stat_pvss_system.id%type;
BEGIN
  IF DELETING THEN
    system_id_1 := :old.peer_1_id;
    system_id_2 := :old.peer_2_id;
  ELSE
    system_id_1 := :new.peer_1_id;
    system_id_2 := :new.peer_2_id;
  END IF;

  fw_sys_stat_pkg.put_sys_need_synchronize(system_id_1);
  fw_sys_stat_pkg.put_sys_need_synchronize(system_id_2);
END;
/
DROP TRIGGER fw_sys_stat_system_connect_bc;
/
create or replace TRIGGER FW_SYS_STAT_TOOL_UPGRADE_ac
AFTER UPDATE OR INSERT OR DELETE ON FW_SYS_STAT_TOOL_UPGRADE
FOR EACH ROW
DECLARE
  project_id fw_sys_stat_pvss_project.id%type;
BEGIN
  IF DELETING THEN
    project_id := :old.project_id;
  ELSE
    project_id := :new.project_id;
  END IF;
  fw_sys_stat_pkg.put_need_synchronize(project_id);
END;
/
DROP TRIGGER fw_sys_stat_tool_upgrade_bc;
/
--Upgrade Schema version
CREATE OR REPLACE VIEW fw_sys_stat_schema (version) AS
  SELECT '5.1.4'
  FROM dual;
COMMIT;
