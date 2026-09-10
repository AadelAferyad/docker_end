# Inception Developer Guide

This guide is for developers who want to set up, extend, debug, or maintain
the Inception stack.

### 1) Development Goals

As a developer, you should be able to:

    Understand the three service boundaries (NGINX, WordPress/php-fpm, MariaDB).
    Modify service Dockerfiles, entrypoint scripts, and the compose definition.
    Add new services safely (e.g. bonus services).
    Debug startup/runtime issues quickly, including cross-container auth/networking bugs.

### 2) Recommended Knowledge

    Docker & Docker Compose fundamentals (images, layers, build vs runtime)
    Linux shell scripting (idempotent entrypoint scripts, PID 1 semantics)
    Networking basics (Docker bridge networks, internal DNS by service name, FastCGI)
    MariaDB/MySQL administration basics (users, grants, `mysql_install_db`)
    WordPress/WP-CLI basics

### 3) Environment Setup From Scratch

Prerequisites: a Linux VM with Docker Engine + the Compose plugin installed.

1. Clone the repository onto the VM.
2. Create `secrets/` at the project root (sibling to `srcs/`), containing:
   - `db_password.txt`
   - `db_root_password.txt`
   - `wp_user_password.txt`
   - `wp_admin_password.txt`

   Each file holds a single plaintext password, no trailing formatting beyond
   a newline. These are referenced by path in `srcs/docker-compose.yml`
   under the top-level `secrets:` block, and are **never** committed —
   confirm `secrets/` and `srcs/.env` are both listed in `.gitignore` before
   your first commit.
3. Create `srcs/.env` defining the non-secret configuration:

   ```
   DOMAIN_NAME=aaferyad.42.fr
   MYSQL_HOST=mariadb
   MYSQL_DATABASE=wordpress
   MYSQL_USER=wp_user
   WP_ADMIN_USER=wp_aaferyad
   WP_ADMIN_EMAIL=aaferyad@gmail.com
   WP_USER=normal_user
   WP_EMAIL=joe_user@gmail.com
   ```

   Note: `WP_ADMIN_USER` is validated at container-start time and must not
   contain `admin`/`administrator` in any case, per project requirements.
4. Add `aaferyad.42.fr` to `/etc/hosts` on whichever machine you'll browse
   from, pointing at the VM's IP (or `127.0.0.1` if browsing from inside the
   VM itself).

### 4) Local Development Workflow

Typical cycle:

    Start the full stack:          make
    After changing a Dockerfile
    or docker-compose.yml:         make re
    Stop everything, keep data:    make down
    Full reset (wipes volumes):    make fclean
    Inspect logs live:             docker logs -f <service>

When iterating on a single service's entrypoint script, note that most
setup logic in this project only runs on a **first-time** initialization
(guarded by checking for `/var/lib/mysql/mysql` in MariaDB, or
`wp-config.php` in WordPress). If you're testing a change to that setup
logic specifically, you need a clean volume — `make fclean && make` — or
your edit will silently be skipped on restart since the guard sees the
volume as "already initialized."

### 5) How Components Interact

The stack is orchestrated by `srcs/docker-compose.yml`:

    - `mariadb`, `wordpress`, and `nginx` are each built from their own
      Dockerfile under `srcs/requirements/<service>/`.
    - All three share the `inception_network` bridge network, and reach
      each other by service name via Docker's internal DNS (e.g.
      `mariadb:3306`, `wordpress:9000`) — never by hardcoded IP.
    - `mariadb` and `wordpress` publish **no ports to the host** — only
      `nginx` does, on 443, which is the sole entrypoint into the
      infrastructure.
    - `db_data` and `wp_data` are named volumes, pinned via `driver_opts` to
      `/home/aaferyad/data/mariadb` and `/home/aaferyad/data/wordpress` on
      the host. `wp_data` is mounted into **both** `wordpress` and `nginx`
      at the same path, since nginx needs direct filesystem access to serve
      static WordPress assets (uploads, themes, CSS/JS) — it cannot fetch
      them from the wordpress container the way it forwards PHP execution.
    - Non-secret config flows in via `env_file: .env`; passwords flow in via
      `secrets:`, mounted at `/run/secrets/<name>` inside each container.

When adding a dependency between services:

    Prefer internal service-to-service communication by service name over
    hardcoded IPs — container IPs are not stable across restarts.
    Keep externally published ports minimal — only nginx should ever
    publish to the host.
    Be aware that `env_file: .env` applies to *every* service listed under
    it — a variable meant only for one service (e.g. `MYSQL_HOST`, used by
    wordpress to reach mariadb) is still present inside every other
    container too, and can silently affect tools inside them that read it
    as a default (this caused a real bug during development: MariaDB's own
    internal `mysql` CLI calls were being redirected over TCP back to
    itself instead of using the local socket, because `MYSQL_HOST` was
    present in its own environment).

