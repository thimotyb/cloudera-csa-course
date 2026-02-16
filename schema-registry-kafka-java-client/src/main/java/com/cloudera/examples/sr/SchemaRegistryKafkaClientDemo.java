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

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.time.Instant;
import java.util.Collections;
import java.util.Objects;
import java.util.Properties;
import java.util.Set;
import java.util.UUID;
import java.util.concurrent.TimeUnit;

public final class SchemaRegistryKafkaClientDemo {

    private static final String VALUE_SCHEMA_VERSION_HEADER = "value.schema.version.id";
    private static final String KEY_SCHEMA_VERSION_HEADER = "key.schema.version.id";

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

    private SchemaRegistryKafkaClientDemo() {
    }

    public static void main(String[] args) throws Exception {
        DemoConfig config = DemoConfig.fromEnvironment();
        String runId = UUID.randomUUID().toString();

        System.out.printf("Bootstrap servers: %s%n", config.bootstrapServers());
        System.out.printf("Schema Registry URL: %s%n", config.schemaRegistryUrl());
        System.out.printf("Topic: %s%n", config.topic());
        System.out.printf("Run ID: %s%n", runId);

        ensureTopicExists(config);
        produceRecords(config, runId);
        consumeRecords(config, runId);
    }

    private static void ensureTopicExists(DemoConfig config) throws Exception {
        Properties adminProps = new Properties();
        adminProps.put(AdminClientConfig.BOOTSTRAP_SERVERS_CONFIG, config.bootstrapServers());
        try (AdminClient adminClient = AdminClient.create(adminProps)) {
            Set<String> topics = adminClient.listTopics().names().get(20, TimeUnit.SECONDS);
            if (topics.contains(config.topic())) {
                System.out.printf("Topic '%s' already exists.%n", config.topic());
                return;
            }

            NewTopic newTopic = new NewTopic(config.topic(), config.partitions(), config.replicationFactor());
            adminClient.createTopics(Collections.singleton(newTopic)).all().get(20, TimeUnit.SECONDS);
            System.out.printf("Topic '%s' created.%n", config.topic());
        }
    }

