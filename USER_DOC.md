# User Documentation

This document is for anyone who needs to *run and operate* the Inception stack —
an end user or an administrator. It assumes no knowledge of how the project is
built internally. For that, see `DEV_DOC.md`.

## 1. What this stack provides

Inception runs a small WordPress website, served securely over HTTPS, on your own
machine. It is made of three cooperating services:

| Service | What it does for you |
|---|---|
| **nginx** | The front door. Everything you access in a browser goes through it. It handles the HTTPS encryption and is the only part of the stack reachable from outside. |
| **wordpress** | The website itself — pages, posts, the admin dashboard. Runs WordPress with php-fpm. |
| **mariadb** | The database, where all site content, settings, and user accounts are stored. Not reachable from outside; only the WordPress service talks to it. |

Your site data (database contents and uploaded files) is kept in two persistent
volumes on the host, so stopping or rebuilding the containers does not lose it.

**What you get:** a WordPress site at `https://lorbke.42.fr` with two accounts
already created — one administrator and one regular author.

## 2. Prerequisites

Before starting, make sure of the following.

**Docker must be running.** On the Linux VM:

```bash
sudo systemctl status docker      # check
sudo systemctl start docker       # start if inactive
```

**The domain must resolve to your machine.** `lorbke.42.fr` is not a real public
domain — it only works because your machine is told to point it at itself. Check
that `/etc/hosts` contains this line:

```
127.0.0.1 lorbke.42.fr
```

If it is missing, add it (requires sudo). Without it, the site will simply not
load — this is the single most common reason "nothing happens".

**The data directory must exist**, at `/home/lorbke/data`. The Makefile creates
it, but if you are setting up manually:

```bash
mkdir -p /home/lorbke/data/mariadb /home/lorbke/data/wordpress
```

**Configuration must be present.** The file `srcs/.env` holds the domain name and
credentials. It is deliberately not in the repository — see section 5.

## 3. Starting and stopping the project

All commands are run from the root of the project directory.

### Start

```bash
make
```

This builds the three images and starts the containers in the background. The
first run takes several minutes: it builds from scratch and WordPress installs
itself. Later starts are much faster.

### Stop

```bash
make down
```

Stops and removes the containers. **Your data is not deleted** — it stays in
`/home/lorbke/data` and comes back on the next start.

### Rebuild from scratch

```bash
make re
```

Tears everything down and rebuilds the images. Use this after changing a
Dockerfile or a configuration file.

### Watch it start

```bash
docker compose -f srcs/docker-compose.yml logs -f
```

Press `Ctrl-C` to stop watching (this does not stop the containers).

<!-- TODO: adjust the target names above to match your actual Makefile. -->

## 4. Accessing the website and the admin panel

### The website

Open **https://lorbke.42.fr** in a browser.

**You will see a security warning** — something like "Your connection is not
private" or "not secure". **This is expected and correct.** The site uses a
self-signed certificate: the connection *is* encrypted, but no public Certificate
Authority vouches for the certificate's identity, so the browser cannot verify
who it is talking to and warns you. For a local project domain like `.42.fr`, no
trusted certificate is possible.

To proceed: click **Advanced** → **Proceed to lorbke.42.fr (unsafe)**. In Safari,
click **Show Details** → **visit this website**.

Note that `http://` (port 80) is not served. Only HTTPS on port 443 is exposed.

### The admin panel

Go to:

```
https://lorbke.42.fr/wp-admin
```

Log in with the **administrator** credentials (see section 5). The second account
has the *author* role and cannot access the full dashboard — use the admin
account for administration.

## 5. Locating and managing credentials

### Where they live

Credentials are stored in **`srcs/.env`**, which is excluded from Git via
`.gitignore` and therefore is not in the repository. It must be created locally
before first start. This is deliberate: any credential committed to the
repository fails the project. You can use the provided `srcs/.env.example` as a template.

The variables it defines:

