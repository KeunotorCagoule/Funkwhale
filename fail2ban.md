# Fail2Ban

## Installation des prérecquis

```sh
[toto@git ~]$ sudo dnf install epel-release
Last metadata expiration check: 2:01:05 ago on Mon Dec  5 14:11:05 2022.
Dependencies resolved.
[...]
Complete!

[toto@git ~]$ sudo dnf install fail2ban
Extra Packages for Enterprise Linux 9 - x86 2.2 MB/s |  12 MB     00:05
Last metadata expiration check: 0:00:08 ago on Mon Dec  5 16:12:47 2022.
Dependencies resolved.
[...]
Complete!
```

## Configuration du Fail2Ban

```sh
# ajout du filtre Fail2Ban
[toto@git filter.d]$ sudo vim gitea.conf
[toto@git ~]$ cat /etc/fail2ban/filter.d/gitea.conf
[Definition]
failregex =  .*(Failed authentication attempt|invalid credentials|Attempted access of unknown user).* from <HOST>
ignoreregex =
```

```sh
# ajout de la configuration du Fail2Ban
[toto@git jail.d]$ sudo vim gitea.conf
[toto@git ~]$ cat /etc/fail2ban/jail.d/gitea.conf
[gitea]
enabled = true
filter = gitea
logpath = /var/lib/gitea/log/gitea.log
maxretry = 3
findtime = 300
bantime = 10800
action = iptables-allports
```

```sh
[toto@git ~]$ sudo systemctl start fail2ban
[toto@git ~]$ sudo systemctl status fail2ban
● fail2ban.service - Fail2Ban Service
     Loaded: loaded (/usr/lib/systemd/system/fail2ban.service; enabled; vendor preset: disabled)
     Active: active (running) since Sun 2022-12-11 22:37:46 CET; 24min ago
       Docs: man:fail2ban(1)
    Process: 712 ExecStartPre=/bin/mkdir -p /run/fail2ban (code=exited, status=0/SUCCESS)
   Main PID: 729 (fail2ban-server)
      Tasks: 5 (limit: 2648)
     Memory: 2.7M
        CPU: 717ms
     CGroup: /system.slice/fail2ban.service
             └─729 /usr/bin/python3 -s /usr/bin/fail2ban-server -xf start
[...]
```
