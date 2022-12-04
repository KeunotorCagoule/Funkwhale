# Base de données

## Sommaire

- [Installation serveur](#installation-serveur)
- [Config serveur](#config-serveur)
- [Création de user](#création-de-user)
- [Test](#test)

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
