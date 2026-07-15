# Developer Documentation

This document is for a developer who needs to set up, build, modify, or reason
about the Inception stack. For operating an already-built stack, see
`USER_DOC.md`.

## 1. Architecture

```
                        WWW
                         │
                         │ 443 (TLS 1.3)
   ┌─────────────────────┼──────────────────────────────┐
   │ HOST (Linux VM)     │                              │
   │  ┌──────────────────┼───────────────────────────┐  │
   │  │ Docker network   │  (bridge, user-defined)   │  │
   │  │                  ▼                           │  │
   │  │   ┌──────────┐  9000   ┌──────────────┐  3306│  │
   │  │   │  nginx   │◄───────►│  wordpress   │◄────┐│  │
   │  │   │          │ FastCGI │   php-fpm    │     ││  │
   │  │   └────┬─────┘         └──────┬───────┘     ││  │
   │  │        │                      │        ┌────▼┴┐ │
   │  │        │                      │        │mariadb│ │
   │  │        │                      │        └───┬──┘ │
   │  └────────┼──────────────────────┼────────────┼────┘
   │           │                      │            │
   │      ┌────▼──────────────────────▼──┐    ┌────▼────┐
   │      │  wp_volume                   │    │db_volume│
   │      │  /home/lorbke/data/wordpress │    │…/mariadb│
   │      └──────────────────────────────┘    └─────────┘
   └────────────────────────────────────────────────────┘
```

Key properties:

- **nginx is the only published port.** `443:443`. Nothing else is bound to the
  host. MariaDB and php-fpm are reachable only from inside the network.
- **Service discovery is by name.** Docker's embedded DNS on user-defined
  networks resolves `mariadb` and `wordpress` to container IPs. No `links:`, no
  hardcoded IPs, no `network_mode: host` — all three are forbidden by the subject
  and unnecessary.
- **The wp_volume is shared** between nginx and wordpress: nginx serves static
  assets from it directly, php-fpm executes the PHP from it.
- **`restart: always`** on every service, per the requirement that containers
  restart on crash.

## 2. Repository layout

```
.
├── Makefile                        # entrypoint for all operations
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
├── .gitignore                      # must contain srcs/.env
└── srcs/
    ├── docker-compose.yml
    ├── .env                        # NOT COMMITTED
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/nginx.conf
        │   └── tools/              # cert generation
        ├── wordpress/
        │   ├── Dockerfile
        │   └── tools/
        │       ├── init_wordpress.sh
        │       └── edit_www_conf.sh
        └── mariadb/
            ├── Dockerfile
            ├── conf/
            └── tools/
```

## 3. Setting up from scratch

### 3.1 Prerequisites

- Linux VM (the subject requires the project run in a VM)
- Docker Engine + Compose plugin
- `make`, `git`

```bash
sudo systemctl enable --now docker
sudo usermod -aG docker $USER    # then log out and back in
```

### 3.2 Host configuration

Point the domain at the local machine:

```bash
echo "127.0.0.1 lorbke.42.fr" | sudo tee -a /etc/hosts
```

Create the data directories:

```bash
mkdir -p /home/lorbke/data/mariadb /home/lorbke/data/wordpress
```

These **must exist before `docker compose up`**. The `local` volume driver with
`o: bind` does not create the source directory — a missing directory produces
`failed to mount local volume: ... no such file or directory` at container start.
The Makefile creates them for this reason.

### 3.3 Environment file

Create `srcs/.env`. Confirm it is ignored *before* committing anything:

```bash
git check-ignore srcs/.env    # must print the path
```

```bash
# srcs/.env

DOMAIN_NAME=lorbke.42.fr
DATA_PATH=/home/lorbke/data

# MariaDB
DB_HOST=mariadb
DB_NAME=wordpress
DB_USER=wp_user
DB_PASSWORD=<db user password>
DB_ROOT=<db root password>

# WordPress administrator
# NOTE: WP_ADMIN must not contain "admin"/"administrator" in any casing.
WP_ADMIN=<admin username>
WP_ADMIN_PASSWORD=<admin password>
WP_ADMIN_EMAIL=<admin email>

# WordPress second user (author role)
WP_USER=<username>
WP_USER_PASSWORD=<password>
WP_USER_EMAIL=<email>
```

`DB_HOST=mariadb` must match the **service name** in `docker-compose.yml` — that
is what Docker's DNS resolves.

> If a credential is ever committed, removing it in a later commit is not enough:
> it remains in Git history. Rewrite history or rotate the value.

### 3.4 Build and launch

```bash
make
```

## 4. Service internals

### 4.1 Base image

All three services use:

```dockerfile
FROM alpine:3.23
```

Pinned deliberately. `latest` is prohibited, and unpinned bases break silently:
Alpine renamed PHP packages from the old `php8` metapackage to versioned prefixes
(`php83`, `php84`, …), so an unpinned base eventually produces
`ERROR: unable to select packages: php8 (no such package)`.

To check what a base actually offers rather than guessing:

```bash
docker run --rm alpine:3.23 sh -c "apk update && apk search 'php8*' | sort"
```

### 4.2 nginx

