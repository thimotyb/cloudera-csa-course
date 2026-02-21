# FIX Log

Registro delle fix applicate nel progetto.  
Aggiornare questo file ogni volta che viene risolto un problema operativo o di configurazione.

## 2026-02-17 - CSA Stack: topic monitoring vuoto in SMM

- **Sintomo**
  - Nella finestra di monitoring topic non comparivano dati.
- **Causa**
  - Uso endpoint UI/API non corretto e/o metriche non disponibili a SMM.
- **Fix**
  - Usare la UI SMM su `http://localhost:9991` (non `8585`, che e' API backend).
  - Verificare che in `docker-compose.yml` siano esposte le metriche Kafka:
    - `24042:24042` (Kafka metrics endpoint)
    - `9100:9100` (system metrics)
  - Tenere attivo `prometheus` con mount:
    - `./prometheus.yml:/opt/prometheus/prometheus.yml`
  - Per produzione messaggi da host, usare `localhost:9094`.
- **Verifica**
  - `http://localhost:9090/api/v1/targets?state=active`: target `kafka:24042` in stato `up`.
  - `http://localhost:8585/api/v2/admin/metrics/aggregated/topics?...`: metriche topic presenti.

## 2026-02-17 - JDBC Sink (Stateless NiFi): bootstrap connector fallito

- **Sintomo**
  - Errori tipo:
    - `Failed to bootstrap Stateless NiFi Engine`
    - timeout download `nifi-standard-nar`
    - `Working Directory ... could not be created`
- **Causa**
  - URL repository NAR non ottimale e path runtime non scrivibile.
- **Fix**
  - Nel JSON connector:
    - `nexus.url`: `https://repository.cloudera.com/repository/repo/`
    - `extensions.directory`: `/tmp/nifi-stateless-extensions`
    - `working.directory`: `/tmp/nifi-stateless-working`
  - Se si usa `/data/...`, creare cartelle con owner utente `kafka` (`uid 3000`) prima del restart task.
- **Verifica**
  - Connector `sink-demo` in stato `RUNNING` con task `RUNNING`.
  - Inserimento/consumo dati completato e scrittura DB avvenuta.

## 2026-02-17 - Debezium MySQL Source: creazione connector HTTP 500

- **Sintomo**
  - Creazione `io.debezium.connector.mysql.MySqlConnector` fallisce con HTTP 500.
- **Causa**
  - Driver JDBC MySQL mancante nel classpath plugin Debezium (`NoClassDefFoundError: com/mysql/cj/jdbc/Driver`).
- **Fix**
  - Installare `mysql-connector-java-8.0.27.jar` in:
    - `/opt/connect/plugin/libs/debezium-connector-mysql/mysql-connector-java.jar`
  - Riavviare `cloudera-kafka-connect-1`.
  - Automatizzato in:
    - `debezium-mysql-source-demo/scripts/install-mysql-jdbc-driver.sh`
- **Verifica**
  - Connector `mysql-source-demo` creato.
  - Eventi CDC pubblicati su topic `mysqlsrc.inventory.customers_live`.

## 2026-02-20 - Flink windowing tutorial legacy non compatibile con Java 21

- **Sintomo**
  - Il tutorial storico di windowing (`flink-tutorials` con Flink `1.9.0`) richiede stack legacy (Java 8/11, dipendenze datate) e non e' adatto all'ambiente Java 21 del corso.
- **Causa**
  - Versioni Flink/plug-in build obsolete rispetto al runtime moderno.
- **Fix/Workaround**
  - Aggiunta demo aggiornata e vendorizzata in:
    - `flink-demo/flink-cli-windowing/`
  - Aggiornamento a:
    - Flink `1.20.1`
    - build Maven Java 21
  - Script operativo CLI end-to-end:
    - `run-windowing.sh` (start/run/list/cancel/stop)
    - `stop-cluster.sh`
- **Verifica**
  - Esecuzione da `flink-demo/flink-cli-windowing`:
    - `./run-windowing.sh`
  - Job visibile con `flink list` e cancellabile via `flink cancel`.

## 2026-02-21 - Flink CLI windowing: UI non raggiungibile su porta 8081

- **Sintomo**
  - Cluster avviato ma dashboard non raggiungibile da browser remoto/host diverso (porta `8081` non risponde).
- **Causa**
  - Configurazione di default Flink bindata su `localhost` (`rest.bind-address: localhost` e bind host locali).
- **Fix/Workaround**
  - Aggiunto script:
    - `flink-demo/flink-cli-windowing/start-cluster.sh`
  - Lo script imposta automaticamente su `config.yaml`:
    - `jobmanager.bind-host`
    - `taskmanager.bind-host`
    - `rest.bind-address`
  - Default: `FLINK_BIND_ADDRESS=0.0.0.0` (override possibile via env).
  - Aggiunto readiness check nello start script:
    - polling su `http://127.0.0.1:8081/overview` con timeout configurabile
    - variabili: `READINESS_TIMEOUT_SEC`, `READINESS_INTERVAL_SEC`, `FLINK_REST_HOST`, `FLINK_REST_PORT`
- **Verifica**
  - Avvio:
    - `cd flink-demo/flink-cli-windowing`
    - `./start-cluster.sh`
  - Controllo porta:
    - `ss -ltnp | grep 8081`
  - Dashboard raggiungibile su `http://127.0.0.1:8081` (e su IP host se consentito da rete/firewall).

## 2026-02-21 - Flink CLI windowing su CSA: incompatibilita' Java/Flink e finestra time

- **Sintomo**
  - Submit del jar su `flink-jobmanager` CSA fallisce con:
    - `UnsupportedClassVersionError` (class file version 65 vs runtime Java 8)
  - Dopo ricompilazione, `--mode time` puo' fallire con errore su timestamp `Long.MIN_VALUE`.
- **Causa**
  - Runtime CSA Flink (`1.15.1-csadh1.9.0.0`) gira su Java 8.
  - L'esempio usava path windowing che in questo contesto richiede timestamp/watermark event-time.
- **Fix/Workaround**
  - Compilazione per CSA:
    - `-Dmaven.compiler.release=8 -Dflink.version=1.15.1`
  - Aggiornato `TumblingWindowExample` per usare esplicitamente processing-time:
    - `windowAll(TumblingProcessingTimeWindows.of(...))`
  - Aggiunta guida operativa CSA:
    - `flink-demo/flink-cli-windowing/README_CSA.md`
- **Verifica**
  - Build jar CSA completata.
  - Submit job `--mode time` su CSA in stato `RUNNING`.
  - `flink list -a` e `flink cancel <JOB_ID>` operativi via `docker compose exec flink-jobmanager`.

## 2026-02-21 - Flink Operations Playground: tag Kafka non piu' disponibile

- **Sintomo**
  - Avvio playground fallisce durante pull con errore:
    - `bitnami/kafka:3.9.0: not found`
- **Causa**
  - Il tag `bitnami/kafka:3.9.0` non e' piu' pubblicato.
- **Fix/Workaround**
  - Aggiornata la demo vendorizzata `flink-demo/flink-operations-kafka/`:
    - sostituita immagine Kafka con `confluentinc/cp-kafka:7.7.1`
    - configurazione single-node KRaft aggiornata via variabili ambiente
  - Migliorata operativita' script:
    - `start-playground.sh` usa `docker compose up -d --remove-orphans`
    - `stop-playground.sh` usa `docker compose down --remove-orphans`
- **Verifica**
  - `./start-playground.sh` completa con dashboard pronta su `http://127.0.0.1:18081`.
  - Job `Click Event Count` in stato `RUNNING`.
  - Topic Kafka `input`/`output` presenti e consumabili da `docker compose exec kafka kafka-console-consumer`.
