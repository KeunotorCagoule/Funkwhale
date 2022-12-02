# Proxy

## Sommaire

- [Installation](#installation)
- [Config](#config)
- [SSL](#ssl)

## Installation

On install nginx

```sh
[toto@proxy ~]$ sudo dnf install nginx -y
Rocky Linux 9 - BaseOS                                                 8.9 kB/s | 3.6 kB     00:00
Rocky Linux 9 - BaseOS                                                 2.3 MB/s | 1.7 MB     00:00
Rocky Linux 9 - AppStream                                               11 kB/s | 4.1 kB     00:00
Rocky Linux 9 - Extras                                                 7.8 kB/s | 2.9 kB     00:00
Dependencies resolved.
[...]
Complete!
```

On le start et récupère le port qu'il écoute

```sh
[toto@proxy ~]$ sudo systemctl start nginx
[toto@proxy ~]$ sudo systemctl enable nginx
Created symlink /etc/systemd/system/multi-user.target.wants/nginx.service → /usr/lib/systemd/system/nginx.service.
[toto@proxy ~]$ sudo systemctl status nginx
● nginx.service - The nginx HTTP and reverse proxy server
     Loaded: loaded (/usr/lib/systemd/system/nginx.service; enabled; vendor preset: disabled)
     Active: active (running) since Fri 2022-12-02 12:00:34 CET; 16s ago
[toto@proxy ~]$ sudo ss -laptn | grep nginx
LISTEN 0      511          0.0.0.0:80        0.0.0.0:*     users:(("nginx",pid=1357,fd=6),("nginx",pid=1356,fd=6))
LISTEN 0      511             [::]:80           [::]:*     users:(("nginx",pid=1357,fd=7),("nginx",pid=1356,fd=7))
```

On ouvre le port dans le firewall

```sh
[toto@proxy ~]$ sudo firewall-cmd --add-port=80/tcp --permanent
success
[toto@proxy ~]$ sudo firewall-cmd --reload
success
```

On test avec la conf par défaut

```sh
[toto@proxy ~]$ curl 10.105.1.12:80
<!doctype html>
<html>
  <head>
    <meta charset='utf-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1'>
    <title>HTTP Server Test Page powered by: Rocky Linux</title>
    <style type="text/css">
    [...]
```

## Config

On change la config de nginx afin de le transformer en reverse proxy

```sh
[toto@proxy ~]$ sudo vim /etc/nginx/conf.d/gitea.conf
[toto@proxy ~]$ cat /etc/nginx/conf.d/gitea.conf
server {
  server_name git.tp5.linux;

  # Port d'écoute de NGINX
  listen 80;

  location / {
    proxy_set_header  Host $host;
    proxy_set_header  X-Real-IP $remote_addr;
    proxy_set_header  X-Forwarded-Proto https;
    proxy_set_header  X-Forwarded-Host $remote_addr;
    proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;

    proxy_pass http://10.105.1.10:3000/;
  }
}
```

On restart pour appliquer les modifications

```sh
[toto@proxy ~]$ sudo systemctl restart nginx
success
```

Et on test

```sh
$ curl git.tp5.linux
<!DOCTYPE html>
<html lang="en-US" class="theme-">
<head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title> Gitea</title>
        ...
```

## SSL

On génère notre clé / certificat

```sh
[toto@proxy ~]$ openssl req -new -newkey rsa:2048 -days 365 -nodes -x509 -keyout server.key -out server.crt
```

On change les permissions et on change le propriétaire

```sh
[toto@proxy ~]$ chmod 0600 server.crt server.key
[toto@proxy ~]$ sudo chown nginx:nginx server.crt
[toto@proxy ~]$ sudo chown nginx:nginx server.key
```

On les déplace au bon endroit

```sh
[toto@proxy ~]$ sudo mv server.crt /etc/pki/tls/certs
[toto@proxy ~]$ sudo mv server.key /etc/pki/tls/private/
```

On modifie la config de nginx et on restart

```sh
[toto@proxy ~]$ sudo vim /etc/nginx/conf.d/gitea.conf
[toto@proxy ~]$ sudo cat /etc/nginx/conf.d/gitea.conf
server {
  # On indique le nom que client va saisir pour accéder au service
  # Pas d'erreur ici, c'est bien le nom de web, et pas de proxy qu'on veut ici !
  server_name git.tp5.linux;

  # Port d'écoute de NGINX
  listen 443 ssl;

  ssl_certificate /etc/pki/tls/certs/server.crt;
  ssl_certificate_key /etc/pki/tls/private/server.key;

  location / {
    # On définit des headers HTTP pour que le proxying se passe bien
    proxy_set_header  Host $host;
    proxy_set_header  X-Real-IP $remote_addr;
    proxy_set_header  X-Forwarded-Proto https;
    proxy_set_header  X-Forwarded-Host $remote_addr;
    proxy_set_header  X-Forwarded-For $proxy_add_x_forwarded_for;

    # On définit la cible du proxying
    proxy_pass http://10.105.1.10:3000;
  }
}
[toto@proxy ~]$ sudo systemctl restart nginx
```

On ouvre le port 443

```sh
[toto@proxy ~]$ sudo firewall-cmd --remove-port=80/tcp --permanent
success
[toto@proxy ~]$ sudo firewall-cmd --add-port=443/tcp --permanent
success
[toto@proxy ~]$ sudo firewall-cmd --reload
success
```

Et enfin on test

```sh
$ curl https://git.tp5.linux
curl: (60) schannel: SEC_E_UNTRUSTED_ROOT (0x80090325) - La chaîne de certificats a été fournie par une autorité qui n'est pas approuvée.
More details here: https://curl.se/docs/sslcerts.html
```

Malgré l'erreur affichée, ce qui est normal, le serveur sous https fonctionne parfaitement
