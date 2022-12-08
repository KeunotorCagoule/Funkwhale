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
