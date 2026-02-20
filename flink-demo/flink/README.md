# Flink Demo Collection

Questa cartella raccoglie esempi Flink del tutorial base da usare nel corso CSA.

Prerequisito runtime: `java` (JDK 21).

## Stato esempi

- `ride-cleansing`: standalone, pronto all'uso
- `rides-and-fares` (keyed state): step successivo
- `hourly-tips`: aggregazioni stateful per ora/driver
- `long-ride-alerts`: rilevamento corse lunghe con stato e timer

## Struttura

- `flink-training/`: snapshot locale del training (nessun clone richiesto a runtime)
- moduli inclusi nello snapshot:
  - `common`
  - `ride-cleansing`
  - `rides-and-fares`
  - `hourly-tips`
  - `long-ride-alerts`
- `EXAMPLES_GUIDE.md`: spiegazione dei lab e delle source usate

## Comandi rapidi

```bash
cd flink-demo/flink/flink-training
./gradlew test shadowJar
./gradlew printRunTasks
./gradlew :ride-cleansing:runJavaSolution
./gradlew :rides-and-fares:runJavaSolution
./gradlew :hourly-tips:runJavaSolution
./gradlew :long-ride-alerts:runJavaSolution
```
