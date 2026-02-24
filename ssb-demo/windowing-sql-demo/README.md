# CSA SSB Demo: Windowing SQL (Tumbling, Hopping, Cumulative)

Demo pronta per lezione usando CSA CE gia' avviato (`docker-compose.yml` della repo).

Questa demo usa gli stessi concetti del summary Flink SQL:

- sorgente `user_behavior`
- watermark su event time
- query window: tumbling, hopping, cumulative

## Prerequisiti

- stack CSA avviato (`./start_csa.sh` o `docker compose up -d`)
- SSB UI raggiungibile: `http://localhost:18121` (`admin/admin`)
- Kafka raggiungibile: `localhost:9094`

## Struttura cartella

- `sql/01_create_user_behavior_source.sql`: sorgente streaming fake
- `sql/02_tumbling_window_select.sql`: query tumbling (interactive)
- `sql/03_hopping_window_select.sql`: query hopping (interactive)
- `sql/04_cumulative_window_select.sql`: query cumulative (interactive)
- `sql/10_create_kafka_sinks.sql`: sink Kafka per risultati finestra
- `sql/11_insert_tumbling_to_kafka.sql`: job continuo tumbling -> Kafka
- `sql/12_insert_hopping_to_kafka.sql`: job continuo hopping -> Kafka
- `sql/13_insert_cumulative_to_kafka.sql`: job continuo cumulative -> Kafka
- `sql/90_cleanup.sql`: cleanup oggetti SQL
- `scripts/create_topics.sh`: crea topic output Kafka
- `scripts/consume_topic.sh`: consuma topic output Kafka

## Flusso demo consigliato (aula)

1. Crea topic output:

```bash
cd ssb-demo/windowing-sql-demo
./scripts/create_topics.sh
```

2. In SSB esegui:

- `sql/01_create_user_behavior_source.sql`

3. Mostra query interactive (una per volta):

- `sql/02_tumbling_window_select.sql`
- `sql/03_hopping_window_select.sql`
- `sql/04_cumulative_window_select.sql`

4. (Opzionale) Esegui job continui con sink Kafka:

- `sql/10_create_kafka_sinks.sql`
- uno o piu' tra:
  - `sql/11_insert_tumbling_to_kafka.sql`
  - `sql/12_insert_hopping_to_kafka.sql`
  - `sql/13_insert_cumulative_to_kafka.sql`

5. Verifica output in terminale:

```bash
./scripts/consume_topic.sh user_behavior_tumbling_out
./scripts/consume_topic.sh user_behavior_hopping_out
./scripts/consume_topic.sh user_behavior_cumulative_out
# opzionale: timeout in ms (default 15000)
./scripts/consume_topic.sh user_behavior_tumbling_out 20 30000
```

Se il job non ha ancora prodotto eventi, il consumer puo' chiudersi con timeout e `0 messages`.

## Note didattiche rapide

- Tumbling: ogni evento va in una sola finestra.
- Hopping: ogni evento puo' andare in piu' finestre sovrapposte.
- Cumulative: finestre progressive, utili per parziali intra-periodo.
