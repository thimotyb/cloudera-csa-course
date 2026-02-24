/*
 * Licensed to the Apache Software Foundation (ASF) under one
 * or more contributor license agreements.  See the NOTICE file
 * distributed with this work for additional information
 * regarding copyright ownership.  The ASF licenses this file
 * to you under the Apache License, Version 2.0 (the
 * "License"); you may not use this file except in compliance
 * with the License.  You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

package myflink;

import org.apache.flink.util.FileUtils;
import org.apache.flink.util.StringUtils;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.io.BufferedReader;
import java.io.File;
import java.io.FileInputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeFormatter;
import java.time.format.DateTimeFormatterBuilder;
import java.time.temporal.ChronoField;
import java.util.TimeZone;
import java.util.function.Consumer;

public class SourceGenerator {
    /** Formatter for SQL string representation of a time value. */
    static final DateTimeFormatter SQL_TIME_FORMAT = new DateTimeFormatterBuilder()
        .appendPattern("HH:mm:ss")
        .appendFraction(ChronoField.NANO_OF_SECOND, 0, 9, true)
        .toFormatter();

    /** Formatter for SQL string representation of a timestamp value (without UTC timezone). */
    static final DateTimeFormatter SQL_TIMESTAMP_FORMAT = new DateTimeFormatterBuilder()
        .append(DateTimeFormatter.ISO_LOCAL_DATE)
        .appendLiteral(' ')
        .append(SQL_TIME_FORMAT)
        .toFormatter();

    private static final Logger LOGGER = LoggerFactory.getLogger(SourceGenerator.class);
    private static final long SPEED = 1000; // 每秒1000条
    private static final String MAX = "MAX"; // 不限速
    private static final String FROM_BEGINNING = "from-beginning";
    private static final File checkpoint = new File("checkpoint");

    public static void main(String[] args) {
        File userBehaviorFile = new File("datagen/user_behavior.log");
        long speed = SPEED;
        long endLine = Long.MAX_VALUE;
        boolean loop = false;
        boolean fromBeginning = false;
        Consumer<String> consumer = new ConsolePrinter();

        // parse arguments
        int argOffset = 0;
        while(argOffset < args.length) {

            String arg = args[argOffset++];
            switch (arg) {
                case "--input":
                    String basePath = args[argOffset++];
                    userBehaviorFile = new File(basePath);
                    break;
                case "--output":
                    String sink = args[argOffset++];
                    switch (sink) {
                        case "console":
                            consumer = new ConsolePrinter();
                            break;
                        case "kafka":
                            String brokers = args[argOffset++];
                            consumer = new KafkaProducer("user_behavior", brokers);
                            break;
                        default:
                            throw new IllegalArgumentException("Unknown output configuration");
                    }
                    break;
                case "--speedup":
                    String spd = args[argOffset++];
                    if (MAX.equalsIgnoreCase(spd)) {
                        speed = Long.MAX_VALUE;
                    } else {
                        speed = Long.parseLong(spd);
                    }
                    break;
                case "--endline":
                    String end = args[argOffset++];
                    endLine = Long.parseLong(end);
                    break;
                case "--loop":
                    loop = true;
                    break;
                case FROM_BEGINNING:
                case "--from-beginning":
                    fromBeginning = true;
                    break;
                default:
                    throw new IllegalArgumentException("Unknown parameter");
            }
        }

        long startLine = 0;
        if (!fromBeginning && checkpoint.exists()) {
            String line = null;
            try {
                line = FileUtils.readFileUtf8(checkpoint);
            } catch (IOException e) {
                LOGGER.error("exception", e);
            }
            if (!StringUtils.isNullOrWhitespaceOnly(line)) {
                startLine = Long.parseLong(line);
            }
        }

        if (!checkpoint.exists()) {
            try {
                checkpoint.createNewFile();
            } catch (IOException e) {
                LOGGER.error("exception", e);
            }
        }
        checkpointState(startLine);

        long cycleShiftMillis = resolveCycleShiftMillis(userBehaviorFile);
        if (loop) {
            LOGGER.info("Loop mode enabled with cycle timestamp shift of {} ms.", cycleShiftMillis);
        }

        TimeZone tz = TimeZone.getTimeZone("Asia/Shanghai");
        try {
            int counter = 0;
            long start = System.nanoTime();
            long totalSent = 0;
            long cycle = 0;
            boolean firstCycle = true;
            boolean printedStartMessage = false;

            while (true) {
                long cycleStartLine = firstCycle ? startLine : 0;
                long currentLine = 0;

                try (InputStream inputStream = new FileInputStream(userBehaviorFile);
                        BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
                    String line;
                    while ((line = reader.readLine()) != null) {
                        if (currentLine < cycleStartLine) {
                            currentLine++;
                            continue;
                        }

                        currentLine++;
                        checkpointState(currentLine);

                        String[] splits = line.split(",");
                        long ts = Long.parseLong(splits[4]) * 1000 + cycle * cycleShiftMillis;
                        Instant instant = Instant.ofEpochMilli(ts + tz.getOffset(ts));
                        LocalDateTime dateTime = LocalDateTime.ofInstant(instant, ZoneId.of("Z"));
                        String outline = String.format(
                            "{\"user_id\": \"%s\", \"item_id\":\"%s\", \"category_id\": \"%s\", \"behavior\": \"%s\", \"ts\": \"%s\"}",
                            splits[0],
                            splits[1],
                            splits[2],
                            splits[3],
                            SQL_TIMESTAMP_FORMAT.format(dateTime));

                        consumer.accept(outline);
                        totalSent++;

                        counter++;
                        if (counter >= speed) {
                            long end = System.nanoTime();
                            long diff = end - start;
                            while (diff < 1000_000_000) {
                                Thread.sleep(1);
                                end = System.nanoTime();
                                diff = end - start;
                            }
                            start = end;
                            counter = 0;
                        }

                        if (!printedStartMessage && totalSent >= 10) {
                            System.out.println("Start sending messages to Kafka...");
                            printedStartMessage = true;
                        }

                        if (totalSent >= endLine) {
                            System.out.println("send " + totalSent + " lines.");
                            return;
                        }
                    }
                }

                if (!loop) {
                    break;
                }

                cycle++;
                firstCycle = false;
                checkpointState(0);
            }
        } catch (IOException | InterruptedException e) {
            LOGGER.error("exception", e);
            if (e instanceof InterruptedException) {
                Thread.currentThread().interrupt();
            }
        } finally {
            closeConsumer(consumer);
        }
    }

    private static long resolveCycleShiftMillis(File userBehaviorFile) {
        long minTsMillis = Long.MAX_VALUE;
        long maxTsMillis = Long.MIN_VALUE;

        try (InputStream inputStream = new FileInputStream(userBehaviorFile);
                BufferedReader reader = new BufferedReader(new InputStreamReader(inputStream))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String[] splits = line.split(",");
                if (splits.length < 5) {
                    continue;
                }
                long tsMillis = Long.parseLong(splits[4]) * 1000;
                minTsMillis = Math.min(minTsMillis, tsMillis);
                maxTsMillis = Math.max(maxTsMillis, tsMillis);
            }
        } catch (IOException e) {
            LOGGER.error("exception", e);
            return 0;
        }

        if (minTsMillis == Long.MAX_VALUE || maxTsMillis == Long.MIN_VALUE) {
            return 0;
        }

        return (maxTsMillis - minTsMillis) + 1000;
    }

    private static void closeConsumer(Consumer<String> consumer) {
        if (consumer instanceof AutoCloseable) {
            try {
                ((AutoCloseable) consumer).close();
            } catch (Exception e) {
                LOGGER.error("exception", e);
            }
        }
    }

    private static void checkpointState(long lineState) {
        try {
            FileUtils.writeFileUtf8(checkpoint, String.valueOf(lineState));
        } catch (IOException e) {
            LOGGER.error("exception", e);
        }
    }
}
