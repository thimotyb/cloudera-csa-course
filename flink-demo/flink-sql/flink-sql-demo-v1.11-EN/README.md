# Flink SQL Demo (Vendored, v1.11-EN)

Vendored copy of the tutorial repository, adapted to run locally in this course repo with Docker Compose, CLI, and standalone Flink.

## References

- Upstream tutorial repo (branch `v1.11-EN`):
  - https://github.com/thimotyb/flink-sql-demo/tree/v1.11-EN
- Apache Flink blog tutorial:
  - https://flink.apache.org/2020/07/28/flink-sql-demo-building-an-end-to-end-streaming-application/

## What was adapted for this repository

- vendored source under this folder (no runtime `git clone` required)
- local image builds for `sql-client`, `datagen`, and `mysql`
- non-conflicting default host ports (so it can run together with other demos)
- helper scripts for start/stop
- included sample `datagen/user_behavior.log` so the generator works out of the box

## Run (CLI/Standalone)

```bash
cd flink-demo/flink-sql/flink-sql-demo-v1.11-EN
./scripts/start-standalone.sh
```

Default endpoints:

- Flink REST/UI: `http://127.0.0.1:18082`
- Kibana: `http://127.0.0.1:15601`
- Elasticsearch HTTP: `http://127.0.0.1:19200`
- MySQL host port: `13306`

Open SQL Client:

```bash
docker compose exec sql-client /opt/sql-client/sql-client.sh
```

## Minimal validation commands

Check jobmanager readiness:

```bash
curl -s http://127.0.0.1:18082/overview
```

Inspect generated Kafka input:

```bash
docker compose exec kafka bash -lc \
  '/usr/bin/kafka-console-consumer --topic user_behavior --bootstrap-server kafka:9094 --from-beginning --max-messages 10'
```

## Stop

```bash
./scripts/stop-standalone.sh
```

Remove volumes too:

```bash
REMOVE_VOLUMES=true ./scripts/stop-standalone.sh
```

## Notes

- `docker compose` is preferred; scripts also support legacy `docker-compose`.
- If port `18082` is in use, set another value:

```bash
FLINK_SQL_REST_PORT=18083 ./scripts/start-standalone.sh
```
