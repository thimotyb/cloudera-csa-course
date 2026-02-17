# Cloudera CSA Course Workspace

This repository contains material and runnable demos for the CSA (Cloudera Streaming Analytics) course using CSA Community Edition.

## What is in this repo

- CSA local stack (Docker Compose)
- Course docs (requirements, syllabus, installation notes)
- Slides and slide-generation helper
- Hands-on streaming demos (Kafka, Schema Registry, Kafka Connect, Debezium)
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

## Fix Tracking

All relevant operational/configuration fixes are documented in:

`FIX.md`

## Maintenance Rule

Whenever a new change impacts students/users (new demo, new script, changed endpoint, changed setup, known workaround):

1. Update this `README.md`.
2. Add/update the related entry in `FIX.md` if it is a fix/workaround.