    private static void produceRecords(DemoConfig config, String runId) throws Exception {
        Properties producerProps = new Properties();
        producerProps.put(ProducerConfig.BOOTSTRAP_SERVERS_CONFIG, config.bootstrapServers());
        producerProps.put(ProducerConfig.CLIENT_ID_CONFIG, "csa-sr-demo-producer");
        producerProps.put(ProducerConfig.ACKS_CONFIG, "all");
        producerProps.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, StringSerializer.class.getName());
        producerProps.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, KafkaAvroSerializer.class.getName());
        producerProps.put("schema.registry.url", config.schemaRegistryUrl());

        Schema valueSchema = new Schema.Parser().parse(VALUE_SCHEMA_JSON);
        try (KafkaProducer<String, GenericRecord> producer = new KafkaProducer<>(producerProps)) {
            for (int i = 1; i <= config.messageCount(); i++) {
                String key = "event-" + i;
                GenericRecord value = buildValue(valueSchema, runId, i);
                ProducerRecord<String, GenericRecord> record = new ProducerRecord<>(config.topic(), key, value);
                producer.send(record).get(20, TimeUnit.SECONDS);
                System.out.printf("Produced key=%s value=%s%n", key, value);
            }
            producer.flush();
        }
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

    private static void consumeRecords(DemoConfig config, String runId) {
        Properties consumerProps = new Properties();
        consumerProps.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, config.bootstrapServers());
        consumerProps.put(ConsumerConfig.CLIENT_ID_CONFIG, "csa-sr-demo-consumer");
        consumerProps.put(ConsumerConfig.GROUP_ID_CONFIG, config.groupIdPrefix() + "-" + UUID.randomUUID());
        consumerProps.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        consumerProps.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false");
        consumerProps.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        consumerProps.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class.getName());
        consumerProps.put("schema.registry.url", config.schemaRegistryUrl());
        consumerProps.put("specific.avro.reader", false);

        int matched = 0;
        long deadline = System.currentTimeMillis() + Duration.ofSeconds(config.consumeTimeoutSeconds()).toMillis();

        try (KafkaConsumer<String, Object> consumer = new KafkaConsumer<>(consumerProps)) {
            consumer.subscribe(Collections.singletonList(config.topic()));
            while (System.currentTimeMillis() < deadline && matched < config.messageCount()) {
                ConsumerRecords<String, Object> records = consumer.poll(Duration.ofSeconds(1));
                for (ConsumerRecord<String, Object> record : records) {
                    GenericRecord value = asGenericRecord(record.value());
                    String currentRunId = Objects.toString(value.get("run_id"), "");
                    if (!runId.equals(currentRunId)) {
                        continue;
                    }

                    matched++;
                    String keySchemaHeader = headerValue(record.headers().lastHeader(KEY_SCHEMA_VERSION_HEADER));
                    String valueSchemaHeader = headerValue(record.headers().lastHeader(VALUE_SCHEMA_VERSION_HEADER));
                    System.out.printf(
                            "Consumed key=%s partition=%d offset=%d key.schema.version.id=%s value.schema.version.id=%s value=%s%n",
                            record.key(),
                            record.partition(),
                            record.offset(),
                            keySchemaHeader,
                            valueSchemaHeader,
                            value
                    );
                }
            }
            consumer.commitSync();
        }

        if (matched < config.messageCount()) {
            throw new IllegalStateException(
                    "Expected " + config.messageCount() + " records for run_id=" + runId + ", but consumed " + matched
            );
        }

        System.out.printf(
                "Completed successfully. Consumed %d/%d records for run_id=%s%n",
                matched,
                config.messageCount(),
                runId
        );
    }

    private static GenericRecord asGenericRecord(Object value) {
        if (value instanceof GenericRecord genericRecord) {
            return genericRecord;
        }
        throw new IllegalArgumentException("Expected GenericRecord but found: " + value);
    }

    /**
     * Converts a Kafka header into a readable string:
     * - returns "<missing>" when the header is absent
     * - returns plain text when bytes are printable ASCII
     * - falls back to hex when bytes are binary/non-printable
     */
    private static String headerValue(Header header) {
        if (header == null || header.value() == null) {
            return "<missing>";
        }
        byte[] bytes = header.value();
        String text = new String(bytes, StandardCharsets.UTF_8);
        boolean printable = text.chars().allMatch(c -> c >= 32 && c <= 126);
        return printable ? text : bytesToHex(bytes);
    }

    /**
     * Renders binary bytes as a hex string with "0x" prefix.
     */
    private static String bytesToHex(byte[] bytes) {
        StringBuilder sb = new StringBuilder(bytes.length * 2);
        for (byte b : bytes) {
            sb.append(String.format("%02x", b));
        }
        return "0x" + sb;
    }

    private record DemoConfig(
            String bootstrapServers,
            String schemaRegistryUrl,
            String topic,
            String groupIdPrefix,
            int partitions,
            short replicationFactor,
            int messageCount,
            int consumeTimeoutSeconds
    ) {
        private static DemoConfig fromEnvironment() {
            return new DemoConfig(
                    env("CSA_BOOTSTRAP_SERVERS", "localhost:9092"),
                    env("CSA_SCHEMA_REGISTRY_URL", "http://localhost:7788/api/v1"),
                    env("CSA_TOPIC", "csa.sr.demo"),
                    env("CSA_GROUP_ID_PREFIX", "csa-sr-demo-group"),
                    envInt("CSA_TOPIC_PARTITIONS", 1),
                    (short) envInt("CSA_TOPIC_REPLICATION_FACTOR", 1),
                    envInt("CSA_MESSAGE_COUNT", 5),
                    envInt("CSA_CONSUME_TIMEOUT_SECONDS", 30)
            );
        }
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
