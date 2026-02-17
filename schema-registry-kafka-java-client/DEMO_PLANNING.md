# Demo Planning - Schema Registry + Kafka Java Client (tmux)

## Obiettivo demo
Mostrare in modo interattivo:
- producer e consumer separati
- serializzazione/deserializzazione Avro con Schema Registry
- osservabilità da terminale (messaggi e metadati schema)

## Durata stimata
- 20-30 minuti

## Prerequisiti
- CSA CE in esecuzione (`docker compose ps`)
- Java 21 + Maven funzionanti
- directory progetto: `schema-registry-kafka-java-client`

## Setup tmux
1. Aprire sessione:
```bash
cd schema-registry-kafka-java-client
tmux new -s sr-demo
```
2. Layout consigliato (4 pannelli):
- `Ctrl+b` poi `"` (split orizzontale)
- `Ctrl+b` poi `%` (split verticale)
- ripetere `%` nel pannello sotto per avere 4 aree

## Ruolo pannelli
- Pannello 1 (alto-sx): Consumer Java
- Pannello 2 (alto-dx): Producer Java
- Pannello 3 (basso-sx): Query Schema Registry via `curl`
- Pannello 4 (basso-dx): comandi Kafka di supporto

## Variabili comuni
Eseguire in pannelli 1 e 2:
```bash
export CSA_BOOTSTRAP_SERVERS=localhost:9092
export CSA_SCHEMA_REGISTRY_URL=http://localhost:7788/api/v1
export CSA_TOPIC=csa.sr.demo.lesson
export CSA_RUN_ID=lesson-001
```

## Flusso demo consigliato

### Fase 1 - Avvio consumer in ascolto
Nel pannello 1:
```bash
export CSA_RUN_ID_FILTER=lesson-001
export CSA_MAX_MESSAGES=20
mvn -q exec:java -Dexec.mainClass=com.cloudera.examples.sr.SchemaRegistryKafkaConsumer
```
Spiegare:
- consumer legge da inizio topic (`earliest`)
- filtro `run_id` per isolare la demo

### Fase 2 - Produzione dati live
Nel pannello 2:
```bash
export CSA_MESSAGE_COUNT=20
export CSA_PRODUCER_INTERVAL_MS=1000
mvn -q exec:java -Dexec.mainClass=com.cloudera.examples.sr.SchemaRegistryKafkaProducer
```
Spiegare:
- ogni messaggio viene serializzato con `KafkaAvroSerializer`
- lo schema viene registrato automaticamente in Schema Registry

### Fase 3 - Ispezione schema registrato
Nel pannello 3:
```bash
curl -s "$CSA_SCHEMA_REGISTRY_URL/schemaregistry/schemas" | jq
```
Individuare il nome schema uguale al topic (`csa.sr.demo.lesson`) e poi:
```bash
curl -s "$CSA_SCHEMA_REGISTRY_URL/schemaregistry/schemas/$CSA_TOPIC/versions" | jq
```
Spiegare:
- versione schema
- contenuto schema Avro registrato

### Fase 4 - Verifica topic e offset
Nel pannello 4:
```bash
docker compose exec kafka kafka-topics.sh --describe --topic csa.sr.demo.lesson --bootstrap-server localhost:9092
```
Spiegare:
- partizioni
- offset avanzati durante il flusso producer/consumer

## Script narrativo (talk track)
1. "Lancio consumer prima del producer per far vedere arrivo eventi live."
2. "Il producer serializza con schema Avro e registra schema se assente."
3. "Dal terminale vediamo i record deserializzati dal consumer."
4. "Interroghiamo Schema Registry e vediamo versione/schema associati al topic."

## Variante rapida (10 minuti)
- Saltare pannello 4
- Tenere solo consumer + producer + query schema

## Future step per demo evoluta
- Aggiungere producer `v2` con campo nuovo (es. `os_type` default)
- mostrare comportamento compatibilità (`BACKWARD`) nel registry
- consumare con reader schema diverso e commentare risultato
- Aggiungere un esempio Kafka Connect **Source** (JDBC Source): inserire righe in una tabella Postgres e mostrare che i record vengono pubblicati nel topic Kafka
