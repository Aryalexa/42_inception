## general

1. NGINX - reverse proxy, handles HTTPS/TLS, routes requests to PHP-FPM
  2. WordPress - PHP application running in php-fpm, handles business logic
  3. MariaDB - database

  The flow is: Client -> NGINX (443) -> WordPress (php-fpm on 9000) -> MariaDB (3306)

  I should explain this clearly and concisely.

● How These Services Work

  The flow:

   Client (https://mayrcast.42.fr:443)
       ↓
   NGINX container (reverse proxy, TLS termination)
       ↓
   WordPress container (php-fpm daemon on port 9000)
       ↓
   MariaDB container (database on port 3306)

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


## concepts and QnAs

### `expose`expose* in Docker Compose
- expose makes the port available to other containers on the same Docker network, but not to the host.

-----

### why NGINX needs to mount the WordPress volume
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


------

### Alpine vs Debian

From bases.md: "penultimate stable version of Alpine or Debian" — your choice.

Alpine (chosen here):

 - ✅ Tiny (~5MB base vs ~100MB for Debian)
 - ✅ Faster build/push/pull
 - ✅ Smaller attack surface
 - ✅ Docker standard (most images use Alpine)
 - ❌ Uses musl libc instead of glibc (can cause compatibility issues with some apps)
 - ❌ Fewer packages, fewer docs

Debian:

 - ✅ More packages, better compatibility
 - ✅ glibc (standard C library)
 - ❌ Much larger, slower
 - ❌ More bloat for a container

For this project: Alpine is fine, but if MariaDB has issues, switching to Debian is easy. Let's test MariaDB first and see.

### docker secrets
Déjame desglosarlo:
│  mariadb:
│    environment:
│      MYSQL_PASSWORD_FILE: /run/secrets/db_password    # ← Dónde buscar el password
│    secrets:
│      - db_password                                     # ← Qué archivo montar como secret

El flujo:
1. Docker Secrets (secrets: en compose):
│  secrets:
│    - db_password:
│        file: ../secrets/db_password.txt 
   → Docker copia secrets/db_password.txt a /run/secrets/db_password dentro del contenedor
   → Solo legible para ese contenedor, no en env vars de la terminal
2. *_FILE pattern (MYSQL_PASSWORD_FILE):
    - Es un patrón que usan las imágenes de MariaDB, PostgreSQL, WordPress, etc.
    - En lugar de pasar MYSQL_PASSWORD=mipass123 (inseguro, visible en env),
    - Pasas MYSQL_PASSWORD_FILE=/run/secrets/db_password (la imagen lee el archivo)
    - La imagen lee el contenido del archivo y lo usa como password
3. .env (variables no-secretas):
│  DOMAIN_NAME=mayrcast.42.fr
│  MYSQL_USER=wordpress
   → Estas SÍ se pasan como env vars normales (no son secretas) 

 Resumido:
┌─────────────┬──────────────────────┬────────────────────────┬───────────────────│
│ Tipo        │ Cómo                 │ Seguridad              │ Uso               │
├─────────────┼──────────────────────┼────────────────────────┼───────────────────│
│ Secrets     │ /run/secrets/        │ ✅ Alta (no en env)    │ Passwords, keys   │
│             │ (archivo)            │                        │                   │
├─────────────┼──────────────────────┼────────────────────────┼───────────────────│
│ Env vars    │ ENV_VAR=valor        │ ❌ Baja (visible en    │ Domain, usernames │
│             │                      │ env)                   │                   │
├─────────────┼──────────────────────┼────────────────────────┼───────────────────│
│ _FILE       │ Patrón que lee       │ ✅ Alta                │ Passwords vía     │
│             │ archivo              │                        │ secrets           │
└─────────────┴──────────────────────┴────────────────────────┴───────────────────│

 ¿Necesitas tanto *_FILE como secrets:?
- secrets: = monta el archivo en el contenedor
- MYSQL_PASSWORD_FILE = le dice a MariaDB "lee aquí el password" 

Sin secrets:, el archivo no existe en el contenedor.
Sin MYSQL_PASSWORD_FILE, MariaDB buscaría MYSQL_PASSWORD (env var insegura).

## make it work

### mariadb
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