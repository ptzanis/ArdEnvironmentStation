--Delete all tables
begin
	for rec in (select table_name from user_tables where table_name like('FW_SYS_STAT%')) loop
		--dbms_output.put_line(rec.table_name);
		execute immediate 'drop table '|| rec.table_name || ' cascade constraints';
	end loop;
end;
/

--Delete all sequences
begin
	for rec in (select sequence_name from user_sequences where sequence_name like('FW_SYS_STAT%')) loop
		--dbms_output.put_line(rec.table_name);
		execute immediate 'drop sequence '|| rec.sequence_name;
	end loop;
end;
/

--Delete all views
begin
	for rec in (select view_name from user_views where view_name like('FW_SYS_STAT%')) loop
		--dbms_output.put_line(rec.table_name);
		execute immediate 'drop view '|| rec.view_name;
	end loop;
end;
/

--Delete all triggers
begin
	for rec in (select trigger_name from user_triggers where trigger_name like('FW_SYS_STAT%')) loop
		--dbms_output.put_line(rec.table_name);
		execute immediate 'drop trigger '|| rec.trigger_name;
	end loop;
end;
/

--Drop temporary tables:
drop table need_synchronize_4091;
