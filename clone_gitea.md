# Clone Gitea

Maintenant qu'on a un serveur de stockage à part, un reverse proxy et une réplication de donnée, on va pouvoir faire un second Gitea, qui sera utilisé par le reverse proxy pour répartir le traffic entre ces deux, et ainsi alléger les ressources

## Setup

Pour commencer, on va recréer un gitea, on va donc suivre la même [Install Gitea](./gitea.md)

Sur le serveur de stockage, on va aussi devoir autoriser l'accès au dossier et la config distante

```sh
[toto@repos srv]$ sudo vim /etc/exports
[toto@repos srv]$ cat /etc/exports
/srv/nfs_shares/repos git.tp5.linux(rw,sync,no_subtree_check) clone.tp5.linux(rw,sync,no_subtree_check)
/srv/nfs_shares/backup_db db.tp5.linux(rw,sync,no_subtree_check)

[toto@repos srv]$ sudo systemctl restart nfs-server
```

Ensuite on les montes (automatiquement) sur notre vm toute fraiche

```sh
[toto@clone ~]$ sudo vim /etc/fstab
[toto@clone ~]$ cat /etc/fstab
...
storage.tp5.linux:/srv/nfs_shares/repos /var/lib/gitea nfs auto,nofail,noatime,nolock,intr,tcp,actimeo=1800 0 0

[toto@clone ~]$ sudo reboot
[toto@clone ~]$ df -h
Filesystem                               Size  Used Avail Use% Mounted on
devtmpfs                                 4.0M     0  4.0M   0% /dev
tmpfs                                    227M  172K  227M   1% /dev/shm
tmpfs                                     91M  3.3M   88M   4% /run
/dev/mapper/rl-root                      6.2G  1.8G  4.5G  28% /
/dev/sda1                               1014M  299M  716M  30% /boot
storage.tp5.linux:/srv/nfs_shares/repos  6.2G  1.2G  5.1G  20% /var/lib/gitea
tmpfs                                     46M     0   46M   0% /run/user/1000
```

Parfait, on a également récupéré la conf `app.ini` du premier serveur, en changeant les params de connexion à la db (pour se connecter à `replication.tp5.linux`)

Sur le serveur MySQL (replication)

```sql
CREATE USER 'gitea'@'clone.tp5.linux' IDENTIFIED BY 'gitea_db';
GRANT ALL PRIVILEGES ON giteadb.* TO 'gitea'@'clone.tp5.linux';
FLUSH PRIVILEGES;
```

Et enfin

```sh
[toto@clone ~]$ sudo systemctl enable gitea --now
```

Parfait !

## Reverse Proxy

Cependant, notre reverse proxy, ne renvoit que sur le serveur 1 (`git.tp5.linux`), pas ouf.

Pour changer cela, on va donc faire

```sh
[toto@proxy ~]$ sudo vim /etc/nginx/conf.d/gitea.conf
[toto@proxy ~]$ cat /etc/nginx/conf.d/gitea.conf
stream {
        upstream stream_gitea {
                server http://10.105.1.10:3000;
                server http://10.105.1.15:3000;
        }
}

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
            proxy_pass stream_gitea;
        }
}
```

Où l'on a ajouter le `stream {...}` et modifé le `proxy_pass`.
D'après les documentations trouvés, dans le `stream`, à droite des urls des `server` donnés, on aurait précisé un poid (weight) si l'on aurait voulu une répartition du traffic en 75%/25% ou autre, mais puisque l'on souhaite une répartition égale, on n'en précise pas.

Et voilà !
