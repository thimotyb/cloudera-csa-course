package com.cloudera.examples.sr;

import com.hortonworks.registries.schemaregistry.serdes.avro.kafka.KafkaAvroDeserializer;
import org.apache.avro.generic.GenericRecord;
import org.apache.kafka.clients.consumer.ConsumerConfig;
import org.apache.kafka.clients.consumer.ConsumerRecord;
import org.apache.kafka.clients.consumer.ConsumerRecords;
import org.apache.kafka.clients.consumer.KafkaConsumer;
import org.apache.kafka.common.header.Header;
import org.apache.kafka.common.serialization.StringDeserializer;

import java.nio.charset.StandardCharsets;
import java.time.Duration;
import java.util.Collections;
import java.util.Objects;
import java.util.Properties;
import java.util.UUID;

public final class SchemaRegistryKafkaConsumer {

    private static final String VALUE_SCHEMA_VERSION_HEADER = "value.schema.version.id";
    private static final String KEY_SCHEMA_VERSION_HEADER = "key.schema.version.id";

    private SchemaRegistryKafkaConsumer() {
    }

    public static void main(String[] args) {
        String bootstrapServers = env("CSA_BOOTSTRAP_SERVERS", "localhost:9092");
        String schemaRegistryUrl = env("CSA_SCHEMA_REGISTRY_URL", "http://localhost:7788/api/v1");
        String topic = env("CSA_TOPIC", "csa.sr.demo");
        String groupId = env("CSA_GROUP_ID_PREFIX", "csa-sr-demo-group") + "-" + UUID.randomUUID();
        String runIdFilter = env("CSA_RUN_ID_FILTER", "");
        int maxMessages = envInt("CSA_MAX_MESSAGES", 0);
        int timeoutSeconds = envInt("CSA_CONSUME_TIMEOUT_SECONDS", 0);

        System.out.printf("Consumer bootstrap servers: %s%n", bootstrapServers);
        System.out.printf("Consumer Schema Registry URL: %s%n", schemaRegistryUrl);
        System.out.printf("Consumer topic: %s%n", topic);
        System.out.printf("Consumer group id: %s%n", groupId);
        if (!runIdFilter.isBlank()) {
            System.out.printf("Consumer filtering run_id=%s%n", runIdFilter);
        }
        if (maxMessages > 0) {
            System.out.printf("Consumer max messages=%d%n", maxMessages);
        } else {
            System.out.println("Consumer max messages=unbounded");
        }

        consumeRecords(bootstrapServers, schemaRegistryUrl, topic, groupId, runIdFilter, maxMessages, timeoutSeconds);
    }

    private static void consumeRecords(
            String bootstrapServers,
            String schemaRegistryUrl,
            String topic,
            String groupId,
            String runIdFilter,
            int maxMessages,
            int timeoutSeconds
    ) {
        Properties consumerProps = new Properties();
        consumerProps.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, bootstrapServers);
        consumerProps.put(ConsumerConfig.CLIENT_ID_CONFIG, "csa-sr-consumer");
        consumerProps.put(ConsumerConfig.GROUP_ID_CONFIG, groupId);
        consumerProps.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, "earliest");
        consumerProps.put(ConsumerConfig.ENABLE_AUTO_COMMIT_CONFIG, "false");
        consumerProps.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, StringDeserializer.class.getName());
        consumerProps.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, KafkaAvroDeserializer.class.getName());
        consumerProps.put("schema.registry.url", schemaRegistryUrl);
        consumerProps.put("specific.avro.reader", false);

        long deadline = timeoutSeconds > 0
                ? System.currentTimeMillis() + Duration.ofSeconds(timeoutSeconds).toMillis()
                : Long.MAX_VALUE;
        int consumedCount = 0;

        try (KafkaConsumer<String, Object> consumer = new KafkaConsumer<>(consumerProps)) {
            consumer.subscribe(Collections.singletonList(topic));
            while (System.currentTimeMillis() < deadline && (maxMessages <= 0 || consumedCount < maxMessages)) {
                ConsumerRecords<String, Object> records = consumer.poll(Duration.ofSeconds(1));
                for (ConsumerRecord<String, Object> record : records) {
                    if (!(record.value() instanceof GenericRecord value)) {
                        continue;
                    }

                    String currentRunId = Objects.toString(value.get("run_id"), "");
                    if (!runIdFilter.isBlank() && !runIdFilter.equals(currentRunId)) {
                        continue;
                    }

                    consumedCount++;
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

                    if (maxMessages > 0 && consumedCount >= maxMessages) {
                        break;
                    }
                }
            }
            consumer.commitSync();
        }

        System.out.printf("Consumer completed. consumed=%d%n", consumedCount);
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
