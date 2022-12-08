# Monitoring

## Installation des prérecquis

```sh
[toto@git ~]$ wget -O /tmp/netdata-kickstart.sh https://my-netdata.io/kickstart.sh && sh /tmp/netdata-kickstart.sh
```

```sh
[toto@git ~]$ sudo systemctl start netdata
[toto@git ~]$ sudo systemctl enable netdata
Created symlink /etc/systemd/system/multi-user.target.wants/netdata.service → /usr/lib/systemd/system/netdata.service.
[toto@git ~]$ sudo systemctl status netdata
● netdata.service - Real time performance monitoring
     Loaded: loaded (/usr/lib/systemd/system/netdata.service; enabled; vend>
     Active: active (running) since Mon 2022-12-05 23:13:38 CET; 16s ago
   Main PID: 1602 (netdata)
      Tasks: 31 (limit: 2648)
     Memory: 56.4M
        CPU: 1.425s
```

```sh
[toto@git ~]$ sudo ss -laptn | grep netdata
LISTEN    0      4096              127.0.0.1:8125               0.0.0.0:*     users:(("netdata",pid=1602,fd=45))
LISTEN    0      4096              127.0.0.1:19999              0.0.0.0:*     users:(("netdata",pid=1602,fd=6))
[...]
```

```sh
[toto@git ~]$ sudo firewall-cmd --add-port=19999/tcp --permanent
success
[toto@git ~]$ sudo firewall-cmd --reload
success
```

```sh
# création et modification du fichier de configuration pour les alertes
[toto@git netdata]$ sudo touch health.d/cpu_usage.conf

[toto@git netdata]$ sudo ./edit-config health.d/cpu_usage.conf
Editing '/etc/netdata/health.d/cpu_usage.conf' ...
[toto@git netdata]$ cat health.d/cpu_usage.conf
alarm: cpu_usage
on: system.cpu
lookup: average -3s percentage foreach user,system
units: %
every: 10s
warn: $this > 50
crit: $this > 80
info: CPU utilization of users or the system itself
```

```sh
# lancement des alarmes
[toto@git netdata]$ sudo netdatacli reload-health

# création du webook pour les alertes
[toto@git netdata]$ sudo /etc/netdata/edit-config health_alarm_notify.conf
Copying '/usr/lib/netdata/conf.d/health_alarm_notify.conf' to '/etc/netdata/health_alarm_notify.conf' ...
Editing '/etc/netdata/health_alarm_notify.conf' ...
[toto@git netdata]$ cat health_alarm_notify.conf | grep DISCORD
SEND_DISCORD="YES"
DISCORD_WEBHOOK_URL="https://discord.com/api/webhooks/1049806437859209247/pOhiiX04oUliWvmjaiO2fqV3-Ol5RNig-T1wBxYp_QWw2lad0j-1B8dBd_O00Iwd9aI2"
DEFAULT_RECIPIENT_DISCORD="alerte-a-la-bombe"
```

```sh
# test des alertes
[toto@git netdata]$ sudo stress-ng -c 10 -l 60
stress-ng: info:  [3282] defaulting to a 86400 second (1 day, 0.00 secs) run per stressor
stress-ng: info:  [3282] dispatching hogs: 10 cpu
^Cstress-ng: info:  [3282] successful run completed in 9.58s
```

```sh
# les alertes fonctionnent correctement !
```
