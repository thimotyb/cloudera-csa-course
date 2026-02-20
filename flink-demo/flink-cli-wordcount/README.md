# Flink CLI Demo - Local Cluster + WordCount

Questa demo mostra come lanciare Flink da linea di comando su cluster locale standalone e avviare l'esempio `WordCount`.

## Obiettivo didattico

- avvio cluster locale Flink con script binari
- esecuzione di un job precompilato (`WordCount.jar`)
- lettura rapida log TaskExecutor
- shutdown cluster

## Prerequisiti

- `java` (JDK 21+)
- `curl`
- `tar`

## Avvio rapido (script consigliato)

```bash
cd flink-demo/flink-cli-wordcount
./run-wordcount.sh
```

Cosa fa lo script:

1. verifica JDK 21+
2. scarica Flink (default `1.20.1`) se non presente
3. estrae il pacchetto in `./.runtime/`
4. avvia cluster locale (`start-cluster.sh`)
5. esegue `examples/streaming/WordCount.jar`
6. mostra tail del log TaskExecutor
7. ferma il cluster (a meno che `KEEP_CLUSTER_RUNNING=true`)

Dashboard locale:

- `http://localhost:8081`

## Comandi manuali equivalenti

```bash
cd flink-demo/flink-cli-wordcount
KEEP_CLUSTER_RUNNING=true ./run-wordcount.sh
```

Oppure manuale completo (dopo il primo download):

```bash
cd flink-demo/flink-cli-wordcount/.runtime/flink-1.20.1
./bin/start-cluster.sh
./bin/flink run examples/streaming/WordCount.jar
tail log/flink-*-taskexecutor-*.out
./bin/stop-cluster.sh
```

## Variabili utili

- `FLINK_VERSION` (default: `1.20.1`)
- `SCALA_SUFFIX` (default: `2.12`)
- `WORKDIR` (default: `./.runtime`)
- `FLINK_HOME` (override path estratto)
- `KEEP_CLUSTER_RUNNING=true` (non ferma il cluster a fine script)
- `TAIL_LINES` (default: `120`)

## Stop cluster separato

Se hai lasciato il cluster attivo:

```bash
cd flink-demo/flink-cli-wordcount
./stop-cluster.sh
```

## Riferimento esempio WordCount

- https://github.com/apache/flink/blob/master/flink-examples/flink-examples-streaming/src/main/java/org/apache/flink/streaming/examples/wordcount/WordCount.java
