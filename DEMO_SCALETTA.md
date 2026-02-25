# DEMO FLINK - Scalette Ordinate

Tabella operativa della sequenza demo Flink concordata, con obiettivo e riferimenti web del tutorial/materiale sorgente.

| Ordine | Demo | Obiettivo | Riferimenti web tutorial/materiale |
|---|---|---|---|
| 1 | `flink-demo/flink-cli-wordcount/` | Capire ciclo base cluster locale + submit job + output. | - Apache Flink `WordCount` example: https://github.com/apache/flink/blob/master/flink-examples/flink-examples-streaming/src/main/java/org/apache/flink/streaming/examples/wordcount/WordCount.java |
| 2 | `flink-demo/flink-cli-windowing/` | Passare a stream processing con finestre (tumbling/count/time), lifecycle job (run/list/cancel). | - Flink DataStream Windows: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/operators/windows <br> - Flink DataStream API overview: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/overview |
| 3 | `ssb-demo/windowing-sql-demo/` | Stessi concetti di windowing ma in Flink SQL/SSB (tumbling, hopping, cumulative) su stack CSA. | - Cloudera SSB tutorial (CSA CE): https://docs.cloudera.com/csp-ce/latest/getting-started/topics/csp-ce-sa-sql-stream-builder.html#csp-ce-sa-sql-stream-builder |
| 4 | `flink-demo/flink/flink-training/ride-cleansing` | DataStream API “reale” con pipeline piu' strutturata. | - Apache Flink Training repository: https://github.com/apache/flink-training <br> - DataStream API docs: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/overview |
| 5 | `flink-demo/flink/flink-training/rides-and-fares` | Keyed state e join/event correlation. | - Apache Flink Training repository: https://github.com/apache/flink-training <br> - Working with State: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/fault-tolerance/state |
| 6 | `flink-demo/flink/flink-training/hourly-tips` | Aggregazioni temporalmente significative in scenario realistico. | - Apache Flink Training repository: https://github.com/apache/flink-training <br> - Windows (DataStream): https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/operators/windows |
| 7 | `flink-demo/flink/flink-training/long-ride-alerts` | Logica event-time + detection pattern/alerting. | - Apache Flink Training repository: https://github.com/apache/flink-training <br> - ProcessFunction docs: https://nightlies.apache.org/flink/flink-docs-stable/docs/dev/datastream/operators/process_function |
| 8 | `flink-demo/flink-sql/` | Pipeline SQL completa con sink esterni (Elasticsearch/Kibana). | - Tutorial sorgente vendorizzato (repo): https://github.com/thimotyb/flink-sql-demo/tree/v1.11-EN <br> - Articolo Apache Flink SQL demo: https://flink.apache.org/2020/07/28/flink-sql-demo-building-an-end-to-end-streaming-application/ |
| 9 | `flink-demo/flink-operations-kafka/` | Operazioni avanzate (recovery, savepoint, rescaling) dopo che le basi sono solide. | - Flink Playgrounds (sorgente vendorizzata): https://github.com/thimotyb/flink-playgrounds |

## Nota

- L'ordine sopra e' pensato per progressione didattica: basi CLI -> windowing -> SQL su CSA -> DataStream API avanzata -> operazioni production-like.
