# Flink CLI Demo - Windowing Tutorial (Java 21)

Questa demo mostra come eseguire da CLI un job di windowing Flink (`TumblingWindowExample`).

## Obiettivo didattico

- avvio cluster locale Flink standalone
- build locale del job tutorial con Maven (Java 21)
- submit job da CLI (`flink run`)
- verifica job (`flink list`) e cancellazione (`flink cancel`)

## Struttura

- `windowing-job/`: progetto Maven con classe principale `org.pd.streaming.window.example.TumblingWindowExample`
- `run-windowing.sh`: script end-to-end
- `start-cluster.sh`: start cluster con bind rete configurabile (default `0.0.0.0`)
- `stop-cluster.sh`: stop cluster separato

## Source usata dal tutorial

Il job usa una source custom interna (`IntegerGenerator`) che emette interi incrementali (`1,2,3,...`) a intervallo regolare (`--source-period-ms`, default `1000`).

Modalita' disponibili:

- `--mode time`: tumbling window a tempo (`--time-window-sec`, default `5`)
- `--mode count`: count window (`--count-window-size`, default `4`)

## Prerequisiti

- `java` (JDK 21+)
- `mvn`
- `curl`
- `tar`

## Demo live (step separati)

### 0) Preparazione (una tantum)

```bash
cd flink-demo/flink-cli-windowing
FLINK_VERSION=1.20.1
SCALA_SUFFIX=2.12
FLINK_TGZ="flink-${FLINK_VERSION}-bin-scala_${SCALA_SUFFIX}.tgz"

mkdir -p .runtime
test -f ".runtime/${FLINK_TGZ}" || curl -fL "https://archive.apache.org/dist/flink/flink-${FLINK_VERSION}/${FLINK_TGZ}" -o ".runtime/${FLINK_TGZ}"
test -d ".runtime/flink-${FLINK_VERSION}" || tar -xf ".runtime/${FLINK_TGZ}" -C .runtime

mvn -f windowing-job/pom.xml -DskipTests clean package
```

### 1) Avvio cluster

```bash
./start-cluster.sh
```

Dashboard:

- `http://127.0.0.1:8081`

Nota:

- di default lo script espone la REST/UI su tutte le interfacce (`FLINK_BIND_ADDRESS=0.0.0.0`)
- per limitare al solo localhost: `FLINK_BIND_ADDRESS=127.0.0.1 ./start-cluster.sh`

### 2) Avvio job (solo job)

```bash
.runtime/flink-1.20.1/bin/flink run -d \
  -c org.pd.streaming.window.example.TumblingWindowExample \
  windowing-job/target/windowing-job-1.0.0.jar \
  --mode time --time-window-sec 5 --source-period-ms 1000
```

Comandi utili durante la demo:

```bash
.runtime/flink-1.20.1/bin/flink list
.runtime/flink-1.20.1/bin/flink cancel <JOB_ID>
```

### 3) Stop cluster

```bash
.runtime/flink-1.20.1/bin/stop-cluster.sh
```

## Avvio rapido (script unico)

```bash
cd flink-demo/flink-cli-windowing
./run-windowing.sh
```

## Variabili utili

- `FLINK_BIND_ADDRESS` (default: `0.0.0.0`; usata da `start-cluster.sh` e `run-windowing.sh`)
- `WINDOW_MODE` (default: `time`; valori: `time|count`)
- `TIME_WINDOW_SEC` (default: `5`)
- `COUNT_WINDOW_SIZE` (default: `4`)
- `SOURCE_PERIOD_MS` (default: `1000`)
- `WAIT_SECONDS` (default: `10`)
- `KEEP_JOB_RUNNING=true` (non cancella il job)
- `KEEP_CLUSTER_RUNNING=true` (non ferma il cluster)
- `FLINK_VERSION` (default: `1.20.1`)
- `SCALA_SUFFIX` (default: `2.12`)
