# Windowing Tutorial su Flink CSA (CLI manuale)

Questa guida ripete i passi manuali del tutorial windowing, ma usando il Flink del cluster CSA nel `docker-compose.yml` del corso.

## Prerequisiti

- Docker + Docker Compose
- JDK 21 locale (per Maven)
- Maven

Nota runtime CSA:

- Flink CSA in questo ambiente: `1.15.1-csadh1.9.0.0`
- JVM runtime nel container: Java 8
- per questo il job va compilato con `-Dmaven.compiler.release=8` e `-Dflink.version=1.15.1`

## 1) Avvia Flink CSA

Dal root del repository (`cloudera/`):

```bash
docker compose up -d flink-jobmanager flink-taskmanager
docker compose ps flink-jobmanager flink-taskmanager
```

Dashboard:

- `http://127.0.0.1:8081`

## 2) Build del job windowing (compatibile CSA)

```bash
cd flink-demo/flink-cli-windowing
mvn -f windowing-job/pom.xml \
  -DskipTests \
  -Dmaven.compiler.release=8 \
  -Dflink.version=1.15.1 \
  clean package
```

## 3) Submit del job da CLI (su JobManager CSA)

Torna al root del repository e copia il jar nel container:

```bash
cd ../..
docker compose cp flink-demo/flink-cli-windowing/windowing-job/target/windowing-job-1.0.0.jar flink-jobmanager:/tmp/windowing-job.jar
```

Avvio esempio tumbling time window:

```bash
docker compose exec -T flink-jobmanager /opt/flink/bin/flink run -d \
  -c org.pd.streaming.window.example.TumblingWindowExample \
  /tmp/windowing-job.jar \
  --mode time --time-window-sec 5 --source-period-ms 1000
```

Alternativa count window:

```bash
docker compose exec -T flink-jobmanager /opt/flink/bin/flink run -d \
  -c org.pd.streaming.window.example.TumblingWindowExample \
  /tmp/windowing-job.jar \
  --mode count --count-window-size 4 --source-period-ms 1000
```

## 4) Verifica e stop del job

Lista job:

```bash
docker compose exec -T flink-jobmanager /opt/flink/bin/flink list -a
```

Cancella job:

```bash
docker compose exec -T flink-jobmanager /opt/flink/bin/flink cancel <JOB_ID>
```

## 5) Stop cluster Flink CSA

```bash
docker compose stop flink-taskmanager flink-jobmanager
```

