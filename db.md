# Base de données

## Sommaire

- [Installation serveur](#installation-serveur)
- [Config serveur](#config-serveur)
- [Création de user](#création-de-user)
- [Test](#test)
- [SSL (**NE FONCTIONNE PAS**)](#ssl)
  - [Génération](#génération)
  - [Conf](#conf)
  - [Client](#client)
  - [Gitea](#gitea)

## Installation serveur

```bash
# installation de mysql
[toto@db ~]$ sudo dnf install mysql-server -y
[...]
Complete!
```

```bash
# lancement du service mysql
[toto@db ~]$ sudo systemctl enable mysqld --now
Created symlink /etc/systemd/system/multi-user.target.wants/mysqld.service → /usr/lib/systemd/system/mysqld.service.
[toto@db ~]$ systemctl status mysqld
● mysqld.service - MySQL 8.0 database server
     Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
     Active: active (running) since Fri 2022-12-02 10:25:02 CET; 12s ago
     [...]
```

## Config serveur

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
mysql> CREATE USER 'gitea'@'git.tp5.linux' IDENTIFIED BY 'gitea_db';
Query OK, 0 rows affected (0.03 sec)
mysql> CREATE DATABASE giteadb CHARACTER SET 'utf8mb4' COLLATE 'utf8mb4_unicode_ci';
Query OK, 1 row affected (0.02 sec)
mysql> GRANT ALL PRIVILEGES ON giteadb.* TO 'gitea'@'git.tp5.linux';
Query OK, 0 rows affected (0.01 sec)
mysql> FLUSH PRIVILEGES;
Query OK, 0 rows affected (0.02 sec)
```

## Test

```bash
# installation de mysql sur la machine qui héberge le web
[toto@git ~]$ sudo dnf install mysql -y
```

```sql
# connexion sur la db depuis la machine git avec le user gitea
[toto@git ~]$ mysql -u gitea -h db.tp5.linux -p giteadb
mysql>
```

## SSL

**NE FONCTIONNE PAS POUR LE MOMENT**

### Génération

```sh
[toto@db ~]$ sudo mkdir /mysql_keys
[toto@db ~]$ cd /mysql_keys
```

On génère notre autorité de certification (CA)

```sh
[toto@db mysql_keys]$ openssl genrsa 2048 > ca-key.pem
[toto@db mysql_keys]$ openssl req -new -x509 -nodes -days 1000 -key ca-key.pem > ca-cert.pem
...
Common Name (eg, your name or your server\'s hostname) []:db.tp5.linux
Email Address []:
```

Ensuite on génère le certificat de notre serveur

```sh
[toto@db mysql_keys]$ openssl req -newkey rsa:2048 -days 1000 -nodes -keyout server-key.pem > server-req.pem
...
Common Name (eg, your name or your server\'s hostname) []:db.tp5.linux
Email Address []:

[toto@db mysql_keys]$ openssl x509 -req -in server-req.pem -days 1000 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 > server-cert.pem
```

Et enfine celui du client

```sh
[toto@db mysql_keys]$ openssl req -newkey rsa:2048 -days 1000 -nodes -keyout client-key.pem > client-req.pem
...
Common Name (eg, your name or your server\'s hostname) []:db.tp5.linux
Email Address []:

[toto@db mysql_keys]$ openssl x509 -req -in client-req.pem -days 1000 -CA ca-cert.pem -CAkey ca-key.pem -set_serial 01 > client-cert.pem
```

### Conf

On change le propriétaire et les permissions de ces fichiers pour les rendre accessibles au user `mysql`

```sh
[toto@db mysql_keys]$ cd ..
[toto@db /]$ sudo chown -R mysql:mysql /mysql_keys/
[toto@db mysql_keys]$ sudo chmod 600 *
[toto@db mysql_keys]$ ls -l
total 32
-rw-------. 1 mysql mysql 1123 Dec  5 13:42 ca-cert.pem
-rw-------. 1 mysql mysql 1704 Dec  5 13:41 ca-key.pem
-rw-------. 1 mysql mysql 1062 Dec  5 13:50 client-cert.pem
-rw-------. 1 mysql mysql 1704 Dec  5 13:49 client-key.pem
-rw-------. 1 mysql mysql  985 Dec  5 13:49 client-req.pem
-rw-------. 1 mysql mysql 1062 Dec  5 13:48 server-cert.pem
-rw-------. 1 mysql mysql 1704 Dec  5 13:43 server-key.pem
-rw-------. 1 mysql mysql  985 Dec  5 13:48 server-req.pem
```

Maintenant, on édite la config de mysql

```sh
[toto@db ~]$ sudo vim /etc/my.cnf.d/mysql-server.cnf
[toto@db ~]$ cat /etc/my.cnf.d/mysql-server.cnf
...
[mysqld]
...
ssl
ssl-cipher=DHE-RSA-AES256-SHA
ssl-ca=/mysql_keys/ca-cert.pem
ssl-cert=/mysql_keys/server-cert.pem
ssl-key=/mysql_keys/server-key.pem
```

On restart le serveur

```sh
[toto@db ~]$ sudo systemctl restart mysqld
[toto@db ~]$ systemctl status mysqld
● mysqld.service - MySQL 8.0 database server
     Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
     Active: active (running) since Mon 2022-12-05 14:01:32 CET; 4s ago
```

Et on regarde si les changements ont été appliqués

```sh
[toto@db ~]$ sudo mysql -p

mysql> show variables LIKE "%ssl%";
+-------------------------------------+-----------------------------+
| Variable_name                       | Value                       |
+-------------------------------------+-----------------------------+
| have_openssl                        | YES                         |
| have_ssl                            | YES                         |
| performance_schema_show_processlist | OFF                         |
| ssl_ca                              | /mysql_keys/ca-cert.pem     |
| ssl_capath                          |                             |
| ssl_cert                            | /mysql_keys/server-cert.pem |
| ssl_cipher                          | DHE-RSA-AES256-SHA          |
| ssl_crl                             |                             |
| ssl_crlpath                         |                             |
| ssl_fips_mode                       | OFF                         |
| ssl_key                             | /mysql_keys/server-key.pem  |
| ssl_session_cache_mode              | ON                          |
| ssl_session_cache_timeout           | 300                         |
+-------------------------------------+-----------------------------+
```

### Client

Maintenant on va conf le client, donc dans un premier temps, on liste les users

```sh
mysql> select user,host,ssl_type from mysql.user;
+------------------+---------------+----------+
| user             | host          | ssl_type |
+------------------+---------------+----------+
| gitea            | git.tp5.linux |          |
| mysql.infoschema | localhost     |          |
| mysql.session    | localhost     |          |
| mysql.sys        | localhost     |          |
| root             | localhost     |          |
+------------------+---------------+----------+
```

On va donc changer notre user gitea pour qu'il utilise une connexion TLS

```sh
mysql> ALTER USER 'gitea'@'git.tp5.linux' REQUIRE SSL;
mysql> select user,host,ssl_type from mysql.user;
+------------------+---------------+----------+
| user             | host          | ssl_type |
+------------------+---------------+----------+
| gitea            | git.tp5.linux | ANY      |
| mysql.infoschema | localhost     |          |
| mysql.session    | localhost     |          |
| mysql.sys        | localhost     |          |
| root             | localhost     |          |
+------------------+---------------+----------+
```

On voit donc que dorénavent l'user gitea utilise une connexion TLS.
Cependant, il n'a aucun certificat/clé, on va donc les lui donner

```sh
[toto@db ~]$ sudo vim /etc/my.cnf.d/client.cnf
[toto@db ~]$ cat /etc/my.cnf.d/client.cnf
...
[client]
ssl-ca=/mysql_keys/ca-cert.pem
ssl-cert=/mysql_keys/client-cert.pem
ssl-key=/mysql_keys/client-key.pem
...
```

Et on restart

```sh
[toto@db ~]$ sudo systemctl restart mysqld
[toto@db ~]$ systemctl status mysqld
● mysqld.service - MySQL 8.0 database server
     Loaded: loaded (/usr/lib/systemd/system/mysqld.service; enabled; vendor preset: disabled)
     Active: active (running) since Mon 2022-12-05 14:10:55 CET; 13s ago
```

### Gitea

Enfin, il faut que Gitea saches qu'il utilise également une connexion TLS

```sh
[toto@git ~]$ sudo vim /etc/gitea/app.ini
[toto@git ~]$ cat /etc/gitea/app.ini
...
; ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ;
; ; MySQL Configuration
; ;
DB_TYPE  = mysql
; can use socket e.g. /var/run/mysqld/mysqld.sock
HOST     = db.tp5.linux
NAME     = giteadb
USER     = gitea
; Use PASSWD = `your password` for quoting if you use special characters in the password.
PASSWD   = gitea_db
SSL_MODE = enable
...
```
