FROM maven:3.6-jdk-8-slim AS builder

WORKDIR /build
COPY datagen/pom.xml /build/pom.xml
COPY src/main/java/myflink /build/src/main/java/myflink
RUN mvn -q -DskipTests package

FROM eclipse-temurin:8-jre
WORKDIR /opt/datagen
COPY datagen/user_behavior.log /opt/datagen/user_behavior.log
COPY --from=builder /build/target/flink-sql-demo.jar /opt/datagen/flink-sql-demo.jar
ENV DATEGEN_HOME /opt/datagen
