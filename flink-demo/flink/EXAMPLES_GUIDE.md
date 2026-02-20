# Flink Examples Guide

Questa guida riassume i principali lab inclusi nello snapshot vendorizzato di
`flink-training`.

Esempi coperti:

- `ride-cleansing`
- `rides-and-fares`
- `hourly-tips`
- `long-ride-alerts`

Percorso codice:

- `flink-demo/flink/flink-training/`

## 1) Ride Cleansing

Obiettivo:

- filtrare lo stream `TaxiRide`
- tenere solo le corse che partono e finiscono dentro NYC

Implementazione di riferimento:

- `flink-training/ride-cleansing/src/solution/java/org/apache/flink/training/solutions/ridecleansing/RideCleansingSolution.java`

Passi logici:

1. crea `DataStream<TaxiRide>` da `TaxiRideGenerator`
2. applica `filter` con `GeoUtils.isInNYC(...)` su coordinate start/end
3. stampa i record validi su sink

Regola di filtro:

- `startLon/startLat` in NYC
- `endLon/endLat` in NYC

## 2) Rides and Fares

Obiettivo:

- fare enrichment/join tra stream `TaxiRide` (solo eventi START) e stream `TaxiFare`
- produrre `RideAndFare` per ogni `rideId`

Implementazione di riferimento:

- `flink-training/rides-and-fares/src/solution/java/org/apache/flink/training/solutions/ridesandfares/RidesAndFaresSolution.java`

Passi logici:

1. stream rides: `TaxiRideGenerator` + filtro `ride.isStart`
2. stream fares: `TaxiFareGenerator`
3. `keyBy(rideId)` su entrambi
4. `connect(...).flatMap(new EnrichmentFunction())`
5. in `EnrichmentFunction`:
   - `ValueState<TaxiRide> rideState`
   - `ValueState<TaxiFare> fareState`
   - se arriva la coppia, emette `new RideAndFare(ride, fare)`
   - pulisce lo stato usato

Dettaglio `flatMap1` e `flatMap2` nella `RichCoFlatMapFunction`:

- `flatMap1(TaxiRide ride, Collector<RideAndFare> out)` gestisce eventi dal primo stream (`TaxiRide`):
  - legge `fareState`
  - se la fare corrispondente e' gia' presente: emette `RideAndFare` e fa `fareState.clear()`
  - altrimenti salva la ride in `rideState`
- `flatMap2(TaxiFare fare, Collector<RideAndFare> out)` gestisce eventi dal secondo stream (`TaxiFare`):
  - legge `rideState`
  - se la ride corrispondente e' gia' presente: emette `RideAndFare` e fa `rideState.clear()`
  - altrimenti salva la fare in `fareState`

Perche' funziona:

- le due `flatMap` sono speculari
- quando arriva il \"secondo pezzo\" della coppia, viene fatto il join immediato
- lo stato keyed per `rideId` copre i casi out-of-order

Nota didattica:

- l'ordine di arrivo non e' garantito
- lo stato serve a bufferizzare l'evento arrivato per primo

## 3) Hourly Tips

Obiettivo:

- per ogni ora, trovare il driver con la somma mance (`tip`) piu' alta

Implementazione di riferimento:

- `flink-training/hourly-tips/src/solution/java/org/apache/flink/training/solutions/hourlytips/HourlyTipsSolution.java`

Passi logici:

1. stream `TaxiFare` da `TaxiFareGenerator`
2. assegnazione event-time + watermark monotono su `fare.getEventTimeMillis()`
3. finestra tumbling 1h keyed per `driverId`: somma `tip` (`AddTips`)
4. seconda finestra 1h globale (`windowAll`) per estrarre il massimo della somma
5. output `Tuple3<windowEndTs, driverId, totalTips>`

Come leggere l'output runtime:

- formato tipico: `N> (windowEndTs, driverId, totalTips)`
- `N>`: subtask del sink che ha stampato la riga
- `windowEndTs`: fine della finestra oraria in epoch millis (event time)
- `driverId`: driver con il totale mance massimo in quella finestra
- `totalTips`: somma mance del driver in quell'ora

Esempio:

- `3> (1577883600000,2013000089,76.0)`
  - fine finestra: `2020-01-01 13:00:00 UTC`
  - driver vincente: `2013000089`
  - totale mance ora: `76.0`

