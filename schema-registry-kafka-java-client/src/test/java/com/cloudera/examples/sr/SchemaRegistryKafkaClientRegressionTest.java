package com.cloudera.examples.sr;

import com.hortonworks.registries.schemaregistry.serdes.avro.kafka.KafkaAvroDeserializer;
import com.hortonworks.registries.schemaregistry.serdes.avro.kafka.KafkaAvroSerializer;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.header.Header;
import org.apache.kafka.common.serialization.StringDeserializer;
import org.apache.kafka.common.serialization.StringSerializer;
import org.junit.jupiter.api.Assertions;
import org.junit.jupiter.api.Assumptions;
import org.junit.jupiter.api.Test;

import java.io.IOException;
import java.nio.charset.StandardCharsets;
import java.net.HttpURLConnection;
import java.net.URL;
import java.time.Duration;
import java.util.Collections;
import java.util.Properties;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

class SchemaRegistryKafkaClientRegressionTest {

    private static final String VALUE_SCHEMA_VERSION_HEADER = "value.schema.version.id";
    private static final String VALUE_SCHEMA_V1_JSON = """
            {
              "type":"record",
              "namespace":"com.cloudera.examples",
              "name":"SensorReadingV1",
              "doc":"Regression test v1 schema",
              "fields":[
                {"name":"run_id","type":"string"},
                {"name":"event_id","type":"string"},
                {"name":"host","type":"string"},
                {"name":"metric","type":"string"},
                {"name":"value","type":"double"},
                {"name":"event_ts","type":"long"}
              ]
            }
            """;

    @Test
    void shouldProduceAndDeserializeV1Message() throws Exception {
        String bootstrapServers = env("CSA_BOOTSTRAP_SERVERS", "localhost:9092");
        String schemaRegistryUrl = env("CSA_SCHEMA_REGISTRY_URL", "http://localhost:7788/api/v1");
        String topic = "csa.sr.regression.v1." + System.currentTimeMillis();
        String groupId = "csa-sr-regression-" + UUID.randomUUID();
        String key = "sensor-1";
        String runId = "run-v1-" + UUID.randomUUID();

        Assumptions.assumeTrue(
                isHttpOk(schemaRegistryUrl + "/schemaregistry/schemas"),
                "Schema Registry non raggiungibile su " + schemaRegistryUrl
        );

        ensureTopicExists(bootstrapServers, topic);

        Schema schemaV1 = new Schema.Parser().parse(VALUE_SCHEMA_V1_JSON);
        GenericRecord expectedRecord = new GenericData.Record(schemaV1);
        expectedRecord.put("run_id", runId);
        expectedRecord.put("event_id", "evt-0001");
        expectedRecord.put("host", "server-a");
        expectedRecord.put("metric", "cpu_load");
        expectedRecord.put("value", 42.5d);
        expectedRecord.put("event_ts", 1_700_000_000_000L);
        System.out.println("V1 sample message: " + expectedRecord);

        produceV1Message(bootstrapServers, schemaRegistryUrl, topic, key, expectedRecord);
        ConsumerRecord<String, Object> consumed = consumeByRunId(
                bootstrapServers, schemaRegistryUrl, topic, groupId, runId, Duration.ofSeconds(30)
        );

        Assertions.assertNotNull(consumed, "Nessun messaggio consumato per run_id=" + runId);
        Assertions.assertEquals(key, consumed.key());
        Assertions.assertTrue(consumed.value() instanceof GenericRecord, "Il payload deve essere GenericRecord");

        GenericRecord actualRecord = (GenericRecord) consumed.value();
        System.out.println("Consumed deserialized message: key=" + consumed.key() + " value=" + actualRecord);
        Assertions.assertEquals(runId, actualRecord.get("run_id").toString());
        Assertions.assertEquals("evt-0001", actualRecord.get("event_id").toString());
        Assertions.assertEquals("server-a", actualRecord.get("host").toString());
        Assertions.assertEquals("cpu_load", actualRecord.get("metric").toString());
        Assertions.assertEquals(42.5d, (double) actualRecord.get("value"), 0.0001d);
        Assertions.assertEquals(1_700_000_000_000L, actualRecord.get("event_ts"));

        Header schemaVersionHeader = consumed.headers().lastHeader(VALUE_SCHEMA_VERSION_HEADER);
        if (schemaVersionHeader != null && schemaVersionHeader.value() != null) {
            System.out.println("value.schema.version.id header presente (" + schemaVersionHeader.value().length + " bytes)");
        } else {
            System.out.println("value.schema.version.id header non presente, verifico schema su Schema Registry");
        }

        assertSchemaV1Registered(schemaRegistryUrl, topic);
    }

