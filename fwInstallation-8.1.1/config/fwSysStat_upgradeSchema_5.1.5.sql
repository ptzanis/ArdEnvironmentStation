-- New package body (fix for ENS-17787)
create or replace PACKAGE BODY "FW_SYS_STAT_PKG" AS

PROCEDURE put_need_synchronize(project_id FW_SYS_STAT_PROJECT_STATUS.project_id%type) AS
  table_mutating exception;
  PRAGMA EXCEPTION_INIT(table_mutating, -4091);
BEGIN
  UPDATE FW_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
  WHERE FW_SYS_STAT_PROJECT_STATUS.project_id = put_need_synchronize.project_id;
EXCEPTION
  -- For more, see: https://docs.oracle.com/cd/A97630_01/appdev.920/a96624/07_errs.htm
  WHEN table_mutating THEN -- 4091 table is mutating
    NULL; -- ignore the error
  WHEN OTHERS THEN
    RAISE; -- any other error: rethrow
END put_need_synchronize;

PROCEDURE put_group_need_synchronize(group_id FW_SYS_STAT_PROJECT_GROUPS.group_id%type) AS
  table_mutating exception;
  PRAGMA EXCEPTION_INIT(table_mutating, -4091);
BEGIN
  UPDATE FW_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
  WHERE FW_SYS_STAT_PROJECT_STATUS.PROJECT_ID IN (
    SELECT PROJECT_ID FROM FW_SYS_STAT_PROJECT_GROUPS
    WHERE GROUP_ID = put_group_need_synchronize.group_id
  );
EXCEPTION
  -- For more, see: https://docs.oracle.com/cd/A97630_01/appdev.920/a96624/07_errs.htm
  WHEN table_mutating THEN -- 4091 table is mutating
    NULL; -- ignore the error
  WHEN OTHERS THEN
    RAISE; -- any other error: rethrow
END put_group_need_synchronize;

PROCEDURE put_sys_need_synchronize(system_id FW_SYS_STAT_PVSS_PROJECT.system_id%type) AS
  table_mutating exception;
  PRAGMA EXCEPTION_INIT(table_mutating, -4091);
BEGIN
  UPDATE FW_SYS_STAT_PROJECT_STATUS SET NEED_SYNCHRONIZE = 'Y'
  WHERE project_id IN (
    SELECT p.id as project_id FROM FW_SYS_STAT_PVSS_PROJECT p
    WHERE p.system_id = put_sys_need_synchronize.system_id
  );
EXCEPTION
  -- For more, see: https://docs.oracle.com/cd/A97630_01/appdev.920/a96624/07_errs.htm
  WHEN table_mutating THEN -- 4091 table is mutating
    NULL; -- ignore the error
  WHEN OTHERS THEN
    RAISE; -- any other error: rethrow
END put_sys_need_synchronize;

END fw_sys_stat_pkg;
/

-- Upgrade Schema version
CREATE OR REPLACE VIEW fw_sys_stat_schema (version) AS
  SELECT '5.1.5'
  FROM dual;
COMMIT;
