# Installation

## Installation des prérequis

```bash
# installation de git sur la machine
[toto@git ~]$ sudo dnf install git wget -y
[...]
Complete!

# ajout d'un user git qui gèrera le gitea
[toto@git ~]$ sudo useradd git -s /usr/sbin/nologin -m -d /var/lib/gitea

# récupération du binaire de gitea
[toto@git bin]$ wget -O gitea https://dl.gitea.io/gitea/1.17.3/gitea-1.17.3-linux-amd64
[...]
2022-12-02 09:25:42 (6.09 MB/s) - ‘gitea’ saved [112413616/112413616]

# changement des droits d'éxcution pour tout le monde
[toto@git bin]$sudo chmod +x gitea

# changement de propriétaire
[toto@git bin]$ sudo chown git:git gitea

# vérification
[toto@git bin]$ ls -l
total 109780
-rw-r--r--. 1 git git 112413616 Dec  2 09:56 gitea
```

## Fonctionnement du site

```bash
# ouverture du port 3000 dans le firewall
[toto@git bin]$ sudo firewall-cmd --add-port=3000/tcp --permanent && sudo firewall-cmd --reload
success
success
```

```bash
# ouverture d'un bash en temps que user git
[toto@git bin]$ sudo -u git -H bash

# lancement du site
[git@git bin]$ ./gitea web
2022/12/02 10:03:27 cmd/web.go:106:runWeb() [I] Starting Gitea on PID: 3365
[...]
2022/12/02 10:03:28 ...s/graceful/server.go:61:NewServer() [I] [6389bf60] Starting new Web server: tcp:0.0.0.0:3000 on PID: 3365

# vérification du fonctionnement du site
[git@git bin]$ curl 10.105.1.10:3000
<!DOCTYPE html>
<html lang="en-US" class="theme-">
<head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>Installation -  Gitea: Git with a cup of tea</title>
        <link rel="manifest" href="data:">
        <meta name="theme-color" content="#6cc644">
        <meta name="default-theme" content="auto">
        <meta name="author" content="Gitea - Git with a cup of tea">
```

## Création du service

```bash
# création du service
[toto@git bin]$ sudo vim /etc/systemd/system/gitea.service
[toto@git bin]$ sudo cat /etc/systemd/system/gitea.service
[Unit]
Description=Gitea (Git with a cup of tea)
After=syslog.target
After=network.target
[...]

[Service]
[...]
RestartSec=2s
Type=simple
User=git
Group=git
WorkingDirectory=/var/lib/gitea/
[...]
ExecStart=/usr/local/bin/gitea web --config /etc/gitea/app.ini
Restart=always
Environment=USER=git HOME=/home/git GITEA_WORK_DIR=/var/lib/gitea
[...]

[Install]
WantedBy=multi-user.target
```

```bash
# téléchargement du fichier app.ini
[toto@git ~]$ sudo mkdir -p /etc/gitea/
[toto@git ~]$ sudo curl https://raw.githubusercontent.com/go-gitea/gitea/main/custom/conf/app.example.ini --output /etc/gitea/app.ini
```

```bash
# lancement du service
[toto@git ~]$ sudo chown git:git /etc/gitea/app.ini
[toto@git ~]$ sudo systemctl enable gitea --now
Created symlink /etc/systemd/system/multi-user.target.wants/gitea.service → /etc/systemd/system/gitea.service.
[toto@git ~]$ systemctl status gitea
● gitea.service - Gitea (Git with a cup of tea)
     Loaded: loaded (/etc/systemd/system/gitea.service; enabled; vendor preset: disabled)
     Active: active (running) since Fri 2022-12-02 10:18:42 CET; 14s ago
     [...]
```