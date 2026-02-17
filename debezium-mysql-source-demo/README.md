# Debezium MySQL Source Demo (Containerizzato)

Questa demo crea una istanza MySQL containerizzata, registra un connettore **Debezium MySQL Source** su Kafka Connect CSA CE e mostra la pubblicazione CDC verso topic Kafka.

## Prerequisiti

- Stack CSA CE avviato (`kafka` e `kafka-connect` running)
- Docker + Docker Compose
- Rete Docker dello stack CSA CE disponibile (auto-rilevata da `cloudera-kafka-connect-1`)

## Struttura

- `docker-compose.yml`: MySQL configurato per binlog CDC
- `mysql/init/01_init.sql`: bootstrap DB, tabella e utente Debezium
- `scripts/start-demo.sh`: avvio MySQL + creazione connector
- `scripts/install-mysql-jdbc-driver.sh`: installa il driver MySQL richiesto dal plugin Debezium MySQL su Kafka Connect
- `scripts/insert-demo-records.sh`: insert su tabella `inventory.customers_live`
- `scripts/consume-topic.sh`: lettura eventi CDC dal topic

## Avvio rapido

```bash
cd debezium-mysql-source-demo
chmod +x scripts/*.sh
./scripts/start-demo.sh
```

`start-demo.sh` include automaticamente:
- installazione driver `mysql-connector-java` nel container `cloudera-kafka-connect-1` (se mancante)
- restart di Kafka Connect
- creazione/aggiornamento connector `mysql-source-demo`

Inserimento record demo:

```bash
./scripts/insert-demo-records.sh
```

Consumo topic CDC:

```bash
./scripts/consume-topic.sh
```

Topic atteso:

- `mysqlsrc.inventory.customers_live`

## Note

- Connector name: `mysql-source-demo`
- Connect URL default: `http://localhost:28083`
- MySQL demo esposto su host: `localhost:3307`
- Per aggiornare la config del connector, rieseguire `./scripts/create-mysql-source-connector.sh`
- Se la rete va forzata manualmente: `CSA_DOCKER_NETWORK=<nome_rete> ./scripts/start-demo.sh`

## Pulizia

```bash
docker compose down -v
curl -X DELETE http://localhost:28083/connectors/mysql-source-demo
```
