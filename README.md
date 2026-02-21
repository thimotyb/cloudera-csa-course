# Cloudera CSA Course Workspace

This repository contains material and runnable demos for the CSA (Cloudera Streaming Analytics) course using CSA Community Edition.

## What is in this repo

- CSA local stack (Docker Compose)
- Course docs (requirements, syllabus, installation notes)
- Slides and slide-generation helper
- Hands-on streaming demos (Kafka, Schema Registry, Kafka Connect, Debezium, Flink tutorial)
- A running fix log for operational issues

## Quick Start

### 1) Start CSA CE

First-time setup:

```bash
./install_csa.sh
```

Subsequent starts:

```bash
./start_csa.sh
```

### 2) Main Endpoints

- SSB UI: `http://localhost:18121`
- SSB MVE: `http://localhost:18131`
- SMM UI: `http://localhost:9991`
- SMM API: `http://localhost:8585`
- Flink UI: `http://localhost:8081`
- Schema Registry: `http://localhost:7788`
- Kafka (host listener): `localhost:9094`

## Repository Map

- `docker-compose.yml`: CSA CE stack used in this workspace
- `install_csa.sh`: install/start script with prerequisites + image pull
- `start_csa.sh`: fast startup script for already-installed environments
- `INSTALLATION.md`: installation procedure and service overview
- `REQUIREMENTS.md`: environment requirements
- `SYLLABUS.md`: course module structure
- `FIX.md`: cumulative log of issues and fixes applied
- `csa-snippets_v1.txt`: quick command snippets used during labs
- `jdbc-sink.json`: ready-to-import Kafka Connect JDBC Sink config
- `schema-registry-kafka-java-client/`: Java demo for Kafka + Schema Registry
- `debezium-mysql-source-demo/`: containerized Debezium MySQL Source demo
- `flink-demo/flink/`: Flink tutorial demos + local `flink-training` snapshot
- `flink-demo/flink-cli-wordcount/`: Flink local-cluster CLI demo (WordCount)
- `flink-demo/flink-cli-windowing/`: Flink local-cluster CLI demo (windowing tutorial modernizzato Java 21)
  - include anche guida CSA: `flink-demo/flink-cli-windowing/README_CSA.md`
- `flink-demo/flink-operations-kafka/`: Flink Operations Playground standalone con Kafka (recovery, savepoint, rescale)

## Hands-On Demos

### Schema Registry + Kafka Java Client

Location:

`schema-registry-kafka-java-client/`

Main commands:

```bash
cd schema-registry-kafka-java-client
mvn -DskipTests clean package
mvn -q exec:java
```

### Debezium MySQL Source (containerized)

Location:

`debezium-mysql-source-demo/`

Main commands:

```bash
cd debezium-mysql-source-demo
chmod +x scripts/*.sh
./scripts/start-demo.sh
./scripts/insert-demo-records.sh
./scripts/consume-topic.sh
```

### Flink Tutorial (standalone)

Location:

`flink-demo/flink/`

Prerequisite:

- `java` (JDK 21)

Main commands:

```bash
cd flink-demo/flink/flink-training
./gradlew test shadowJar
./gradlew printRunTasks
./gradlew :ride-cleansing:runJavaSolution
# keyed state step
./gradlew :rides-and-fares:runJavaSolution
# altri lab disponibili
./gradlew :hourly-tips:runJavaSolution
./gradlew :long-ride-alerts:runJavaSolution
```

The `flink-training` code is already included in:

`flink-demo/flink/flink-training/`

Included modules in this snapshot:

- `common`
- `ride-cleansing`
- `rides-and-fares`
- `hourly-tips`
- `long-ride-alerts`

Detailed guide for the Flink examples (logic + sources):

`flink-demo/flink/EXAMPLES_GUIDE.md`

### Flink CLI WordCount (local cluster)

Location:

`flink-demo/flink-cli-wordcount/`

Prerequisite:

- `java` (JDK 21+)

Main commands:

```bash
cd flink-demo/flink-cli-wordcount
./run-wordcount.sh
# opzionale: lascia il cluster attivo
KEEP_CLUSTER_RUNNING=true ./run-wordcount.sh
# stop separato
./stop-cluster.sh
```

### Flink CLI Windowing Tutorial (local cluster)

Location:

`flink-demo/flink-cli-windowing/`

Prerequisite:

- `java` (JDK 21+)
- `mvn`

Main commands:

```bash
cd flink-demo/flink-cli-windowing
# attende readiness REST/UI prima di terminare
./start-cluster.sh
# opzionale: timeout readiness
READINESS_TIMEOUT_SEC=90 ./start-cluster.sh
# stop separato cluster
./stop-cluster.sh
# oppure flusso completo end-to-end
# default: run-windowing cancella il job e ferma il cluster a fine esecuzione
./run-windowing.sh
# modalita' count-window
WINDOW_MODE=count ./run-windowing.sh
# lascia job/cluster attivi
KEEP_JOB_RUNNING=true KEEP_CLUSTER_RUNNING=true ./run-windowing.sh
```

CSA variant (use Flink services from course `docker-compose.yml`):

- `flink-demo/flink-cli-windowing/README_CSA.md`

### Flink Operations Playground + Kafka (standalone)

Location:

`flink-demo/flink-operations-kafka/`

Main commands:

```bash
cd flink-demo/flink-operations-kafka
# build + up + readiness check dashboard
./start-playground.sh
# job list via client container
docker compose run --rm --no-deps client flink list
# stop stack
./stop-playground.sh
```

Dashboard default:

- `http://127.0.0.1:18081`

## Fix Tracking

All relevant operational/configuration fixes are documented in:

`FIX.md`
