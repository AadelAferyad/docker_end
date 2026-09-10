# Inception


## Description

Inception is a system administration project whose goal is to deploy a small,
production-style web infrastructure entirely inside Docker containers,
orchestrated with Docker Compose, on a dedicated virtual machine.

The stack is built from scratch — every image is built from a custom
Dockerfile rather than pulled pre-made from Docker Hub (with the sole
exception of the Alpine/Debian base images themselves) — and is composed of
three services, each running in its own dedicated container:

- **NGINX** — the single entrypoint into the infrastructure, serving traffic
  over TLS (v1.2/v1.3 only) on port 443.
- **WordPress + php-fpm** — the actual website, running as a FastCGI
  application server with no bundled web server.
- **MariaDB** — the relational database backing WordPress, with no bundled
  web server.

Two Docker named volumes persist state across container restarts: one for
the MariaDB data directory, one for the WordPress site files. Both are
pinned to `$(HOME)/data` on the host. All three services communicate
over a dedicated Docker bridge network, and all credentials are supplied via
Docker secrets and a non-secret `.env` file rather than being hardcoded
anywhere in the images.

## Instructions

### Prerequisites

- A Linux virtual machine with Docker Engine and the Docker Compose plugin
  installed.
- The domain `aaferyad.42.fr` resolving to the VM's local IP address (e.g.
  via an `/etc/hosts` entry on the machine you're browsing from).

### Setup

1. Clone the repository onto the VM.
2. Create a `secrets/` folder at the project root containing:
   - `db_password.txt`
   - `db_root_password.txt`
   - `wp_user_password.txt`
   - `wp_admin_password.txt`
3. Create a `srcs/.env` file defining (at minimum): `DOMAIN_NAME`,
   `MYSQL_DATABASE`, `MYSQL_USER`, `MYSQL_HOST`, `WP_ADMIN_USER`,
   `WP_ADMIN_EMAIL`, `WP_USER`, `WP_EMAIL`.
4. From the project root, run:

   ```bash
   make
   ```

   This creates the host data directories, builds all three images from
   their Dockerfiles, and starts the stack in detached mode.

5. Visit `https://aaferyad.42.fr` in a browser. The TLS certificate is
   self-signed, so a browser warning is expected on first visit — accept it
   to proceed to the site.

### Other Makefile targets

| Target | Effect |
|---|---|
| `make` | Build and start the full stack |
| `make down` | Stop and remove containers (volumes/images kept) |
| `make clean` | `down`, plus remove any leftover stopped containers |
| `make fclean` | Full teardown: containers, volumes, images, and host data directories all removed |
| `make re` | `fclean` followed by a fresh `make` |

## Resources

- [Docker documentation](https://docs.docker.com/)
- [Docker Compose file reference](https://docs.docker.com/compose/compose-file/)
- [MariaDB Knowledgebase](https://mariadb.com/kb/)
- [WP-CLI Handbook](https://make.wordpress.org/cli/handbook/)
- [PHP-FPM documentation](https://www.php.net/manual/en/install.fpm.php)
- [NGINX Docs — SSL/TLS termination](https://nginx.org/en/docs/http/configuring_https_servers.html)

## Quick Start
```bash
#1) Clone
git clone https://github.com/AadelAferyad/docker_end.git
cd docker_end

#2) Build and start all services
make

#3) Verify running containers
docker ps 
```

## Make Command
```bash
# Build and run all services
make

# Stop and remove running stack
make down

# Rebuild everything from scratch and restart
make re

# Full cleanup (containers/images/other artifacts according to Makefile)
make fclean
```
## Operation Guids
```bash
# Show logs (all services)
docker compose logs -f

# Show logs for a specific service
docker compose logs -f <service_name>

# Restart one service
docker compose restart <service_name>

# Rebuild one service
docker compose build <service_name>

docker compose up -d <service_name>
```