Builds nginx and openssl, generates a self-signed certificate, and serves TLS on
443 only.

nginx runs in the foreground:

```dockerfile
ENTRYPOINT ["nginx"]
CMD ["-g", "daemon off;"]
```

### 4.3 wordpress

Installs WordPress and php-fpm, configures it from `.env`, and runs php-fpm in the foreground.

```dockerfile
ENTRYPOINT ["/init_wordpress.sh"]
CMD ["php-fpm83", "-F"]
```

### 4.4 mariadb

Installs `mariadb` and `mariadb-client`, initialises the data directory if empty,
creates the database and the WordPress user from environment variables, and runs
`mysqld` in the foreground.

The init logic must be idempotent: guard on whether the data directory is already
populated, since the volume persists across rebuilds.

## 5. ENTRYPOINT, CMD, and PID 1

This is the design constraint the subject cares about most, and the reason
`tail -f`, `sleep infinity`, and `while true` are forbidden.

**Build time vs run time.** `RUN` executes once, at image build, and bakes results
into layers — install packages, create symlinks, set `memory_limit`. The
entrypoint script executes at *every container start*, and is the only place that
can: wait for another container, read `.env` values, or branch on current state.
Baking credentials in with `RUN` would both hardcode secrets into image layers and
break when they change.

**How the two combine.** ENTRYPOINT is the command; CMD is its default argument.
Together:

```dockerfile
ENTRYPOINT ["/init_wordpress.sh"]
CMD ["php-fpm83", "-F"]
```

Docker runs `/init_wordpress.sh php-fpm83 -F`. The script receives
`php-fpm83 -F` as `$@`.

**Why PID 1 matters.** Docker launches one process per container, and it becomes
PID 1. The kernel treats PID 1 specially: it installs **no default signal
handlers**, so a signal only acts if the process explicitly handles it, and PID 1
inherits orphaned processes and is responsible for reaping them. `docker stop`
sends SIGTERM, waits 10s, then SIGKILL — so a PID 1 that ignores SIGTERM turns
every stop into a 10-second hang followed by a hard kill.

**Exec form vs shell form.** `CMD ["php-fpm83", "-F"]` (JSON array) execs the
binary directly → php-fpm is PID 1. `CMD php-fpm83 -F` (bare string) runs
`/bin/sh -c "php-fpm83 -F"` → **`sh`** is PID 1 and php-fpm is its child; `sh` does
not forward SIGTERM. Always use exec form for the main process.

**Why `exec "$@"`.** Because ENTRYPOINT is exec form, the *script* is PID 1 during
setup. `exec` replaces the current process image rather than forking, so the
script process *becomes* php-fpm, keeping PID 1. Without `exec`, the script stays
PID 1 and swallows signals.

Because most processes are actually not designed to be PID 1, the docker images are built with the `init: true` option in the compose file, which runs a minimal init process as PID 1 that forwards signals and reaps children. This is a common pattern to avoid issues with signal handling in containers.

## 6. Volumes and persistence

### Where data lives

| Volume | Container path | Host path |
|---|---|---|
| `db_volume` | `/var/lib/mysql` | `/home/lorbke/data/mariadb` |
| `wp_volume` | `/var/www/html` | `/home/lorbke/data/wordpress` |

### Declaration

```yaml
volumes:
  db_volume:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/mariadb

  wp_volume:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${DATA_PATH}/wordpress
```

These are **named volumes** — they appear in `docker volume ls`, are inspectable,
and are referenced by name in services (`db_volume:/var/lib/mysql`). The
`driver_opts` pin their storage to a chosen host path, which is what satisfies the
"data inside `/home/login/data`" requirement.

### Persistence semantics

- `make down` removes containers; data survives.
- `docker compose down -v` **removes the named volumes**. With the `bind` form
  this removes the volume objects; the host directories remain, but do not rely on
  this.
- `make fclean` deliberately wipes the host directories.
- Because data persists, **all init logic must be idempotent** — this is why the
  WordPress script guards on `wp-config.php` and the MariaDB script guards on an
  already-initialised data directory.

## 7. Useful commands

```bash
# Container state
docker compose -f srcs/docker-compose.yml ps
docker compose -f srcs/docker-compose.yml logs -f <service>

# Shell into a container
docker compose -f srcs/docker-compose.yml exec <service> sh

# Confirm PID 1
docker compose -f srcs/docker-compose.yml exec wordpress ps -ef

# Volumes
docker volume ls
docker volume inspect srcs_db_volume

# Network: confirm DNS resolution between services
docker network ls
docker compose -f srcs/docker-compose.yml exec wordpress getent hosts mariadb

# Verify TLS versions offered
docker compose -f srcs/docker-compose.yml exec nginx \
  openssl s_client -connect localhost:443 -tls1_2 </dev/null
# TLS 1.0/1.1 must fail:
openssl s_client -connect lorbke.42.fr:443 -tls1_1 </dev/null

# Inspect a base image's packages
docker run --rm alpine:3.23 sh -c "apk update && apk search 'php8*' | sort"

# Rebuild a single service
docker compose -f srcs/docker-compose.yml up -d --build wordpress
```