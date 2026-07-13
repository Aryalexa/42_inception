
# INCEPTION

## intro

what this is about

## Table of contents

steps
1. understand the project
2. plan: from independent service we grow out
3. plan execution
3.1. mariadb
3.2. mount mariadb in a container
3.3. wordpress
3.4. mount wordpress as a service
3.5. run wordpress with its DB
3.6. nginx
3.7. add nginx to the docker compose
3.8. run everything
3.9. now let's use a VM
3.10. set up


container and docker useful info
- docker secrets

decisions
1. ...


### 1. understand the project
After reading the **project requirements**, we now know:

- this is a containers project. Each container is a service and they communicate via a network.

- we will control the services via Makefile, so using make to get the project up and running

- containers must be built from OS images: "decision 1: alpine vs debian" 🪻🔗

- volumes: Docker named volumes vs bind mount 🪐🔗

- we should follow best practices for writaing Dockerfiles. 🪐🔗

- `<login>.42.fr` should resolve to your machine’s IP address, not to a public DNS server. 🪐🔗

- we will make sure to user docker secrets 🪐🔗

- there are three services:
  - db: mariadb
    where the wordpress DB data is stored
  - back: wordpress
    needs its own storage to store wp website files
    🌷 clients can access the web via..
  - web service: nginx
    🌷 it adds a layer of ... in front of wp


### 2. plan
We start with the most independent service first. It gives fast feedback and isolates failures.

1) MariaDB (first)
Why: WordPress needs a ready DB and created user.

2) WordPress (second)
Why: WordPress mounts the wordpress volume (site files) and needs DB creds; php-fpm listens on 9000 so NGINX not required yet.

3) NGINX (last)

### 3.8

#### **NGINX must be the only entrypoint**

Your architecture should look like:

```text
Internet
     │
     ▼
NGINX (443 HTTPS)
     │
 ┌───┴─────┐
 │         │
 ▼         ▼
WordPress  MariaDB
```

Only **NGINX** is exposed to the outside.

Example:

```yaml
nginx:
  ports:
    - "443:443"
```

WordPress:

```yaml
wordpress:
  expose:
    - "9000"
```

MariaDB:

```yaml
mariadb:
  expose:
    - "3306"
```

Notice there are **no `ports:`** for WordPress or MariaDB. They are reachable only by other containers on the Docker network.

#### **Only port 443**

Do **not** expose:

```text
80
8080
3306
9000
```

Only:

```text
443
```

should be accessible from the host.

---

#### TLS 1.2 or TLS 1.3

NGINX must serve HTTPS using modern TLS versions.

Typical configuration:

```nginx
ssl_protocols TLSv1.2 TLSv1.3;
```

Older protocols like:

* SSLv3
* TLSv1.0
* TLSv1.1

must be disabled.


### 3.10
On a new machine, the only manual setup should be:

- Create .env from .env.example.
- Create the required files under secrets/.
- Update the local hosts file (login.42.fr → your local/VM IP).
- Run docker compose up.

