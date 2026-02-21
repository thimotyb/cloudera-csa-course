# Flink Operations Playground with Kafka (Standalone)

Questa demo replica il playground operativo di Flink con Kafka in una cartella vendorizzata locale, senza `git clone` esterno.

Funzionalita' coperte:

- failure/recovery automatico (kill taskmanager)
- osservazione job/runtime da CLI e REST API
- stop con savepoint e restart da savepoint
- rescale del job

## Struttura

- `docker-compose.yml`: stack demo (Flink JobManager/TaskManager, client, Kafka, event generator)
- `conf/`: configurazione Flink
- `ops-playground-image/`: Dockerfile + codice Java del job `ClickCountJob`
- `start-playground.sh`: build + up + readiness check dashboard
- `stop-playground.sh`: down dello stack

## Prerequisiti

- Docker Engine
- Docker Compose plugin (`docker compose`) o `docker-compose`
- `curl`
- `jq` (opzionale, utile per formattare output API)

## 1) Avvio demo

```bash
cd flink-demo/flink-operations-kafka
./start-playground.sh
```

Note:

- la dashboard Flink e' esposta di default su `http://127.0.0.1:18081`
- per usare `8081`: `FLINK_REST_PORT=8081 ./start-playground.sh`
- per saltare la build immagine: `SKIP_BUILD=true ./start-playground.sh`

Controllo stato:

```bash
docker compose ps
```

## 2) Log JobManager/TaskManager

```bash
docker compose logs -f jobmanager
docker compose logs -f taskmanager
```

## 3) Flink CLI dal container client

```bash
docker compose run --rm --no-deps client flink --help
docker compose run --rm --no-deps client flink list
```

## 4) Ispezione job via REST API

```bash
curl -s http://127.0.0.1:18081/jobs
```

Se hai cambiato porta:

```bash
curl -s "http://127.0.0.1:${FLINK_REST_PORT}/jobs"
```

## 5) Ispezione topic Kafka (input/output)

Apri due terminali separati:

Consumer input (`~1000 records/s`):

```bash
docker compose exec kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 --topic input
```

Consumer output (`~24 records/min`, aggregazione finestre da 15s):

```bash
docker compose exec kafka kafka-console-consumer \
  --bootstrap-server kafka:9092 --topic output
```

## 6) Fault injection e recovery

Kill del taskmanager:

```bash
docker compose kill taskmanager
```

Riavvio taskmanager:

```bash
docker compose up -d taskmanager
```

## 7) Upgrade/Rescale con savepoint

Lista job e copia `JOB_ID`:

```bash
docker compose run --rm --no-deps client flink list
```

Stop con savepoint:

```bash
docker compose run --rm --no-deps client flink stop <JOB_ID>
```

Dall'output copia il path `file:/tmp/flink-savepoints-directory/savepoint-...`.

Restart da savepoint:

```bash
docker compose run --rm --no-deps client flink run -s <SAVEPOINT_PATH> \
  -d /opt/ClickCountJob.jar \
  --bootstrap.servers kafka:9092 --checkpointing --event-time
```

Rescale (esempio parallelism `3`):

```bash
docker compose run --rm --no-deps client flink stop <JOB_ID>
docker compose up -d --scale taskmanager=2
docker compose run --rm --no-deps client flink run -p 3 -s <SAVEPOINT_PATH> \
  -d /opt/ClickCountJob.jar \
  --bootstrap.servers kafka:9092 --checkpointing --event-time
```

Dettaglio job:

```bash
curl -s http://127.0.0.1:18081/jobs/<JOB_ID>
```

## 8) Stop demo

```bash
./stop-playground.sh
```

Per rimuovere anche volumi:

```bash
REMOVE_VOLUMES=true ./stop-playground.sh
```

## Source

Materiale vendorizzato da:

- `https://github.com/thimotyb/flink-playgrounds`
- sottocartelle originali: `operations-playground` e `docker/ops-playground-image`
