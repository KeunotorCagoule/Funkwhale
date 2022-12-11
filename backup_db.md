# Backup DB

## Storage

```sh
# création du fichier partagé sur le serveur
[toto@storage ~]$ sudo mkdir -p /srv/nfs_shares/backup_db
[sudo] password for toto:

# création du user qui dumpera la DB
[toto@storage ~]$ sudo useradd db_dump -m -d /srv/nfs_shares/backup_db -s /usr/bin/login
[sudo] password for toto:
useradd: warning: the home directory /srv/nfs_shares/backup_db already exists.
useradd: Not copying any file from skel directory into it.
[toto@storage ~]$ sudo chown db_dump:db_dump /srv/nfs_shares/backup_db
```

```sh
# ajout de la machine auquel le fichier peut être partagé
[toto@storage ~]$ sudo vim /etc/exports
[toto@storage ~]$ cat /etc/exports
/srv/nfs_shares/repos git.tp5.linux(rw,sync,no_subtree_check)
/srv/nfs_shares/backup_db db.tp5.linux(rw,sync,no_subtree_check)
```

```sh
# vérification du lancement du service NFS
[toto@storage ~]$ systemctl status nfs-server
● nfs-server.service - NFS server and services
     Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: di>
    Drop-In: /run/systemd/generator/nfs-server.service.d
             └─order-with-mounts.conf
     Active: active (exited) since Thu 2022-12-08 09:16:34 CET; 30min ago
   Main PID: 854 (code=exited, status=0/SUCCESS)
        CPU: 31ms

Dec 08 09:16:34 storage.tp5.linux systemd[1]: Starting NFS server and services...
Dec 08 09:16:34 storage.tp5.linux systemd[1]: Finished NFS server and services.
```

## DB

```sh
[toto@db ~]$ sudo dnf install nfs-utils -y
[sudo] password for toto:
Last metadata expiration check: 0:09:38 ago on Thu Dec  8 09:43:09 2022.
Dependencies resolved.
[...]
Complete!
```

```sh
[toto@db srv]$ sudo mkdir db_dumps

# relancement du service nfs pour prendre en compte tous les changements
[toto@db srv]$ sudo systemctl restart nfs-server
```

```sh
# montage du dossier distant sur la machine DB
[toto@db ~]$ sudo mount 10.105.1.13:/srv/nfs_shares/backup_db /srv/db_dumps/
Created symlink /run/systemd/system/remote-fs.target.wants/rpc-statd.service → /usr/lib/systemd/system/rpc-statd.service.

# on vérifie le montage
[toto@db ~]$ df -h | grep backup
10.105.1.13:/srv/nfs_shares/backup_db  6.2G  1.2G  5.1G  20% /srv/db_dumps
```

```sh
# création du user qui va dumper la DB
[toto@db srv]$ sudo useradd db_dump -u 1002 -m -d /srv/db_dumps -s /usr/bin/login
useradd: warning: the home directory /srv/db_dumps already exists.
useradd: Not copying any file from skel directory into it.
Creating mailbox file: File exists
```

```sh
# petit test
[toto@db srv]$ sudo -u db_dump touch /srv/db_dumps/test.txt
[toto@storage backup_db]$ ls
test.txt

[toto@db srv]$ sudo -u db_dump rm /srv/db_dumps/test.txt
[toto@storage backup_db]$ ls
```

```sh
# configuration pour que le dossier client se mount automatiquement au lancement de la machine
[toto@db ~]$ sudo vim /etc/fstab
[toto@db ~]$ cat /etc/fstab | grep nfs
storage.tp5.linux:/srv/nfs_shares/db.tp5.linux /srv/db_dumps nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0

# restart de la DB
[toto@db ~]$ sudo reboot
```

```sh
# fichier bien monté automatiquement au lancement de la DB
[toto@db ~]$ df -h | grep nfs
storage.tp5.linux:/srv/nfs_shares/backup_db  6.2G  1.2G  5.1G  20% /srv/db_dumps
```

## Script

```sh
[toto@db opt]$ sudo vim db_dump.sh
[sudo] password for toto:

[toto@db opt]$ cat db_dump.sh
#!/bin/bash
# Last Update : 06/12/2022
# Written by : Roulland Roxanne
# This script will dump the database and save it to a file

# Set the variables
user='gitea'
passwd='gitea_db'
db='giteadb'
name="${db}_$(date '+%y%m%d_%H%M%S')"
outputpath="/srv/db_dumps/"

# Dump the database
echo "Backup started for database - ${db}."
cd $outputpath
mysqldump -u ${user} -p${passwd} --no-tablespaces --skip-lock-tables --databases ${db} > "${name}.sql"
if [[ $? == 0 ]]
then
        tar -czf "${name}.tar.gz" "${name}.sql"
        rm -f "${name}.sql"
        echo "Backup successfully completed."
else
        echo "Backup failed."
        rm -f "${name}.sql"
        exit 1
fi
```

