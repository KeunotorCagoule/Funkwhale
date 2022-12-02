# Base de données

## Installation

```bash
# installation de mysql
[toto@db ~]$ sudo dnf install mysql -server -y
[...]
Complete!
```

```bash
# lancement du service mysql
[toto@db ~]$ sudo systemctl enable mysqld --now
[...]
[toto@db ~]$ systemctl status mysqld
● mysqld.service - MySQL 8.0 database server
     Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
     Active: active (running) since Fri 2022-12-02 10:25:02 CET; 12s ago
     [...]
```

```bash
# install de mysql
[toto@db ~]$ sudo mysql_secure_installation
[toto@db ~]$ sudo vim /etc/my.cnf
[toto@db ~]$ cat /etc/my.cnf
#
# This group is read both both by the client and the server
# use it for options that affect everything
#
[client-server]

#
# include all files from the config directory
#
!includedir /etc/my.cnf.d

bind-address=10.105.1.10
```

```bash
# ouverture du port 3306
[toto@db ~]$ sudo firewall-cmd --add-port=3306/tcp --permanent
success
[toto@db ~]$ sudo firewall-cmd --reload
success
```

## Création de user

```bash
# connexion à la db
[toto@db ~]$ mysql -u root -p
```

```sql
# création de user sur la db
mysql> CREATE USER 'gitea'@'git.tp5.linux' IDENTIFIED BY 'rootroot';
Query OK, 0 rows affected (0.03 sec)
mysql> CREATE DATABASE giteadb CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';
Query OK, 1 row affected (0.02 sec)
mysql> GRANT ALL PRIVILEGES ON giteadb.* TO 'gitea'@'git.tp5.linux';
Query OK, 0 rows affected (0.01 sec)

mysql> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.02 sec)
```

```bash
# installation de mysql sur la machine qui héberge le web
[toto@git ~]$ sudo dnf install mysql -y
```

```sql
# connexion sur la db depuis la machine git avec le user gitea
[toto@git ~]$ mysql -u gitea -h db.tp5.linux -p giteadb
mysql>
```

## Certificat SSL

```bash
# création clé SSL entre le web et la db
[toto@db ~]$ openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout mysql.key -out mysql.crt

# déplacement des clés SSL dans les dossiers appropriés
[toto@db ~]$ sudo mv mysql.crt /etc/pki/tls/certs
[toto@db ~]$ sudo mv mysql.key /etc/pki/tls/private

# configuration des clés SSL
[toto@db ~]$ sudo vim /etc/my.cnf
[toto@db ~]$ sudo cat /etc/my.cnf
#
# This group is read both both by the client and the server
# use it for options that affect everything
#
[client-server]

#
# include all files from the config directory
#
!includedir /etc/my.cnf.d

bind-address=10.105.1.10

[mysqld]
ssl-cert=/etc/pki/tls/certs/mysql.crt
ssl-key=/etc/pki/tls/private/mysql.key
tls-version=TLSv1.2,TLSv1.3

# changement de propriétaire et attribution des clés SSL à mysql
[toto@db ~]$ sudo chown mysql:mysql /etc/pki/tls/certs/mysql.crt /etc/pki/tls/private/mysql.key
[toto@db ~]$ sudo chmod 0600 /etc/pki/tls/certs/mysql.crt /etc/pki/tls/private/mysql.key
```

```bash
# relancement du service msql
[toto@db ~]$ sudo systemctl restart mysqld
[toto@db ~]$ systemctl status mysqld
● mysqld.service - MySQL 8.0 database server
     Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
     Active: active (running) since Fri 2022-12-02 11:12:17 CET; 7s ago
     [...]

# connexion à la db pour drop le user et spécifier le user utilisé dans le certificat SSL
[toto@db ~]$ mysql -u root -p
```

```sql
mysql> DROP USER 'gitea'@'git.tp5.linux';
Query OK, 0 rows affected (0.03 sec)
mysql> CREATE USER 'gitea'@'git.tp5.linux' IDENTIFIED BY 'rootroot' REQUIRE SSL;
Query OK, 0 rows affected (0.03 sec)
mysql> GRANT ALL PRIVILEGES ON giteadb.* TO 'gitea'@'git.tp5.linux';
Query OK, 0 rows affected (0.01 sec)
mysql> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.01 sec)
```

## Test

```bash
# vérification du SSL
[toto@git ~]$ mysql -u gitea -h db.tp5.linux -p giteadb
Enter password:
Welcome to the MySQL monitor.  Commands end with ; or \g.
[...]
mysql>
```
