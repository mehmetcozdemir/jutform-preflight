# JutForm — Pre-flight Environment Check

> **Note:** JutForm is a fictional, parody version of [Jotform](https://www.jotform.com) created solely for this assessment. It is not affiliated with or endorsed by Jotform in any way.

This repository verifies that your machine can run the JutForm assessment environment. Please complete these steps **before event day** so we can use all 3 hours for the actual assessment.

## Prerequisites

- An environment capable of running `docker` and `docker compose` (e.g., Docker Desktop, Colima, Podman, or native Docker Engine on Linux)
- Git
- A terminal / command line

## Setup

```bash
git clone <this-repo-url>
cd jutform-preflight

docker compose up -d
```

The first run will build images and download dependencies. This may take **5–10 minutes** depending on your internet connection.

Wait for all services to be healthy:

```bash
docker compose ps
```

All 5 services (nginx, php-fpm, mysql, redis, mailpit) should show `running` status.

## Verify

### Option A: Browser

Open [http://localhost:8080](http://localhost:8080) — you should see a status page that automatically checks all services.

### Option B: Command Line

```bash
./scripts/verify.sh
```

This runs all checks and reports pass/fail for each service.

### Option C: Direct API

```bash
curl http://localhost:8080/api/health | python3 -m json.tool
```

## What Gets Checked

| Check | What it verifies |
|-------|-----------------|
| Nginx | Web server is running, can serve static files and proxy to PHP |
| PHP-FPM | PHP 8.1 is running with required extensions (pdo, pdo_mysql, redis, json, intl, zip) |
| MySQL | Database is running, PHP can connect and execute queries |
| Redis | Redis is running, PHP can connect, write, and read |
| Mailpit | SMTP port is reachable (email capture service) |

## Expected Result

All checks should show **OK / PASSED**. If any check fails, see the troubleshooting section below.

## Troubleshooting

### "Cannot connect to the Docker daemon"
Docker is not running. Start Docker Desktop (or your Docker engine) and try again.

### Containers exit immediately
Check logs: `docker compose logs <service-name>` (e.g., `docker compose logs mysql`).

### Port conflicts
If ports 8080, 8025, 3307, 6380, or 1025 are already in use by other applications, either stop those applications or edit `docker-compose.yml` to use different host ports.

### MySQL takes a long time to start
On first run, MySQL initializes the database. Wait 30–60 seconds and check again: `docker compose ps`.

### Low memory errors
Ensure your container runtime has at least **4 GB of RAM** allocated. In Docker Desktop: Settings → Resources → Memory.

## Cleanup

When you're done verifying:

```bash
docker compose down -v
```

The `-v` flag removes the database volume so you start clean next time.

## Need Help?

If you cannot get the checks to pass after troubleshooting, contact your designated organizer with:

1. Your operating system and version
2. Docker version (`docker --version` and `docker compose version`)
3. The full output of `./scripts/verify.sh`
4. Any error logs from `docker compose logs`