    private static void ensureTopicExists(String bootstrapServers, String topic) throws Exception {
        Properties adminProps = new Properties();
        adminProps.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        try (AdminClient adminClient = AdminClient.create(adminProps)) {
            NewTopic newTopic = new NewTopic(topic, 1, (short) 1);
            adminClient.createTopics(Collections.singleton(newTopic)).all().get(20, TimeUnit.SECONDS);
        }
    }

    private static void produceV1Message(
            String bootstrapServers,
            String schemaRegistryUrl,
            String topic,
            String key,
            GenericRecord value
    ) throws Exception {
        Properties producerProps = new Properties();
        producerProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        producerProps.put(ProducerConfig.CLIENT_ID_CONFIG, "csa-sr-regression-producer");
        producerProps.put(ProducerConfig.ACKS_CONFIG, "all");
        producerProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        producerProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class.getName());
        producerProps.put("schema.registry.url", schemaRegistryUrl);

        try (KafkaProducer<String, GenericRecord> producer = new KafkaProducer<>(producerProps)) {
            producer.send(new ProducerRecord<>(topic, key, value)).get(20, TimeUnit.SECONDS);
            producer.flush();
        }
    }

    private static ConsumerRecord<String, Object> consumeByRunId(
            String bootstrapServers,
            String schemaRegistryUrl,
            String topic,
            String groupId,
            String runId,
            Duration timeout
    ) {
        Properties consumerProps = new Properties();
        consumerProps.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        consumerProps.put(ConsumerConfig.CLIENT_ID_CONFIG, "csa-sr-regression-consumer");
        consumerProps.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        consumerProps.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        consumerProps.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false");
        consumerProps.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        consumerProps.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class.getName());
        consumerProps.put("schema.registry.url", schemaRegistryUrl);
        consumerProps.put("specific.avro.reader", false);

        long deadline = System.currentTimeMillis() + timeout.toMillis();
        try (KafkaConsumer<String, Object> consumer = new KafkaConsumer<>(consumerProps)) {
            consumer.subscribe(Collections.singleton(topic));
            while (System.currentTimeMillis() < deadline) {
                ConsumerRecords<String, Object> records = consumer.poll(Duration.ofSeconds(1));
                for (ConsumerRecord<String, Object> record : records) {
                    if (!(record.value() instanceof GenericRecord actual)) {
                        continue;
                    }
                    if (runId.equals(String.valueOf(actual.get("run_id")))) {
                        return record;
                    }
                }
            }
            return null;
        }
    }

    private static boolean isHttpOk(String url) {
        try {
            HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
            connection.setRequestMethod("GET");
            connection.setConnectTimeout(3000);
            connection.setReadTimeout(3000);
            int status = connection.getResponseCode();
            return status >= 200 && status < 300;
        } catch (IOException e) {
            return false;
        }
    }

    private static String env(String key, String defaultValue) {
        String value = System.getenv(key);
        return value == null || value.isBlank() ? defaultValue : value;
    }

    private static void assertSchemaV1Registered(String schemaRegistryUrl, String topic) throws IOException {
        String versionsUrl = schemaRegistryUrl + "/schemaregistry/schemas/" + topic + "/versions";
        HttpURLConnection connection = (HttpURLConnection) new URL(versionsUrl).openConnection();
        connection.setRequestMethod("GET");
        connection.setConnectTimeout(5000);
        connection.setReadTimeout(5000);

        int status = connection.getResponseCode();
        Assertions.assertTrue(status >= 200 && status < 300, "Schema Registry response non valida: " + status);

        String body = new String(connection.getInputStream().readAllBytes(), StandardCharsets.UTF_8);
        Assertions.assertTrue(body.contains("\"version\":1"), "Versione schema v1 non trovata in Schema Registry");
        Assertions.assertTrue(
                body.contains("SensorReadingV1"),
                "Schema atteso SensorReadingV1 non trovato in Schema Registry"
        );
    }
}
