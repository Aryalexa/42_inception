# Research notes

## Containers vs VM
| Containers                                       | Virtual Machines (VMs)                              |
| ------------------------------------------------ | --------------------------------------------------- |
| Share the host OS kernel                         | Each VM has its own guest OS                        |
| Lightweight (MBs)                                | Heavier (GBs)                                       |
| Start in seconds or less                         | Start in minutes (typically)                        |
| Lower resource usage                             | Higher CPU, RAM, and disk usage                     |
| Best for microservices, CI/CD, cloud-native apps | Best for running different OSes or strong isolation |
| Isolation at the process level                   | Isolation at the hardware/hypervisor level          |
| Examples: Docker, Podman                         | Examples: VMware, VirtualBox, Hyper-V, KVM          |

Rule of thumb
* **Use containers** when you want **fast deployment, portability, and efficient resource usage**.
* **Use VMs** when you need **different operating systems, stronger isolation, or full machine virtualization**.

Simple analogy
* **Container** = Apartment in a building (shares the building infrastructure).
* **VM** = Separate house (has its own infrastructure, but costs more to maintain).

## Docker named volumes VS bind mounts

> Bind mounts are for: Development, sharing source code
> ``- host-addr:cont-addr``
> Named volumes are for: Databases, persistent app data
> ``- vol-name:cont-addr``

### Named Volumes
A named volume is managed by Docker. You give it a name, and Docker stores it in its own storage directory.

```yaml
services:
    service:
        volumes:
            - postgres-data:/var/lib/postgresql/data
volumes:
  postgres-data:
```
Pros
- Docker manages everything. Docker chooses location.
- Safer. You can't accidentally delete data by modifying a host folder.
- Better portability between environments.

Cons
- Harder to inspect files directly.
- Files aren't stored in an obvious location.

### Bind mounts
A bind mount maps an existing folder from your computer into the container. Editing a file on your computer immediately changes it inside the container.

```yaml
services:
    service:
        volumes:
            - ./src:/app
```

Pros
- Great for development. Live code changes.
- Easy to inspect files.
- Works well with editors and Git.

Cons
- Container depends on the host directory existing.
- Less portable.
- File permission issues are more common.
- Unsafe. Can accidentally overwrite files inside the container.

## PID 1

* **PID 1** is the main process inside a container.
* Docker runs the command specified by `CMD` (or `ENTRYPOINT`) as the container's main process.
* PID 1 is responsible for:
  * Receiving termination signals (`SIGTERM`, `SIGINT`).
  * Reaping zombie child processes.
* Use the **exec form** of `CMD` so your application becomes PID 1.

**Good**
```dockerfile
CMD ["node", "server.js"]
```

**Avoid**
```dockerfile
CMD node server.js
```

Reason: the shell form runs `/bin/sh -c`, making the shell PID 1 instead of your application, which can interfere with signal handling. 
Imagine Docker wants to stop your container and sends SIGTERM. The shell receives the signal first. It may not forward it to your app, so it never gets the chance to shut down gracefully.


**Why does PID 1 have special behavior?** 

On Linux, PID 1 is the init process. It has responsibilities that ordinary processes don't:
- it receives signals intended for the container
- it should clean up ("reap") exited child processes to avoid zombie processes

When your application is PID 1, it inherits those responsibilities.


## Dockerfile CMD

