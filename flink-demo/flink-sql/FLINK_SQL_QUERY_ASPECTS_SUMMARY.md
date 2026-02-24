# Flink SQL: Riassunto Aspetti Principali delle Query

Documento rapido da usare durante la lezione CSA.

## 1) Modello mentale corretto

- In Flink SQL stai interrogando **stream continui**, non tabelle statiche.
- Le tabelle sono **dynamic tables**: il risultato cambia nel tempo.
- Una query tipica ha questo flusso:
  - `CREATE TABLE` sorgente
  - `CREATE TABLE` destinazione
  - `INSERT INTO ... SELECT ...` trasformazione continua

## 2) Definizione sorgenti e sink (DDL)

La query parte sempre da una definizione tabellare con connector e formato.

```sql
CREATE TABLE user_behavior (
    user_id BIGINT,
    item_id BIGINT,
    category_id BIGINT,
    behavior STRING,
    ts TIMESTAMP(3),
    proctime AS PROCTIME(),
    WATERMARK FOR ts AS ts - INTERVAL '5' SECOND
) WITH (
    'connector' = 'kafka',
    'topic' = 'user_behavior',
    'properties.bootstrap.servers' = 'kafka:9094',
    'format' = 'json'
);
```

Punti chiave:

- `connector`: dove leggo/scrivo (Kafka, Elasticsearch, JDBC, ecc.).
- `format`: come serializzo/deserializzo (`json`, `avro`, ...).
- Colonne calcolate: utili per tempo di processamento (`PROCTIME`).

Riferimenti Flink docs:

- CREATE TABLE (DDL): https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/create/
- Table connectors overview: https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/table/overview/
- Kafka SQL connector: https://nightlies.apache.org/flink/flink-docs-stable/docs/connectors/table/kafka/

## 3) Tempo evento, watermark e lateness

Per query robuste su stream:

