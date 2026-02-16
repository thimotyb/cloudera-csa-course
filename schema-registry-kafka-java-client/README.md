# Schema Registry + Kafka Java Client (CSA CE)

Esempio pronto e compilabile con Maven + Java 21, basato sul capitolo Cloudera:
`Integrating Schema Registry with a Kafka Java client`.

## 1. Avvio CSA
Dal repository principale:

```bash
./start_csa.sh
```

Verifica endpoint:
- Kafka: `localhost:9092`
- Schema Registry: `http://localhost:7788/api/v1`

## 2. Build

```bash
cd schema-registry-kafka-java-client
mvn -DskipTests clean package
```

## 3. Esecuzione

```bash
mvn -q exec:java
```

Oppure con script unico (check prerequisiti + build + run):

```bash
./run-demo.sh
```

Oppure con jar completo:

```bash
java -jar target/schema-registry-kafka-java-client-1.0.0-jar-with-dependencies.jar
```

## 4. Override configurazione (opzionale)

```bash
export CSA_BOOTSTRAP_SERVERS=localhost:9092
export CSA_SCHEMA_REGISTRY_URL=http://localhost:7788/api/v1
export CSA_TOPIC=csa.sr.demo
export CSA_MESSAGE_COUNT=5
mvn -q exec:java
```

## Esecuzione separata Producer / Consumer (tmux)
Entry point disponibili:
- Producer: `com.cloudera.examples.sr.SchemaRegistryKafkaProducer`
- Consumer: `com.cloudera.examples.sr.SchemaRegistryKafkaConsumer`

### Sessione tmux consigliata

```bash
cd schema-registry-kafka-java-client
tmux new -s sr-demo
```

Nel primo pannello (Consumer):

```bash
export CSA_TOPIC=csa.sr.demo.lesson
export CSA_RUN_ID_FILTER=lesson-001
mvn -q exec:java -Dexec.mainClass=com.cloudera.examples.sr.SchemaRegistryKafkaConsumer
```

Apri secondo pannello con `Ctrl+b` poi `"` e lancia Producer:

```bash
export CSA_TOPIC=csa.sr.demo.lesson
export CSA_RUN_ID=lesson-001
export CSA_MESSAGE_COUNT=20
export CSA_PRODUCER_INTERVAL_MS=1000
mvn -q exec:java -Dexec.mainClass=com.cloudera.examples.sr.SchemaRegistryKafkaProducer
```

Output atteso:
- Producer stampa i record inviati
- Consumer stampa i record deserializzati ricevuti in tempo reale

## Cosa dimostra
- Configurazione producer/consumer Kafka Java
- Uso serializer/deserializer Cloudera Schema Registry
- Produzione e consumo record Avro (`GenericRecord`)
- Lettura header schema version (`key.schema.version.id`, `value.schema.version.id`)

## Test di non regressione
Esegue un round-trip reale su CSA:
- produce un messaggio con **schema v1** (`SensorReadingV1`)
- consuma dallo stesso topic
- verifica deserializzazione dei campi e presenza header `value.schema.version.id`

```bash
mvn -Dtest=SchemaRegistryKafkaClientRegressionTest test
```