```sh
# changement de propriétaire du script
[toto@db opt]$ sudo chown db_dump:db_dump db_dump.sh

# changement des permissions du script pour le mettre en executable
[toto@db opt]$ sudo chmod 744 db_dump.sh
[toto@db opt]$ ls -l
total 8
-rwxr--r--. 1 root    root     60 Dec  5 16:31 autoupdater.sh
-rwxr--r--. 1 db_dump db_dump 732 Dec  8 11:17 db_dump.sh
```

```sh
# dump la DB
[toto@db ~]$ sudo -u db_dump /opt/db_dump.sh
Backup started for database - giteadb.
mysqldump: [Warning] Using a password on the command line interface can be insecure.
mysqldump: Error: 'Access denied; you need (at least one of) the PROCESS privilege(s) for this operation' when trying to dump tablespaces
tar: Removing leading `/' from member names
Backup successfully completed.
```

```sh
# unzip le tar.gz pour avoir le fichier lisible
[toto@db db_dumps]$ tar -xzf giteadb_221208_160419.tar.gz
```

## Création du service

```sh
# création du service
[toto@db ~]$ sudo vim /etc/systemd/system/backup.service
[sudo] password for toto:
[toto@db ~]$ cat /etc/systemd/system/backup.service
[Unit]
Description=Backup DB tables

[Service]
ExecStart=/opt/db_dump.sh
WorkingDirectory=/srv/db_dumps
User=db_dump
Type=oneshot

[Install]
WantedBy=multi-user.target
```

```sh
# création du timer associé à la backup pour la lancer tous les 4 heures
[toto@db ~]$ vim /etc/systemd/system/backup.timer
[toto@db ~]$ cat /etc/systemd/system/backup.timer
[Unit]
Description=Run service backup

[Timer]
OnCalendar=*-*-* 4:00:00
Persistent=true

[Install]
WantedBy=timers.target
```

```sh
# lancement du timer
[toto@db ~]$ sudo systemctl daemon-reload
[sudo] password for toto:
[toto@db ~]$ sudo systemctl start backup.timer
[toto@db ~]$ sudo systemctl enable backup.timer
Created symlink /etc/systemd/system/timers.target.wants/backup.timer → /etc/systemd/system/backup.timer.
[toto@db ~]$ sudo systemctl status backup.timer
● backup.timer - Run service backup
     Loaded: loaded (/etc/systemd/system/backup.timer; enabled; vendor pres>
     Active: active (waiting) since Sat 2022-12-10 11:10:36 CET; 18s ago
      Until: Sat 2022-12-10 11:10:36 CET; 18s ago
    Trigger: Sun 2022-12-11 04:00:00 CET; 16h left
   Triggers: ● backup.service

Dec 10 11:10:36 db.tp5.linux systemd[1]: Started Run service backup.

# liste des timers existants
[toto@db ~]$ sudo systemctl list-timers
NEXT                        LEFT       LAST                        PASSED  >
Sat 2022-12-10 12:14:40 CET 58min left Sat 2022-12-10 11:10:44 CET 4min 56s>
Sun 2022-12-11 00:00:00 CET 12h left   Sat 2022-12-10 10:57:24 CET 18min ag>
Sun 2022-12-11 04:00:00 CET 16h left   n/a                         n/a     >
Sun 2022-12-11 11:12:20 CET 23h left   Sat 2022-12-10 11:12:20 CET 3min 20s>

4 timers listed.
Pass --all to see loaded but inactive timers, too.
```

## Restore la DB

```sh
# dans l'exemple la dernière backup date du 8 puisque le timer n'a été up que le 10
[toto@db ~]$ ls -lt /srv/db_dumps/ | head -2
total 132
-rw-r--r--. 1 db_dump db_dump 10080 Dec  8 16:37 giteadb_221208_163748.tar.gz

# unzip le fichier tar.gz
[toto@db ~]$ sudo tar -xzf /srv/db_dumps/giteadb_221208_163748.tar.gz

# commande à lancer pour récupérer la DB
[toto@db ~]$ mysql -u db_dump -p nextcloud < /srv/db_dumps/giteadb_221208_163748.sql
```
