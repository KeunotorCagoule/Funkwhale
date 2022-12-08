# Replication

En vue de faire un vrai reverse proxy, qui répartie la charge entre deux serveur web, on va commencer par créer un master-master entre `db.tp5.linux` et notre future nouvelle machine `replication.tp5.linux` histoire que les deux serveurs web utilise un serveur mysql à eux, histoire de répartir la charge également sur les transactions SQL.

## Setup

On installe et lance mysql-server

```sh
[toto@replication ~]$ sudo dnf install mysql-server -y
...
Complete!

[toto@replication ~]$ sudo systemctl enable mysqld --now
Created symlink /etc/systemd/system/multi-user.target.wants/mysqld.service → /usr/lib/systemd/system/mysqld.service.
[toto@replication ~]$ systemctl status mysqld
● mysqld.service - MySQL 8.0 database server
	Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
	Active: active (running) since Thu 2022-12-08 11:01:15 CET; 51s ago
```

Et on ouvre le port dans le firewall

```sh
[toto@replication ~]$ sudo firewall-cmd --add-port=3306/tcp --permanent
success
[toto@replication ~]$ sudo firewall-cmd --reload
success
```

## Config

```sh
[toto@replication ~]$ sudo mysql_secure_installation
```

Maintenant on va préparer le master1 (`db.tp5.linux`)

```sh
[toto@db ~]$ sudo vim /etc/my.cnf.d/mysql-server.cnf
[toto@db ~]$ cat /etc/my.cnf.d/mysql-server.cnf
...
server-id = 1
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = giteadb
```

On créer le user MySQL pour la réplication

```sql
CREATE USER 'replication'@'replication.tp5.linux' IDENTIFIED BY 'replica';
GRANT REPLICATION SLAVE ON *.* to 'replication'@'replication.tp5.linux';
FLUSH PRIVILEGES;

SHOW MASTER STATUS;
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000003 |      157 | giteadb      |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
```

On revient sur le serveur de réplication

```sh
[toto@replication ~]$ sudo vim /etc/my.cnf.d/mysql-server.cnf
[toto@replication ~]$ cat /etc/my.cnf.d/mysql-server.cnf
...
server-id = 2
log_bin = /var/log/mysql/mysql-bin.log
binlog_do_db = giteadb

[toto@replication ~]$ sudo systemctl restart mysqld
```

On créer le user MySQL slave

```sql
CREATE USER 'replication2'@'db.tp5.linux' IDENTIFIED BY 'replica';
GRANT REPLICATION SLAVE ON *.* TO 'replication2'@'db.tp5.linux';
FLUSH PRIVILEGES;
```

On recréer la db

```sql
CREATE DATABASE giteadb CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';
```

Et enfin on définis la db master

```sql
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST='db.tp5.linux', MASTER_USER='replication', MASTER_PASSWORD='replica', MASTER_LOG_FILE='mysql-bin.000003', MASTER_LOG_POS=157, GET_MASTER_PUBLIC_KEY=1;
START SLAVE;
```

On vérifie que tout est bon

```sql
SHOW SLAVE STATUS \G;
*************************** 1. row ***************************
			Slave_IO_State: Waiting for source to send event
			   Master_Host: db.tp5.linux
			   Master_User: replication
			   Master_Port: 3306
			 Connect_Retry: 60
		    Master_Log_File: mysql-bin.000003
		Read_Master_Log_Pos: 157
			Relay_Log_File: replication-relay-bin.000002
			 Relay_Log_Pos: 326
	   Relay_Master_Log_File: mysql-bin.000003
		   Slave_IO_Running: Yes
		  Slave_SQL_Running: Yes
		    Replicate_Do_DB:
		Replicate_Ignore_DB:
		 Replicate_Do_Table:
	  Replicate_Ignore_Table:
	 Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
			    Last_Errno: 0
			    Last_Error:
			  Skip_Counter: 0
		Exec_Master_Log_Pos: 157
		    Relay_Log_Space: 542
		    Until_Condition: None
			Until_Log_File:
			 Until_Log_Pos: 0
		 Master_SSL_Allowed: No
		 Master_SSL_CA_File:
		 Master_SSL_CA_Path:
		    Master_SSL_Cert:
		  Master_SSL_Cipher:
			Master_SSL_Key:
	   Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
			 Last_IO_Errno: 0
			 Last_IO_Error:
			Last_SQL_Errno: 0
			Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
		   Master_Server_Id: 1
			   Master_UUID: e0052251-722c-11ed-af98-080027b96b60
		   Master_Info_File: mysql.slave_master_info
				SQL_Delay: 0
		SQL_Remaining_Delay: NULL
	 Slave_SQL_Running_State: Replica has read all relay log; waiting for more updates
		 Master_Retry_Count: 86400
			   Master_Bind:
	 Last_IO_Error_Timestamp:
	Last_SQL_Error_Timestamp:
			Master_SSL_Crl:
		 Master_SSL_Crlpath:
		 Retrieved_Gtid_Set:
		  Executed_Gtid_Set:
			 Auto_Position: 0
	    Replicate_Rewrite_DB:
			  Channel_Name:
		 Master_TLS_Version:
	  Master_public_key_path:
	   Get_master_public_key: 1
		  Network_Namespace:
```

