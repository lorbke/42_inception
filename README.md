*This project has been created as part of the 42 curriculum by lorbke.*

# Inception

## Description

Inception is a system administration exercise. The goal is to build a small,
self-contained web infrastructure from scratch, running entirely inside Docker
containers on a virtual machine, orchestrated with Docker Compose.

The stack serves a WordPress site over HTTPS. It is composed of three services,
each isolated in its own container, each built from a Dockerfile written by hand
from a bare Alpine base — no ready-made images are pulled from DockerHub:

| Service | Role |
|---|---|
| **nginx** | TLS termination and the only entrypoint to the infrastructure (port 443). Serves static files and forwards PHP requests to WordPress over FastCGI. |
| **wordpress** | WordPress + php-fpm. No web server of its own; it only speaks FastCGI on port 9000. |
| **mariadb** | The database. Reachable only from inside the Docker network on port 3306. |

Two named volumes hold the persistent state — the database files and the
WordPress site files — so that data survives container removal and rebuilds.
A user-defined bridge network connects the three containers and isolates them
from the host network.

The point of the exercise is containerisation: image
building, process isolation, service orchestration, persistence, networking, and
secret handling.

## Instructions

### Prerequisites

- A Linux virtual machine
- Docker Engine and the Docker Compose plugin
- `make`
- Data directory: `/home/lorbke/data` or permission to create it
- A hosts entry pointing the domain at the local machine:
  ```
  127.0.0.1 lorbke.42.fr
  ```

### Configuration

Create `srcs/.env` with the required environment variables (see `DEV_DOC.md`/`.env.example` for
the full list). This file is **not** committed — it is listed in `.gitignore`.

### Running

```bash
make          # build the images and start the stack
make down     # stop and remove the containers
make re       # rebuild from scratch
```

Then open **https://lorbke.42.fr** in a browser. The certificate is self-signed,
so the browser will warn that the site is not trusted; this is expected and you
must accept it to proceed.

Full usage instructions are in `USER_DOC.md`; setup and internals are in
`DEV_DOC.md`.

## Project description

### Use of Docker

Every service is built from its own `Dockerfile` under
`srcs/requirements/<service>/`, based on **Alpine 3.23** — the penultimate stable
release at the time of writing. The tag is pinned explicitly; `latest` is
prohibited by the subject and is a bad idea regardless, because package names and
versions shift underneath you between releases.

Each container runs exactly one service, as a foreground process in the PID 1
slot. No daemonising, no `tail -f`, no `sleep infinity`. Where start-time setup is
needed, an entrypoint script performs it and then hands off to the real process
with `exec "$@"`, so that the long-running process inherits PID 1 and receives
signals from `docker stop` directly.

### Sources included

```
.
├── Makefile
├── README.md
├── USER_DOC.md
├── DEV_DOC.md
└── srcs/
    ├── docker-compose.yml
    ├── .env                      (gitignored)
    └── requirements/
        ├── nginx/
        │   ├── Dockerfile
        │   ├── conf/
        │   └── tools/
        ├── wordpress/
        │   ├── Dockerfile
        │   └── tools/
        └── mariadb/
            ├── Dockerfile
            ├── conf/
            └── tools/
```

### Main design choices

**Alpine over Debian.** Smaller images and faster builds. The cost is that Alpine
packages PHP under versioned names (`php83`, `php83-fpm`, …) and installs
versioned binaries (`/usr/bin/php83`), so the WordPress image symlinks
`/usr/bin/php` for WP-CLI, whose shebang is `#!/usr/bin/env php`.

**WP-CLI for provisioning.** The WordPress container downloads and installs
WordPress at first start via WP-CLI, driven entirely by environment variables. The
init script guards on the presence of `wp-config.php`, so the install runs once and
subsequent restarts go straight to php-fpm.

**Waiting for the database.** Compose starts containers, it does not wait for them
to be *ready*. The WordPress entrypoint polls MariaDB's port before running any
`wp` command. This is a bounded readiness check, not an infinite loop keeping the
container alive — the container's life is php-fpm, which the script `exec`s into
once setup completes.

**nginx as sole entrypoint.** Only nginx publishes a port (443). MariaDB and
php-fpm are reachable only over the internal Docker network, by service name. The
database is never exposed to the host.

### Virtual Machines vs Docker

A **virtual machine** virtualises hardware. A hypervisor presents virtual CPUs,
memory, and disks, and a complete guest OS — its own kernel included — boots on
top. Isolation is very strong, since the guest kernel is genuinely separate. The
cost is weight: each VM carries a full OS, boots in tens of seconds, and consumes
its allocated RAM whether or not it uses it.

A **container** virtualises the operating system instead. Containers are ordinary
processes on the host, isolated by kernel features — namespaces (separate views of
the filesystem, network, process tree, users) and cgroups (resource limits). All
containers on a host **share the host's kernel**. There is no guest OS to boot, so
containers start in milliseconds and cost roughly what the process itself costs.

The trade-off is isolation strength versus overhead. A VM's escape surface is the
hypervisor; a container's is the shared kernel, which is a much larger surface.
Containers also cannot run a different kernel from the host — which is why Docker
on macOS and Windows runs a Linux VM behind the scenes to supply a Linux kernel,
and why this project is required to be done in a Linux VM.

For this project, containers are the right tool: three services that must be
isolated from one another, started and destroyed constantly during development,
and shipped as reproducible images. Three VMs would be absurd overkill for the
same result.

### Secrets vs Environment Variables

**Environment variables** (here, `srcs/.env` consumed by Compose) are convenient
and the standard way to configure containers. Their weaknesses are real:

- They are visible in `docker inspect` and in `/proc/<pid>/environ` inside the
  container.