- usa una colonna di **event time** (`ts` nell'esempio),
- definisci la **watermark** per gestire dati in ritardo.

Esempio:

- `WATERMARK FOR ts AS ts - INTERVAL '5' SECOND`
- significa: tollero fino a 5 secondi di ritardo rispetto a `ts`.

Riferimenti Flink docs:

- Time attributes (event/proctime): https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/concepts/time_attributes/
- Watermark: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/concepts/time_attributes/#watermark

## 4) Tipi principali di query che puoi fare

Riferimenti Flink docs:

- SELECT: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/select/
- Joins (incl. interval/temporal): https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/joins/
- Deduplication: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/deduplication/
- Top-N: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/topn/
- Windowing TVF: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/window-tvf/
- Window Aggregation: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/window-agg/
- Window Top-N: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/window-topn/
- Window Deduplication: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/window-deduplication/

### 4.1 Proiezione e filtro

```sql
SELECT user_id, behavior, ts
FROM user_behavior
WHERE behavior = 'buy';
```

Uso: pulizia e selezione eventi rilevanti.

### 4.2 Aggregazioni con finestre

Differenza rapida tra i tre tipi:

| Tipo finestra | Come funziona | Quante finestre per evento | Caso tipico |
|---|---|---|---|
| Tumbling | Finestre fisse, adiacenti, non sovrapposte | 1 | KPI periodici (es. conteggio orario) |
| Hopping | Finestre con durata fissa ma che scorrono a passo piu' piccolo (sovrapposte) | >1 | Sliding analytics (ultimi N minuti, aggiornati spesso) |
| Cumulative | Finestre progressive che crescono da uno start comune fino a un massimo | >1 (progressive) | Report incrementale intra-periodo |

#### Tumbling window

- Definizione: blocchi temporali consecutivi, senza overlap.
- Esempio concettuale: con finestra `10 minuti`, un evento alle `10:07` entra solo in `[10:00, 10:10)`.
- Quando usarla: quando vuoi un valore unico per periodo (es. "totale acquisti ogni ora").

Esempio SQL:

```sql
SELECT
  HOUR(TUMBLE_START(ts, INTERVAL '1' HOUR)) AS hour_of_day,
  COUNT(*) AS buy_cnt
FROM user_behavior
WHERE behavior = 'buy'
GROUP BY TUMBLE(ts, INTERVAL '1' HOUR);
```

#### Hopping window

- Definizione: finestre sovrapposte, con `slide` piu' piccolo della `size`.
- Esempio concettuale: con `size=10 minuti` e `slide=5 minuti`, un evento alle `10:07` entra in:
  - `[10:00, 10:10)`
  - `[10:05, 10:15)`
- Quando usarla: monitoraggio "rolling" (es. metriche su ultima ora aggiornate ogni 5 minuti).

Esempio SQL:

```sql
SELECT
  window_start,
  window_end,
  COUNT(*) AS cnt
FROM TABLE(
  HOP(TABLE user_behavior, DESCRIPTOR(ts), INTERVAL '5' MINUTE, INTERVAL '1' HOUR)
)
GROUP BY window_start, window_end;
```

#### Cumulative window

- Definizione: una famiglia di finestre progressive che partono uguali e aumentano a step.
- Esempio concettuale: con `step=10 minuti` e `max=1 ora`, per un evento alle `10:07` puoi avere output progressivi:
  - `[10:00, 10:10)`
  - `[10:00, 10:20)`
  - `[10:00, 10:30)`
  - ...
  - `[10:00, 11:00)`
- Quando usarla: quando vuoi vedere il parziale che cresce nel tempo dentro la stessa ora/giornata.

Esempio SQL:

```sql
SELECT
  window_start,
  window_end,
  COUNT(*) AS cnt
FROM TABLE(
  CUMULATE(TABLE user_behavior, DESCRIPTOR(ts), INTERVAL '10' MINUTE, INTERVAL '1' HOUR)
)
GROUP BY window_start, window_end;
```

Regola pratica da spiegare in aula:

- Tumbling: "una finestra sola per evento".
- Hopping: "lo stesso evento puo' contribuire a piu' finestre sovrapposte".
- Cumulative: "lo stesso evento compare nei parziali progressivi fino al limite massimo".

### 4.3 Join tra stream

- **Regular/interval join**: correli due stream su chiavi e tempo.
- **Temporal join**: arricchisci stream con tabella dimensionale versionata nel tempo.

Esempio (interval join, schema semplificato):

```sql
SELECT o.user_id, o.order_id, c.campaign_id
FROM orders o
JOIN clicks c
ON o.user_id = c.user_id
AND c.ts BETWEEN o.ts - INTERVAL '10' MINUTE AND o.ts;
```

### 4.4 Deduplica e Top-N

Pattern tipico con `ROW_NUMBER()`:

```sql
SELECT *
FROM (
  SELECT *,
         ROW_NUMBER() OVER (PARTITION BY user_id ORDER BY ts DESC) AS rn
  FROM user_behavior
)
WHERE rn = 1;
```

Uso: tenere l'ultimo evento per chiave.

## 5) Semantica del risultato (Append / Update / Retract)

Non tutte le query producono solo righe nuove:

- Query semplici possono essere **append-only**.
- Aggregazioni/join possono produrre **update/retract**.

Implicazione pratica:

- il sink deve supportare il tipo di changelog prodotto.
- con sink upsert serve tipicamente una chiave primaria logica.

Riferimenti Flink docs:

- Dynamic Tables (changelog, append/update): https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/concepts/dynamic_tables/
- Table to Stream Conversion (append/retract): https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/concepts/dynamic_tables/#table-to-stream-conversion

## 6) Esecuzione in Flink SQL

Query continua tipica:

```sql
INSERT INTO buy_cnt_per_hour
SELECT HOUR(TUMBLE_START(ts, INTERVAL '1' HOUR)), COUNT(*)
FROM user_behavior
WHERE behavior = 'buy'
GROUP BY TUMBLE(ts, INTERVAL '1' HOUR);
```

Nota aula: `INSERT INTO ... SELECT ...` avvia un job streaming che resta attivo finche' non lo fermi.

Riferimenti Flink docs:

- INSERT statement: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/insert/
- SQL Client: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sqlclient/

## 7) Errori comuni da spiegare agli studenti

- Mancanza watermark: finestre su event time non corrette o incomplete.
- Tipo timestamp errato (`STRING` invece di `TIMESTAMP`): funzioni tempo non applicabili.
- Connector/sink incompatibile col changelog: job fallisce a runtime.
- Topic/schema non coerenti col formato dichiarato (`json`, `avro`): parse error.
- Query senza filtro/window su stream ad alto volume: crescita stato e latenza.

## 8) Mini scaletta parlata (2 minuti)

- "In Flink SQL modelliamo stream come tabelle dinamiche."
- "Definiamo source/sink con `CREATE TABLE` e poi trasformiamo con `INSERT INTO ... SELECT`."
- "La parte critica e' il tempo: event time + watermark."
- "Le query piu' usate sono filtro, aggregazioni su finestre, join e deduplica."
- "Infine controlliamo sempre il tipo di output (append/update) e la compatibilita' del sink."

## 9) Risorse ufficiali Flink (Window SQL)

- Windowing TVF:
  - https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/window-tvf/
- Window Aggregation:
  - https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/window-agg/
- Window Top-N:
  - https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/window-topn/
- Window Deduplication:
  - https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/table/sql/queries/window-deduplication/
