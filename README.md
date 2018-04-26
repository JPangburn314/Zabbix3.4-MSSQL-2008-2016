# Zabbix-MSSQL-2008-2016

 This has been tested on Zabbix Agent 3.4.6 on Windows Servers 2008/R2,2010,and 2012. With MSSQL versions 2008-2016.

Stop Zabbix Agent service.

Copy the contents of the "files" directory into c:\Program Files\Zabbix Agent\

modify C:\Program Files\Zabbix Agent\zabbix_agentd.conf

Timeout=30
ServerActive=(IP of Zabbix server)
Include=c:\Program Files\Zabbix Agent\conf.d\*
UnsafeUserParameters=1

Start zabbix agent service.

Import Template App MSSQL 2008-2016.xml to server.
Attach template to MSSQL hosts.

Note: Only a few triggers have been created but there are over 70 items per database being monitored so you can customise your thresholds as you see fit.

