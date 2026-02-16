package com.cloudera.examples.sr;

import com.hortonworks.registries.schemaregistry.serdes.avro.kafka.KafkaAvroSerializer;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericData;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.admin.AdminClient;
import org.apache.kafka.clients.admin.AdminClientConfig;
import org.apache.kafka.clients.admin.NewTopic;
import org.apache.kafka.clients.producer.KafkaProducer;
import org.apache.kafka.clients.producer.ProducerConfig;
import org.apache.kafka.clients.producer.ProducerRecord;
import org.apache.kafka.common.serialization.StringSerializer;

import java.time.Instant;
import java.util.Collections;
import java.util.Properties;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

public final class SchemaRegistryKafkaProducer {

    private static final String VALUE_SCHEMA_JSON = """
            {
              "type":"record",
              "namespace":"com.cloudera.examples",
              "name":"SensorReading",
              "doc":"Schema Registry integration demo payload",
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

    private SchemaRegistryKafkaProducer() {
    }

    public static void main(String[] args) throws Exception {
        String bootstrapServers = env("CSA_BOOTSTRAP_SERVERS", "localhost:9092");
        String schemaRegistryUrl = env("CSA_SCHEMA_REGISTRY_URL", "http://localhost:7788/api/v1");
        String topic = env("CSA_TOPIC", "csa.sr.demo");
        int partitions = envInt("CSA_TOPIC_PARTITIONS", 1);
        short replicationFactor = (short) envInt("CSA_TOPIC_REPLICATION_FACTOR", 1);
        int messageCount = envInt("CSA_MESSAGE_COUNT", 10);
        int intervalMs = envInt("CSA_PRODUCER_INTERVAL_MS", 1000);
        String runId = env("CSA_RUN_ID", UUID.randomUUID().toString());

        System.out.printf("Producer bootstrap servers: %s%n", bootstrapServers);
        System.out.printf("Producer Schema Registry URL: %s%n", schemaRegistryUrl);
        System.out.printf("Producer topic: %s%n", topic);
        System.out.printf("Producer run_id: %s%n", runId);
        System.out.printf("Producer message count: %d%n", messageCount);

        ensureTopicExists(bootstrapServers, topic, partitions, replicationFactor);
        produceRecords(bootstrapServers, schemaRegistryUrl, topic, runId, messageCount, intervalMs);
    }

    private static void ensureTopicExists(
            String bootstrapServers,
            String topic,
            int partitions,
            short replicationFactor
    ) throws Exception {
        Properties adminProps = new Properties();
        adminProps.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);

        try (AdminClient adminClient = AdminClient.create(adminProps)) {
            Set<String> topics = adminClient.listTopics().names().get(20, TimeUnit.SECONDS);
            if (topics.contains(topic)) {
                System.out.printf("Topic '%s' already exists.%n", topic);
                return;
            }

            NewTopic newTopic = new NewTopic(topic, partitions, replicationFactor);
            adminClient.createTopics(Collections.singleton(newTopic)).all().get(20, TimeUnit.SECONDS);
            System.out.printf("Topic '%s' created.%n", topic);
        }
    }

    private static void produceRecords(
            String bootstrapServers,
            String schemaRegistryUrl,
            String topic,
            String runId,
            int messageCount,
            int intervalMs
    ) throws Exception {
        Properties producerProps = new Properties();
        producerProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        producerProps.put(ProducerConfig.CLIENT_ID_CONFIG, "csa-sr-producer");
        producerProps.put(ProducerConfig.ACKS_CONFIG, "all");
        producerProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        producerProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class.getName());
        producerProps.put("schema.registry.url", schemaRegistryUrl);

        Schema valueSchema = new Schema.Parser().parse(VALUE_SCHEMA_JSON);
        try (KafkaProducer<String, GenericRecord> producer = new KafkaProducer<>(producerProps)) {
            for (int i = 1; i <= messageCount; i++) {
                String key = "event-" + i;
                GenericRecord value = buildValue(valueSchema, runId, i);
                ProducerRecord<String, GenericRecord> record = new ProducerRecord<>(topic, key, value);
                producer.send(record).get(20, TimeUnit.SECONDS);
                System.out.printf("Produced key=%s value=%s%n", key, value);

                if (intervalMs > 0 && i < messageCount) {
                    Thread.sleep(intervalMs);
                }
            }
            producer.flush();
        }

        System.out.println("Producer completed.");
    }

    private static GenericRecord buildValue(Schema valueSchema, String runId, int index) {
        GenericRecord record = new GenericData.Record(valueSchema);
        record.put("run_id", runId);
        record.put("event_id", UUID.randomUUID().toString());
        record.put("host", "csa-localhost");
        record.put("metric", "cpu_load");
        record.put("value", 10.5d + index);
        record.put("event_ts", Instant.now().toEpochMilli());
        return record;
    }

    private static String env(String key, String defaultValue) {
        String value = System.getenv(key);
        return value == null || value.isBlank() ? defaultValue : value;
    }

    private static int envInt(String key, int defaultValue) {
        String value = System.getenv(key);
        if (value == null || value.isBlank()) {
            return defaultValue;
        }
        return Integer.parseInt(value.trim());
    }
}
