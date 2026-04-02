# Event Platform Infra

Docker setup for local development: **RabbitMQ** (AMQP + management UI).

## Repositories

[GitHub: Elena-sky](https://github.com/Elena-sky)

- [event-platform-gateway-api](https://github.com/Elena-sky/event-platform-gateway-api)
- [event-platform-notification-service](https://github.com/Elena-sky/event-platform-notification-service)
- [event-platform-analytics-audit-service](https://github.com/Elena-sky/event-platform-analytics-audit-service)
- [event-platform-retry-orchestrator-service](https://github.com/Elena-sky/event-platform-retry-orchestrator-service)
- [event-platform-infra](https://github.com/Elena-sky/event-platform-infra)

## Configuration

```bash
cp .env.example .env
```

Edit `.env` for credentials, ports, and `EVENT_PLATFORM_NETWORK_NAME`.

## Requirements

- [Docker](https://docs.docker.com/get-docker/) and Docker Compose v2

**CI:** on push/PR to `main` or `master`, [`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs `docker compose config` (after `cp .env.example .env`) to validate the Compose file.

## Usage

Start services (from this directory, with `.env` present):

```bash
docker compose up -d
```

Validate configuration:

```bash
docker compose config
```

Stop:

```bash
docker compose down
```

Stop and remove the data volume (queues/messages in RabbitMQ):

```bash
docker compose down -v
```

## Services and ports

| Service | Host port | Description |
|---------|-----------|-------------|
| RabbitMQ AMQP | `RABBITMQ_AMQP_PORT` (see `.env.example`) | Clients on the host |
| Management UI | `RABBITMQ_MANAGEMENT_PORT` | e.g. http://localhost:15672 |

Data volume: `rabbitmq_data`.