| Variable | Meaning |
|---|---|
| `DOMAIN_NAME` | The site domain (`lorbke.42.fr`) |
| `DB_HOST` | Database hostname on the Docker network (`mariadb`) |
| `DB_NAME` | The WordPress database name |
| `DB_USER` / `DB_PASSWORD` | The database account WordPress uses |
| `DB_ROOT` | The MariaDB root password |
| `WP_ADMIN` / `WP_ADMIN_PASSWORD` / `WP_ADMIN_EMAIL` | The WordPress administrator account |
| `WP_USER` / `WP_USER_PASSWORD` / `WP_USER_EMAIL` | The second, non-admin account |

### Rules and constraints

- Never commit `srcs/.env`. Verify with `git check-ignore srcs/.env` — if it
  prints the path, it is correctly ignored.

### Changing a password

Changing `.env` after installation does **not** change already-created accounts —
those values were used once, at first install, and now live in the database.

To change the WordPress admin password on a running stack:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress \
  wp user update <username> --user_pass='<new-password>' --allow-root
```

Or use the dashboard: **Users → Profile → Set New Password**.

To make new `.env` values take effect from scratch, you must reset the data —
see section 7.

## 6. Checking that the services are running correctly

### Are all three containers up?

```bash
docker compose -f srcs/docker-compose.yml ps
```

All three should show `Up`. If one shows `Restarting`, or its uptime keeps
resetting to a few seconds, it is crash-looping — check its logs.

### Read the logs

```bash
docker compose -f srcs/docker-compose.yml logs nginx
docker compose -f srcs/docker-compose.yml logs wordpress
docker compose -f srcs/docker-compose.yml logs mariadb
```

Note that **a quiet nginx is a healthy nginx** — it logs very little until
requests arrive. Absence of nginx output is not by itself a problem.

Two log lines that look alarming but are normal:

- `[Warning] Aborted connection ... user: 'unauthenticated' ... (This connection
  closed normally without authentication)` in MariaDB — this is the WordPress
  container's readiness check knocking on the database port during startup. It is
  a `Warning`, not an error, and it says *closed normally*.
- The browser certificate warning, as explained in section 4.

### Is the site actually served over TLS?

```bash
curl -kIv https://lorbke.42.fr 2>&1 | grep -iE "SSL|TLS|HTTP/"
```

`-k` tells curl to accept the self-signed certificate. You should see a TLS
version negotiated and an HTTP status returned.

### Is the database reachable and populated?

```bash
docker compose -f srcs/docker-compose.yml exec mariadb \
  mariadb -u root -p -e "SHOW DATABASES;"
```

### Is WordPress installed?

```bash
docker compose -f srcs/docker-compose.yml exec wordpress \
  wp core is-installed --allow-root && echo "installed"
```

```bash
docker compose -f srcs/docker-compose.yml exec wordpress \
  wp user list --allow-root
```

This should list exactly two users, one an administrator.

## 7. Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| Browser cannot reach the site at all | Missing hosts entry | Add `127.0.0.1 lorbke.42.fr` to `/etc/hosts` |
| "Not secure" warning | Self-signed certificate | Expected — click through it |
| `502 Bad Gateway` | nginx cannot reach php-fpm | Check the wordpress container is `Up`; nginx must `fastcgi_pass wordpress:9000` |
| Site loads but redirects to the wrong URL | WordPress `siteurl`/`home` mismatch | See below |
| Container keeps restarting | Bad config or crash at startup | Read that container's logs |
| `Cannot connect to the Docker daemon` | Docker not running | `sudo systemctl start docker` |

**Fixing a wrong site URL:**

```bash
docker compose -f srcs/docker-compose.yml exec wordpress wp option get siteurl --allow-root
docker compose -f srcs/docker-compose.yml exec wordpress wp option get home --allow-root
```

Both should read `https://lorbke.42.fr`. If not:

```bash
docker compose -f srcs/docker-compose.yml exec wordpress \
  wp option update siteurl https://lorbke.42.fr --allow-root
docker compose -f srcs/docker-compose.yml exec wordpress \
  wp option update home https://lorbke.42.fr --allow-root
```

## 8. Full reset (destroys all data)

This deletes the database and the site files, and reinstalls WordPress from the
current `.env` values on next start.

```bash
make down
sudo rm -rf /home/lorbke/data/mariadb/* /home/lorbke/data/wordpress/*
make
```

> **Warning:** this is irreversible. Everything in the site — posts, users,
> uploads, settings — is destroyed.