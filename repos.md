# NFS Server

On va utiliser un serveur NFS pour sauvegarder à part les repos des utilisateurs

## Sommaire

- [Install](#install)
- [Client](#client)

## Install

Dans un premier temps, on va créer le dossier qui sera partagé

```sh
[toto@repos ~]$ cd /srv
[toto@repos srv]$ sudo mkdir -p nfs_shares/repos
[toto@repos srv]$ sudo mkdir nfs_shares/gitea
```

Ensuite on créer le user

```sh
[toto@repos srv]$ sudo useradd git -m -d /srv/nfs_shares/repos -s /usr/bin/login
useradd: warning: the home directory /srv/nfs_shares/repos already exists.
useradd: Not copying any file from skel directory into it.
[toto@repos srv]$ sudo chown git:git /srv/nfs_shares/repos
[toto@repos srv]$ sudo chown git:git /srv/nfs_shares/gitea
```

On install le serveur NFS

```sh
[toto@repos srv]$ sudo dnf install nfs-utils -y
...
Complete!

[toto@repos srv]$ sudo vim /etc/exports
[toto@repos srv]$ cat /etc/exports
/srv/nfs_shares/repos git.tp5.linux(rw,sync,no_subtree_check)
/srv/nfs_shares/gitea git.tp5.linux(rw,sync,no_subtree_check)
```

Et on démarre le service

```sh
[toto@repos srv]$ sudo systemctl enable nfs-server --now
[toto@repos srv]$ systemctl status nfs-server
● nfs-server.service - NFS server and services
     Loaded: loaded (/usr/lib/systemd/system/nfs-server.service; enabled; vendor preset: disabled)
     Active: active (exited) since Mon 2022-12-05 23:12:32 CET; 11s ago
```

On ouvre ensuite les ports

```sh
[toto@repos srv]$ sudo firewall-cmd --permanent --add-service=nfs
success
[toto@repos srv]$ sudo firewall-cmd --permanent --add-service=mountd
success
[toto@repos srv]$ sudo firewall-cmd --permanent --add-service=rpc-bind
success
[toto@repos srv]$ sudo firewall-cmd --reload
success
[toto@repos srv]$ sudo firewall-cmd --list-services
cockpit dhcpv6-client mountd nfs rpc-bind ssh
```

## Client

On install ce qu'il faut

```sh
[toto@git ~]$ sudo dnf install nfs-utils -y
...
Complete!
```

On fait une sauvegarde car lorsque l'on va monter le dossier distant, le dossier que l'on a actuellement sera effacé

```sh
[toto@git toto]$ sudo tar -cf ~/backup.tar.gz /var/lib/gitea
[toto@git toto]$ sudo cp /etc/gitea/app.ini ~
```

On monte les dossier distant

```sh
[toto@git lib]$ sudo mount storage.tp5.linux:/srv/nfs_shares/repos /var/lib/gitea
[toto@git lib]$ sudo mount storage.tp5.linux:/srv/nfs_shares/gitea /etc/gitea
```

On test

```sh
# Oui je fais sudo dans mon homedir mais sinon ça ne garde pas le propriétaire initial du dossier dans le tar
[toto@git ~]$ sudo tar -xf backup.tar.gz

# On remet le dossier backup à sa place
[toto@git ~]$ sudo mv gitea /home/git
[toto@git ~]$ sudo mv app.ini /home/git
[toto@git ~]$ sudo -u git -H bash

bash-5.1$ cd /home/git
bash-5.1$ mv gitea/* /var/lib/gitea
bash-5.1$ ls /var/lib/gitea
data  log

bash-5.1$ mv app.ini /etc/gitea/
bash-5.1$ ls /etc/gitea
app.ini

bash-5.1$ exit

```

Sur `storage.tp5.linux`

```sh
[toto@storage nfs_shares]$ ls /srv/nfs_shares/repos
data  log

[toto@storage nfs_shares]$ ls /srv/nfs_shares/gitea
app.ini
```

Ca marche super !

### Montage automatique

Maintenant, on souhaite que le dossier soit mount automatiquement au lancement de la machine

```sh
[toto@git ~]$ sudo vim /etc/fstab
[toto@git ~]$ cat /etc/fstab
...
storage.tp5.linux:/srv/nfs_shares/repos /var/lib/gitea nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0
storage.tp5.linux:/srv/nfs_shares/gitea /etc/gitea nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=18000 0 0

[toto@git ~]$ sudo reboot
[toto@git ~]$ df -h
Filesystem                               Size  Used Avail Use% Mounted on
devtmpfs                                 4.0M     0  4.0M   0% /dev
tmpfs                                    227M  172K  227M   1% /dev/shm
tmpfs                                     91M  3.3M   88M   4% /run
/dev/mapper/rl-root                      6.2G  1.8G  4.5G  28% /
/dev/sda1                               1014M  299M  716M  30% /boot
storage.tp5.linux:/srv/nfs_shares/gitea  6.2G  1.2G  5.1G  20% /etc/gitea
storage.tp5.linux:/srv/nfs_shares/repos  6.2G  1.2G  5.1G  20% /var/lib/gitea
tmpfs                                     46M     0   46M   0% /run/user/1000
```

Et on test

```sh
[toto@git ~]$ sudo -u git touch /var/lib/gitea/test.txt
```

Et sur `storage.tp5.linux`

```sh
[toto@storage ~]$ ls /srv/nfs_shares/repos
data  log  test.txt
```

Parfait !