### 6) Adding a New Service

General checklist (relevant for bonus services — redis, ftp, adminer, etc.):

    Add a Dockerfile under srcs/requirements/<service>/.
    Add a service entry in docker-compose.yml, with its own image name
      matching the service name.
    Define required environment variables in .env, and any credentials as
      Docker secrets — never hardcoded.
    Add a dedicated named volume if the service is stateful.
    Only publish a host port if the service genuinely needs external
      reachability — most bonus services should stay internal on the
      docker network, same as mariadb/wordpress.
    Validate the compose file: docker compose -f srcs/docker-compose.yml config
    Rebuild and test in isolation before wiring it to the rest of the stack.

### 7) Debugging Strategy

Use this order — this is the actual sequence that resolved several bugs
during development:

    1. docker compose -f srcs/docker-compose.yml config   (catches YAML/syntax errors before anything runs)
    2. docker ps -a                                        (is the container actually up, or crash-looping?)
    3. docker inspect <container> --format '{{json .State}}'  (real exit code/error, not just docker ps status)
    4. docker logs <container> --tail 50                   (what actually happened at/before the crash)
    5. docker exec -it <container> bash                    (poke around inside directly)
    6. Reproduce the failing command manually inside the container,
       e.g. the exact `mysql -u ...` call your entrypoint script runs,
       to see the real client-side error instead of inferring from
       server-side log warnings.
    7. Rebuild with no cache if a script/config change doesn't seem to be
       taking effect: docker compose -f srcs/docker-compose.yml build --no-cache <service>

A repeating pattern of the same warning/error every few seconds in a
container's logs (e.g. once every 2 seconds) is usually a `sleep N` retry
loop somewhere upstream (often in a *different* container) that is stuck
because its readiness check keeps failing — check the dependent service's
entrypoint script's wait loop, not just the container the errors are
printed in.

### 8) Coding & Config Practices

    Keep entrypoint scripts idempotent: guard one-time setup (DB init,
      WordPress install) behind a check for a marker that only exists after
      that setup has run (a specific data subdirectory, a config file).
    Fail fast in shell scripts: set -euo pipefail at the top of every
      entrypoint script.
    Never let a container's PID 1 be a shell sitting idle — the final line
      of every entrypoint should exec the real long-running process
      (mariadbd, php-fpm, nginx) so it receives signals directly and
      restart/stop behaves correctly.
    Read passwords from Docker secret files ($(cat /run/secrets/<name>)),
      never from plain environment variables or hardcoded strings.
    Prefer explicit connection parameters (--protocol=socket, explicit
      --host) over relying on a tool's ambient environment-variable
      defaults, especially in a project where env_file: .env is shared
      across multiple services.
    Validate user-controlled values that get interpolated into SQL
      (e.g. restrict DB name/user to [A-Za-z0-9_]) before using them in a
      raw query string.

### 9) Validation Checklist

Before considering the mandatory part done:

    make succeeds on a genuinely clean environment (make fclean first)
    make re succeeds
    All three containers show "Up" in docker ps, none restarting in a loop
    https://<login>.42.fr loads WordPress in a browser (self-signed cert
      warning is expected and fine)
    mariadb and wordpress publish no ports to the host — only nginx does
    Killing a service's main process causes Docker to restart the container
      automatically (restart: on-failure)
    Stopping and recreating a container preserves its data (verify DB
      contents and WordPress files survive `docker rm` + recreate, as long
      as the named volume is reattached)
    No .env, secrets/*.txt, or other credentials are committed to Git
    README.md, USER_DOC.md, and DEV_DOC.md are all present and current

### 10) Maintenance Tips

    Periodically check for newer penultimate-stable Alpine/Debian releases
      and re-test the build against them.
    Use make fclean between unrelated test iterations to avoid a stale
      named volume masking a bug (a common source of confusing behavior:
      an entrypoint script's one-time setup logic silently not re-running
      because the "already initialized" marker survived from a broken
      previous run).
    Periodically review entrypoint scripts for anything that could leak a
      secret via process listing (ps aux) — prefer VAR=value cmd scoping
      (e.g. MYSQL_PWD=... mysqladmin ... shutdown) over passing passwords
      as bare CLI arguments.
    Keep this document aligned with the actual current service names, paths,
      and .env variable names as the project evolves.