- Child processes inherit them, so any subprocess sees every secret.
- They tend to get logged or dumped in crash reports by accident.
- If baked into an image with `ENV` or `ARG`, they persist in the image layers —
  which is why the subject forbids passwords in Dockerfiles.

**Docker secrets** instead mount the secret as a file inside the container
(under `/run/secrets/<name>`, on tmpfs — memory-backed, never written to the
container's disk). Access is per-service rather than ambient: only services that
declare a secret can read it, it is not inherited by child processes as
environment state, and it does not appear in `docker inspect`'s env listing.

The practical division used here: `.env` carries non-sensitive configuration
(domain name, database name, service hostnames), while passwords are the
candidates for secrets. Either way, nothing containing a credential is committed —
the subject is explicit that credentials found in the Git repository fail the
project outright.

### Docker Network vs Host Network

With **host networking** (`network_mode: host`), a container shares the host's
network namespace outright. It has no separate IP; binding port 443 in the
container *is* binding port 443 on the host. There is no isolation and no
port-mapping step, which is why it is occasionally used for raw throughput — and
why it is forbidden here.

With a **user-defined bridge network**, Docker creates an isolated virtual network
with its own subnet. Each container gets its own IP and its own network namespace.
Three things follow, and they are exactly what this project needs:

1. **Isolation.** Nothing is reachable from the host unless a port is explicitly
   published. MariaDB listens on 3306 and the host cannot touch it — only
   containers on the same network can.
2. **Automatic DNS.** Docker runs an embedded resolver on user-defined networks, so
   containers resolve each other by **service name**. WordPress connects to
   `mariadb:3306` and nginx forwards to `wordpress:9000` — no IPs, no `links:`, no
   hardcoding. This is why `links:` is both forbidden and unnecessary: it is the
   obsolete predecessor of this behaviour.
3. **A single controlled entrypoint.** Because only nginx publishes `443:443`, the
   attack surface exposed to the outside world is one port on one service.

Host networking would collapse all three: every service would be exposed on the
host, name resolution between them would not exist, and the "nginx is the only
entrypoint" requirement would be unenforceable.

### Docker Volumes vs Bind Mounts

Both make data outlive a container, but they differ in *who owns the storage*.

A **bind mount** maps an arbitrary host path into the container. The host path is
the source of truth; Docker manages nothing and only points at it. It is
excellent for development (edit code on the host, see it live in the container)
but couples the container to the host's filesystem layout, and permissions/UID
mismatches are a common source of pain.

A **named volume** is a storage object that Docker itself creates and tracks. It
has a name, appears in `docker volume ls`, is inspectable and removable through
Docker, and by default lives under `/var/lib/docker/volumes/<name>/_data`. The
container references it by name and knows nothing about host paths, which makes
the service definition portable. Named volumes are the intended mechanism for
*persistent application state* — databases, uploads — as opposed to source code.

This project requires named volumes for the database and the WordPress files, and
forbids bind mounts for them, while *also* requiring that the data live inside
`/home/lorbke/data` on the host. Those two constraints pull against each other,
since a plain named volume puts its data wherever Docker's data root is. The two
ways to satisfy both:

- Declare named volumes with `driver_opts` (`type: none`, `o: bind`,
  `device: /home/lorbke/data/...`). The object is a named volume in every sense
  Docker tracks, but the local driver uses the kernel's bind mechanism to pin it to
  the chosen path. This is the common approach.
- Move Docker's `data-root` to `/home/lorbke/data` in `/etc/docker/daemon.json`
  and declare plain named volumes with no driver options at all. The volumes are
  then unambiguously "pure" named volumes, and their data physically resides inside
  `/home/lorbke/data/volumes/<name>/_data` — which satisfies the "inside
  `/home/login/data`" wording without invoking any bind mechanism.

<!-- TODO: state which of the two you chose and why. Be ready to defend it. -->

## Resources

### Documentation

- Docker documentation — https://docs.docker.com/
- Dockerfile reference — https://docs.docker.com/reference/dockerfile/
- Docker Compose file reference — https://docs.docker.com/reference/compose-file/
- Docker storage / volumes — https://docs.docker.com/engine/storage/volumes/
- Docker networking — https://docs.docker.com/engine/network/
- Docker secrets — https://docs.docker.com/engine/swarm/secrets/
- Alpine Linux packages — https://pkgs.alpinelinux.org/packages
- nginx documentation — https://nginx.org/en/docs/
- nginx `ngx_http_ssl_module` — https://nginx.org/en/docs/http/ngx_http_ssl_module.html
- PHP-FPM configuration — https://www.php.net/manual/en/install.fpm.configuration.php
- MariaDB documentation — https://mariadb.com/kb/en/documentation/
- WP-CLI handbook — https://make.wordpress.org/cli/handbook/
- OpenSSL `req` — https://docs.openssl.org/master/man1/openssl-req/

### Articles and references

- "Docker and the PID 1 zombie reaping problem" — https://blog.phusion.nl/2015/01/20/docker-and-the-pid-1-zombie-reaping-problem/
- tini, a minimal init for containers — https://github.com/krallin/tini
- RFC 8446 — TLS 1.3 — https://datatracker.ietf.org/doc/html/rfc8446

### Use of AI

AI (Claude) was used for:
Answering in-depth questions about Docker and how PID 1 works in containers.
Fixing errors that arose when updating to Alpine 3.23 and PHP 8.3, which required changes to the Dockerfiles and entrypoint scripts. The AI was not used to merely replace the existing code, but to understand the underlying issues and suggest solutions. I then verified these suggestions by testing the containers and ensuring they worked as expected.
AI was also used to help smoothe writing of the README.md, USER_DOC.md and DEV_DOC.md files.