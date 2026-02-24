#!/bin/bash

# Cloudera Streaming Analytics Community Edition Startup Script

set -e

echo "Starting CSA Community Edition services..."

# 1. Start CSA
docker-compose up -d

# 2. Wait for services to be healthy
echo "Waiting for services to become healthy..."
echo "This can take several minutes depending on your hardware."

SERVICES=("flink-jobmanager" "kafka" "postgresql" "ssb-sse" "smm")

for service in "${SERVICES[@]}"; do
    echo -n "Checking $service... "
    while true; do
        # Suppress warnings about obsolete version attribute
        HEALTH=$(docker-compose ps "$service" --format "{{.Health}}" 2>/dev/null || echo "unsupported")
        
        # Fallback for platforms where --format {{.Health}} might not work as expected or reports differently
        if [ "$HEALTH" == "unsupported" ] || [ -z "$HEALTH" ]; then
             STATUS=$(docker-compose ps "$service" --format json 2>/dev/null | grep -o '"Health":"[^"]*"' | cut -d'"' -f4)
             HEALTH=${STATUS:-"starting"}
        fi

        if [ "$HEALTH" == "healthy" ]; then
            echo "Healthy!"
            break
        elif [ "$HEALTH" == "unhealthy" ]; then
            echo "Critical: $service is UNHEALTHY. Check logs with 'docker-compose logs $service'."
            exit 1
        fi
        echo -n "."
        sleep 5
    done
done

echo "--------------------------------------------------"
echo "CSA Services are UP and HEALTHY!"
echo "--------------------------------------------------"
echo "Services available at:"
echo "- SSB Web UI: http://localhost:18121"
echo "- SSB Materialized Views: http://localhost:18131"
echo "- Streams Messaging Manager UI: http://localhost:9991"
echo "- Streams Messaging Manager API: http://localhost:8585"
echo "- Flink Web UI: http://localhost:8081"
echo "- Kafka: localhost:9092"
echo "- Schema Registry: http://localhost:7788"
echo "--------------------------------------------------"