* `CMD` specifies the **default command** to run when a container starts.
* It can be overridden at runtime:
```bash
docker run my-image python other.py
```
* Prefer the **exec form** (`CMD ["cmd", "arg1"]`) over the shell form (`CMD cmd arg1`).
  - exec form: Docker starts the command directly. And it PID 1.
  - shell form: Docker actually runs ``/bin/sh -c "cmd arg1"```. Now the shell is PID 1, not your app.


> Always use the exec form of `CMD` (`CMD ["app"]`) so your application runs as PID 1, receives signals correctly, and can shut down gracefully.


## Dockerfile ENTRYPOINT

> `ENTRYPOINT` defines the **main executable** of the container. Unlike `CMD`, it is **not easily replaced** when running the container.

`ENTRYPOINT` Defines the executable that always runs.

```dockerfile
ENTRYPOINT ["python"]
CMD ["app.py"]
```

Running:
```bash
docker run my-image
```
executes ``python app.py``

Running:
```bash
docker run my-image other.py
```
executes ``python other.py``


The `CMD` is replaced, but `ENTRYPOINT` (`python`) stays.

Rule of thumb
* **`CMD`** → default command or default arguments (easy to override).
* **`ENTRYPOINT`** → fixed executable that the container is built to run. Often combined with `CMD` for default arguments.

### entrypoint script
An **entrypoint script** is a shell script that is executed as the container's `ENTRYPOINT` before starting the main application.

```dockerfile
COPY docker-entrypoint.sh /
ENTRYPOINT ["/docker-entrypoint.sh"]
CMD ["node", "server.js"]
```

`docker-entrypoint.sh`:

```sh
#!/bin/sh
set -e

# Initialization
echo "Waiting for database..."

# Run migrations
npm run migrate

# Start the main application
exec "$@"
```

#### Why use an entrypoint script?

To perform startup tasks such as:

* Waiting for a database or another service.
* Running database migrations.
* Creating configuration files from environment variables.
* Initializing directories or permissions.

#### Why `exec "$@"`?

The last line should almost always be `exec "$@"`.

Here `$@` = all the arguments passed to the script. So `$@` expands to: `node server.js`. `exec` replaces the shell with that command. Without `exec`, PID 1 is the shell executing the entrypoint script.

**Takeaway:** An entrypoint script is for **initialization before your app starts**, and it should end with `exec "$@"` so the main application runs as PID 1.


## Best Dockerfile Best Practices

> A good Dockerfile should produce an image that is:
> * ✅ Small
> * ✅ Secure
> * ✅ Reproducible
> * ✅ Cache-friendly (fast builds)
> * ✅ Runs the application as **PID 1**
> * ✅ Easy to configure without rebuilding
> * ✅ Contains only what's needed to run the application


### 1. Use a minimal base image

Smaller images are faster and have fewer vulnerabilities.

```dockerfile
FROM node:22-alpine
```

---

### 2. Pin image versions

Avoid `latest` to ensure reproducible builds.

```dockerfile
FROM node:22.15-alpine
```

---

### 3. Leverage Docker layer caching

Copy dependency files first, then install dependencies.

```dockerfile
COPY package*.json ./
RUN npm install

COPY . .
```

---

### 4. Use a `.dockerignore`

Exclude files like:

```text
node_modules
.git
.env
coverage
```

This reduces build time and image size.

---

### 5. Use multi-stage builds

Keep build tools out of the final image.

```dockerfile
FROM node AS builder
# build

