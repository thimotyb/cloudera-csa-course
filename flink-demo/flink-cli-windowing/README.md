# Flink CLI Demo - Windowing Tutorial (Java 21)

Questa demo mostra come eseguire da CLI un job di windowing Flink, partendo da una versione modernizzata del tutorial `TumblingWindowExample`.

## Obiettivo didattico

- avvio cluster locale Flink standalone
- build locale del job tutorial con Maven (Java 21)
- submit job da CLI (`flink run`)
- verifica job (`flink list`) e cancellazione (`flink cancel`)

## Cosa e' stato aggiornato rispetto agli appunti originali

- Flink aggiornato da `1.9.0` a `1.20.1`
- codice tutorial vendorizzato in questa cartella (non serve `git clone` esterno)
- build su Java 21
- script automatizzati per start/run/list/cancel/stop

## Struttura

- `windowing-job/`: progetto Maven con classe principale `org.pd.streaming.window.example.TumblingWindowExample`
- `run-windowing.sh`: script end-to-end
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

## Avvio rapido

```bash
cd flink-demo/flink-cli-windowing
./run-windowing.sh
```

Cosa fa lo script:

1. verifica JDK 21+
2. scarica/estrae Flink 1.20.1 in `./.runtime/` (se assente)
3. compila il job Maven in `windowing-job/target/`
4. avvia cluster locale (`start-cluster.sh`)
5. submit job in detached mode
6. attende alcuni secondi e mostra `flink list`
7. mostra tail del log TaskExecutor
8. cancella il job e ferma il cluster

Dashboard locale:

- `http://localhost:8081`

## Variabili utili

- `WINDOW_MODE` (default: `time`; valori: `time|count`)
- `TIME_WINDOW_SEC` (default: `5`)
- `COUNT_WINDOW_SIZE` (default: `4`)
- `SOURCE_PERIOD_MS` (default: `1000`)
- `WAIT_SECONDS` (default: `10`)
- `KEEP_JOB_RUNNING=true` (non cancella il job)
- `KEEP_CLUSTER_RUNNING=true` (non ferma il cluster)
- `FLINK_VERSION` (default: `1.20.1`)
- `SCALA_SUFFIX` (default: `2.12`)

## Esecuzione manuale equivalente

```bash
cd flink-demo/flink-cli-windowing
mvn -f windowing-job/pom.xml -DskipTests clean package

.runtime/flink-1.20.1/bin/start-cluster.sh
.runtime/flink-1.20.1/bin/flink run -d \
  -c org.pd.streaming.window.example.TumblingWindowExample \
  windowing-job/target/windowing-job-1.0.0.jar \
  --mode time --time-window-sec 5 --source-period-ms 1000

.runtime/flink-1.20.1/bin/flink list
.runtime/flink-1.20.1/bin/flink cancel <JOB_ID>
.runtime/flink-1.20.1/bin/stop-cluster.sh
```