Pas d'erreur, trout est bon

## Master - Master

Maintenant, on souhaite que le serveur slave soit également un master.

Sur le slave

```sql
SHOW MASTER STATUS;
+------------------+----------+--------------+------------------+-------------------+
| File             | Position | Binlog_Do_DB | Binlog_Ignore_DB | Executed_Gtid_Set |
+------------------+----------+--------------+------------------+-------------------+
| mysql-bin.000001 |      157 | giteadb      |                  |                   |
+------------------+----------+--------------+------------------+-------------------+
```

Sur le master (db.tp5.linux)

```sql
STOP SLAVE;
CHANGE MASTER TO MASTER_HOST='replication.tp5.linux', MASTER_USER='replication2', MASTER_PASSWORD='replica', MASTER_LOG_FILE='mysql-bin.000001', MASTER_LOG_POS=157, GET_MASTER_PUBLIC_KEY=1;
START SLAVE;
```

On regarde que tout est bon

```sql
show slave status \G;
*************************** 1. row ***************************
               Slave_IO_State: Waiting for source to send event
                  Master_Host: replication.tp5.linux
                  Master_User: replication2
                  Master_Port: 3306
                Connect_Retry: 60
              Master_Log_File: mysql-bin.000001
          Read_Master_Log_Pos: 157
               Relay_Log_File: db-relay-bin.000002
                Relay_Log_Pos: 326
        Relay_Master_Log_File: mysql-bin.000001
             Slave_IO_Running: Yes
            Slave_SQL_Running: Yes
              Replicate_Do_DB:
          Replicate_Ignore_DB:
           Replicate_Do_Table:
       Replicate_Ignore_Table:
      Replicate_Wild_Do_Table:
  Replicate_Wild_Ignore_Table:
                   Last_Errno: 0
                   Last_Error:
                 Skip_Counter: 0
          Exec_Master_Log_Pos: 157
              Relay_Log_Space: 533
              Until_Condition: None
               Until_Log_File:
                Until_Log_Pos: 0
           Master_SSL_Allowed: No
           Master_SSL_CA_File:
           Master_SSL_CA_Path:
              Master_SSL_Cert:
            Master_SSL_Cipher:
               Master_SSL_Key:
        Seconds_Behind_Master: 0
Master_SSL_Verify_Server_Cert: No
                Last_IO_Errno: 0
                Last_IO_Error:
               Last_SQL_Errno: 0
               Last_SQL_Error:
  Replicate_Ignore_Server_Ids:
             Master_Server_Id: 2
                  Master_UUID: 8ce57701-76e2-11ed-aaaa-080027b96b60
             Master_Info_File: mysql.slave_master_info
                    SQL_Delay: 0
          SQL_Remaining_Delay: NULL
      Slave_SQL_Running_State: Replica has read all relay log; waiting for more updates
           Master_Retry_Count: 86400
                  Master_Bind:
      Last_IO_Error_Timestamp:
     Last_SQL_Error_Timestamp:
               Master_SSL_Crl:
           Master_SSL_Crlpath:
           Retrieved_Gtid_Set:
            Executed_Gtid_Set:
                Auto_Position: 0
         Replicate_Rewrite_DB:
                 Channel_Name:
           Master_TLS_Version:
       Master_public_key_path:
        Get_master_public_key: 1
            Network_Namespace:
```

Parfait!

## Test final

Sur `db`

```sql
USE giteadb;
CREATE TABLE test (`id` varchar(10));
```

Sur `replication`

```sql
USE giteadb;
SHOW TABLES;
+-------------------+
| Tables_in_giteadb |
+-------------------+
| test              |
+-------------------+

DROP TABLE giteadb;
```

Et enfin sur `db`

```sql
SHOW TABLES;
...
| stopwatch                 |
| task                      |
| team                      |
| team_repo                 |
| team_unit                 |
| team_user                 |
| topic                     |
| tracked_time              |
| two_factor                |
| upload                    |
...
```

Aucune table "test", la réplication fonctionne bien.

## Correction

Cependant, sur `db`, nous avions déjà des tables de créées, donc `replication` ne les as pas, on va donc toutes les supprimer, et refaire l'"install" de Gitea (install graphique lorsque le site est déjà up)

Pour éviter toute erreur pendant la suppression, on stop le slave de `replication`, on supprime sur `db` et on relance le slave.

```sql
DROP DATABASE giteadb;
CREATE DATABASE giteadb CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';
```

Sachant qu'on a pas besoin de refaire les `GRANTS` puisque malgré que la db a été supprimée, les users gardes les permissions séparement.

Et maintenant, on doit dire à Gitea que l'on a pas fait son install

```sh
[toto@git ~]$ sudo vim /etc/gitea/app.ini
[toto@git ~]$ cat /etc/gitea/app.ini | grep INSTALL_LOCK
INSTALL_LOCK       = false
[toto@git ~]$ sudo systemctl restart gitea
```