FROM nginx
COPY --from=builder ...
```

---

### 6. Run as a non-root user

Improves container security.

```dockerfile
USER app
```

---

### 7. Use the exec form

Prefer:

```dockerfile
CMD ["node", "server.js"]
ENTRYPOINT ["python"]
```

Avoid:

```dockerfile
CMD node server.js
```

This ensures your application becomes **PID 1**.

---

### 8. Use an entrypoint script only when needed

Use it for initialization (e.g., migrations, config generation, waiting for dependencies), and finish with:

```sh
exec "$@"
```

---

### 9. Reduce image layers

Combine related `RUN` commands and clean up caches.

```dockerfile
RUN apt-get update && \
    apt-get install -y curl && \
    rm -rf /var/lib/apt/lists/*
```

---

### 10. Keep images immutable

* Don't store data inside the image.
* Inject configuration with **environment variables**.
* Persist data using **volumes**.

## DNS (Domain Name System) and the hosts file
This is about **DNS (Domain Name System)** and the **hosts file**.

**How a domain name is resolved**

Normally, when you visit a web `google.com`..
- your computer asks a **DNS** server for the correspondent IP address.
- The DNS server replies: `142.250.x.x`.
- Then your browser connects to that IP.

**But before...**

Before asking a DNS server, your operating system checks a local file called **hosts**.

The hosts file is simply a manual mapping: `IP_ADDRESS` and `DOMAIN_NAME`.

Example:
```text
127.0.0.1 localhost
```
This means: Whenever I type `localhost`, connect to `127.0.0.1`.


**Where is the hosts file?** Editing it usually requires administrator/root privileges.

* Linux/macOS
```
/etc/hosts
```
* Windows
```
C:\Windows\System32\drivers\etc\hosts
```

> Making a domain point to our local IP address lets you test features that depend on the **Host** header, virtual hosts, HTTPS certificates, or domain-based routing, even though the site is running locally.

> the hosts file is simply a **local, manual DNS override**.





## Docker Secrets

In the Compose file:

```yaml
services:
  service:
    environment:
      DB_PS_FILE: /run/secrets/db_password    # ← Read the value from a file (*_FILE pattern)
    secrets:
      - db_password                           # ← Mount this secret into the service container

secrets:
  db_password:                                # ← Create a secret from a local file
    file: ../secrets/db_password.txt          #    The file will be mounted inside the container as read-only
```

### Basic flow

1. **Create the secrets and specify where to use them**

   * In the Compose file, declare the secret and reference a local file.
   * In each service, specify which secrets should be mounted.

   ```yaml
   secrets:
     db_password:
       file: ./secrets/db_password.txt

   services:
     service:
       secrets:
         - db_password
   ```

2. **Inside the container, the secret appears as a read-only file at `/run/secrets/db_password`**

   * Docker copies `secrets/db_password.txt` to `/run/secrets/db_password` inside the container.
   * The file is only accessible from that container and is **not** exposed as an environment variable.

3. **Use the `*_FILE` pattern** (for example, `DB_PS_FILE=/run/secrets/db_password`) so the application reads the secret from the file instead of from an environment variable.

> **Notes:** Secrets are not baked into the image, are not exposed as environment variables, and should never be committed to Git.

### `*_FILE` pattern (e.g., `DB_PS_FILE`)

**Using passwords with secrets**

* This is a pattern supported by official images such as MariaDB, PostgreSQL, WordPress, and others.
* Instead of passing `DB_PS=myPassword123` (which is insecure because it's visible as an environment variable),
* You pass `DB_PS_FILE=/run/secrets/db_password`.
* The image reads the file's contents and uses that value as the password.

### `.env` (non-secret variables)

```text
DOMAIN_NAME=macastro.42.fr
DB_USER=wordpress
```

These values are passed as regular environment variables because they are **not** considered sensitive.

### Summary

| Type                      | How it's provided           | Security                           | Typical use                                          |
| ------------------------- | ------------------------- | ------------------------- | ------------------------- |
| **Secrets**               | `/run/secrets/` (file)      | ✅ High (not in env)     | Passwords, keys, certificates                    |
| **Env vars**              | `ENV_VAR=value`             | ❌ Low (visible in the env) | Domain names, usernames, configuration               |
| **`*_FILE` pattern**      | Reads the value from a file | ✅ High                 | Passwords via secrets |





## general

1. NGINX - reverse proxy, handles HTTPS/TLS, routes requests to PHP-FPM
2. WordPress - PHP application running in php-fpm, handles business logic
3. MariaDB - database

The flow is:

   Client (https://mayrcast.42.fr:443)
       ↓
   NGINX container (reverse proxy, TLS termination)
       ↓
   WordPress container (php-fpm daemon on port 9000)
       ↓
   MariaDB container (database on port 3306)

● How These Services Work

**NGINX Container**
 - **Role**: Reverse proxy + TLS terminator
 - **Listens on**: Port 443 (HTTPS only, as required)
 - **What it does**:
    - Accepts HTTPS requests from the internet
    - Decrypts them using self-signed cert (for local testing)
    - Routes PHP requests to the WordPress container's php-fpm  daemon (port 9000)
    - Serves static files (CSS, JS, images) directly
 - The client never talks to WordPress or MariaDB—they only see  NGINX
 - **Key config**:
 location ~ \.php$ {
     fastcgi_pass wordpress:9000;  # Forward PHP requests to  wordpress container
 }

**WordPress Container**
 - **Role**: PHP application server (NOT a web server)
 - **Listens on**: Port 9000 (php-fpm daemon—NOT HTTP)
 - **What it does**:
    - Runs PHP-FPM (FastCGI Process Manager)—a daemon that processes PHP code
    - Receives requests from NGINX via the fastcgi_pass directive
    - Executes WordPress PHP code, queries the database
    - Returns HTML/JSON responses back to NGINX
 - IMPORTANT: It has NO web server (no nginx inside), no port 80/443—just PHP processing
 - Volume: Shares /var/www/html with NGINX so both can access WordPress files

**MariaDB Container**

 - **Role**: Database server
 - **Listens on**: Port 3306 (internal Docker network only, not exposed to internet)
 - **What it does**: - Stores WordPress posts, users, settings, etc.
 - Only WordPress (and MariaDB itself) can reach it via the Docker network
 - Initialized with database wordpress, user wordpress, and root password

**The Network**
All three containers connect via a Docker bridge network (inception). They talk to each other by hostname:
 - NGINX talks to wordpress:9000
 - WordPress talks to mariadb:3306
 - Client talks to NGINX at https://mayrcast.42.fr:443




## `expose` in Docker Compose
- expose makes the port available to other containers on the same Docker network, but not to the host.


## why NGINX needs to mount the WordPress volume
Technically, NGINX could proxy ALL requests to WordPress (including static files), and let WordPress serve them. But that would be inefficient:

 Current setup:
    Static request (image.png) → NGINX → serves directly from volume (fast, no PHP)
    PHP request (index.php) → NGINX → fastcgi_pass → WordPress processes → returns HTML
 
 Alternative (WordPress serves everything):
    Static request (image.png) → NGINX → fastcgi_pass → WordPress → serves file (slower, unnecessary PHP)
    PHP request (index.php) → NGINX → fastcgi_pass → WordPress → processes → returns HTML

Why NGINX needs the volume:

 1. Performance: Static files (CSS, JS, images) can be served instantly without touching PHP-FPM
 2. Efficiency: Reduces load on the PHP daemon—it only processes .php files, not images/CSS
 3. Caching: NGINX can set proper cache headers on static assets independently

If you removed the volume from NGINX:

 - Every CSS, JS, image request would go through PHP-FPM unnecessarily
 - Slower response times
 - More CPU usage on the WordPress container

However, in a production setup, you might actually store static assets in object storage (S3, etc.) separate from the volume, and NGINX would proxy those. But for this project, sharing the volume is the right call.






## mariadb
Test MariaDB Alone
```sh
 # Create the data directory (required by docker-compose)
 mkdir -p /home/mayrcast/data/mariadb
 
 # Edit secrets with real passwords (locally only, not in git)
 nano secrets/db_root_password.txt
 nano secrets/db_password.txt
 
 # Build just mariadb
 docker-compose -f srcs/docker-compose.yml build mariadb
 
 # Run just mariadb
 docker-compose -f srcs/docker-compose.yml up -d mariadb
 
 # Check if it's running?
 docker-compose -f srcs/docker-compose.yml ps
 
 # View logs
 docker-compose -f srcs/docker-compose.yml logs mariadb
 
 # Test connection from host (if you have mariadb-client installed)
 mysql -h 127.0.0.1 -u root -p<password> -e "SHOW DATABASES;"
 
 # Or test from inside container
 docker exec mariadb mysql -u root -p<password> -e "SHOW DATABASES;"

What to check:

 1. Container starts without crashing
 2. Logs show no errors
 3. Database initializes with wordpress DB and wordpress user
 
 ```