## 4) Long Ride Alerts

Obiettivo:

- emettere `rideId` delle corse con durata > 2 ore
- emettere alert il prima possibile, senza attendere necessariamente l'END

Implementazione di riferimento:

- `flink-training/long-ride-alerts/src/solution/java/org/apache/flink/training/solutions/longrides/LongRidesSolution.java`

Passi logici:

1. stream `TaxiRide` da `TaxiRideGenerator`
2. watermark strategy con out-of-orderness ammessa di 60 secondi
3. `keyBy(rideId)` + `KeyedProcessFunction` (`AlertFunction`)
4. stato keyed (`ValueState<TaxiRide>`) per memorizzare il primo evento visto
5. timer event-time a `start + 2h` per alert in assenza dell'END
6. emissione alert quando:
   - arriva la coppia START/END e la durata supera 2h, oppure
   - scatta il timer

## 5) Sources usate (dettaglio)

### TaxiRideGenerator

Classe:

- `flink-training/common/src/main/java/org/apache/flink/training/exercises/common/sources/TaxiRideGenerator.java`

Caratteristiche:

- stream continuo (finche' il job gira)
- produce eventi out-of-order
- genera batch di START e rilascia alcuni END anche prima dello START corrispondente
- ritmo emissione pilotato da `SLEEP_MILLIS_PER_EVENT = 10`

Per ogni `rideId` vengono generati:

- un evento START (`isStart=true`)
- un evento END (`isStart=false`)

Perche' alcuni END arrivano prima degli START:

- e' intenzionale e didattico
- serve a simulare stream reali dove ordine di arrivo != ordine logico
- dimostra che non puoi assumere "prima START poi END"
- obbliga a usare correttamente stato, timer e/o watermark per gestire out-of-order

### TaxiFareGenerator

Classe:

- `flink-training/common/src/main/java/org/apache/flink/training/exercises/common/sources/TaxiFareGenerator.java`

Caratteristiche:

- stream in ordine per `rideId`
- genera un `TaxiFare` per `rideId`
- usa la stessa cadenza del ride generator (`10ms/event`)

Supporta modalita' bounded:

- `TaxiFareGenerator.runFor(Duration)` limita l'emissione fino a una soglia temporale

### DataGenerator (base comune)

Classe:

- `flink-training/common/src/main/java/org/apache/flink/training/exercises/common/utils/DataGenerator.java`

Ruolo:

- genera in modo deterministico i campi di `TaxiRide` e `TaxiFare` a partire da `rideId`

Conseguenza didattica utile:

- per lo stesso `rideId`, la `startTime` della fare coincide con il tempo START della ride
- questo rende riproducibile il join di `rides-and-fares`

### GeoUtils

Classe:

- `flink-training/common/src/main/java/org/apache/flink/training/exercises/common/utils/GeoUtils.java`

Uso principale:

- filtro geografico in `ride-cleansing` (`isInNYC`)
- limiti NYC:
  - `LON_WEST = -74.05`
  - `LON_EAST = -73.7`
  - `LAT_SOUTH = 40.5`
  - `LAT_NORTH = 41.0`

## 6) Datatypes principali

- `TaxiRide`: include `rideId`, tipo evento (START/END), timestamp, coordinate start/end, driver/taxi
- `TaxiFare`: include `rideId`, `startTime`, payment info (`tip`, `tolls`, `totalFare`)
- `RideAndFare`: coppia di `TaxiRide` + `TaxiFare`

Classi:

- `flink-training/common/src/main/java/org/apache/flink/training/exercises/common/datatypes/TaxiRide.java`
- `flink-training/common/src/main/java/org/apache/flink/training/exercises/common/datatypes/TaxiFare.java`
- `flink-training/common/src/main/java/org/apache/flink/training/exercises/common/datatypes/RideAndFare.java`

## 7) Esecuzione rapida

Da root del training vendorizzato:

```bash
cd flink-demo/flink/flink-training
./gradlew :ride-cleansing:runJavaSolution
./gradlew :rides-and-fares:runJavaSolution
./gradlew :hourly-tips:runJavaSolution
./gradlew :long-ride-alerts:runJavaSolution
```

Nota:

- sono stream continui, interrompili con `Ctrl+C`
