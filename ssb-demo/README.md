# SSB Demo - Query `orders` con connector Faker

Questa demo spiega la query del tutorial che crea una tabella streaming `orders` in SQL Stream Builder (SSB) usando il connector `faker`.

## Query del tutorial

```sql
DROP TABLE IF EXISTS orders;

CREATE TABLE orders (
    order_id INTEGER,
    city STRING,
    street_address STRING,
    amount INTEGER,
    order_time TIMESTAMP(3),
    order_status STRING,
    WATERMARK FOR `order_time` AS order_time - INTERVAL '15' SECOND
) WITH (
    'connector' = 'faker',
    'rows-per-second' = '1',
    'fields.order_id.expression' = '#{number.numberBetween ''0'',''99999999''}',
    'fields.city.expression' = '#{Address.city}',
    'fields.street_address.expression' = '#{Address.street_address}',
    'fields.amount.expression' = '#{number.numberBetween ''0'',''100''}',
    'fields.order_time.expression' = '#{date.past ''15'',''SECONDS''}',
    'fields.order_status.expression' = '#{regexify ''(RECEIVED|PREPARING|DELIVERING|DELIVERED|CANCELED){1}''}'
);
```

## Cosa fa, in breve

- Rimuove la tabella `orders` se esiste gia' (`DROP TABLE IF EXISTS`).
- Crea una nuova tabella streaming che genera eventi finti (fake) senza sorgenti esterne.
- Ogni riga e' un ordine con id, citta', indirizzo, importo, timestamp e stato.

## Spiegazione riga per riga

### `DROP TABLE IF EXISTS orders;`

- Evita errore se la tabella era gia' stata creata in una esecuzione precedente.

### Definizione colonne

- `order_id INTEGER`: identificativo ordine.
- `city STRING`: citta' dell'ordine.
- `street_address STRING`: indirizzo completo.
- `amount INTEGER`: importo.
- `order_time TIMESTAMP(3)`: tempo evento con millisecondi.
- `order_status STRING`: stato ordine.

### Watermark

`WATERMARK FOR order_time AS order_time - INTERVAL '15' SECOND`

- Dice a Flink/SSB come gestire il tempo evento.
- Considera in ritardo gli eventi che arrivano oltre 15 secondi rispetto a `order_time`.
- Serve per finestre/event-time query affidabili.

### Proprieta' `WITH (...)`

- `'connector' = 'faker'`:
  - usa un generatore di dati fake.
- `'rows-per-second' = '1'`:
  - produce 1 riga al secondo.

#### Espressioni per campo

- `fields.order_id.expression`:
  - numero casuale tra 0 e 99.999.999.
- `fields.city.expression`:
  - citta' fake.
- `fields.street_address.expression`:
  - indirizzo fake.
- `fields.amount.expression`:
  - importo casuale tra 0 e 100.
- `fields.order_time.expression`:
  - timestamp nel passato (entro 15 secondi).
- `fields.order_status.expression`:
  - uno stato tra:
    - `RECEIVED`
    - `PREPARING`
    - `DELIVERING`
    - `DELIVERED`
    - `CANCELED`

## Come testarla in SSB

1. Apri SSB.
2. Esegui il DDL sopra.
3. Verifica con:

```sql
SELECT * FROM orders;
```

Vedrai un flusso continuo di record fake.

## Nota didattica

Questa tabella e' utile per esercizi su:

- filtri e aggregazioni in tempo reale
- windowing (tumbling/sliding/session)
- gestione event-time e watermark

## Demo correlata (windowing completo)

Per una demo pronta aula con tumbling/hopping/cumulative e sink Kafka:

`ssb-demo/windowing-sql-demo/README.md`
