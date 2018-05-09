ALTER TABLE fw_sys_stat_pvss_project ADD RESPONSIBLE VARCHAR2(128);
ALTER TABLE fw_sys_stat_computer ADD RESPONSIBLE VARCHAR2(128);

drop table fw_sys_stat_pc_responsible;
drop table FW_SYS_STAT_SYSTEM_RESPONSIBLE;

--Upgrade Schema version
CREATE OR REPLACE VIEW fw_sys_stat_schema (version) AS
	SELECT '5.1.1'
	FROM dual;
COMMIT;