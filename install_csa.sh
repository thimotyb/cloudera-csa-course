#!/bin/bash

# Cloudera Streaming Analytics Community Edition Installation Script

set -e

echo "Starting CSA Community Edition Installation..."

# 1. Prerequisites Check
echo "Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo "Error: Docker not found. Please install Docker first."
    exit 1
fi

if ! command -v docker-compose &> /dev/null; then
    echo "Error: Docker Compose not found. Please install Docker Compose first."
    exit 1
fi

# Check available RAM (Recommended 8GB+ for CSA)
TOTAL_RAM=$(free -g | awk '/^Mem:/{print $2}')
if [ "$TOTAL_RAM" -lt 8 ]; then
    echo "Warning: Only ${TOTAL_RAM}GB of RAM detected. CSA works best with at least 8GB."
fi

# 2. Pull Images
echo "Pulling Docker images (this may take a while)..."
docker-compose pull

# 3. Start CSA
echo "Starting CSA services..."
docker-compose up -d

# 4. Wait for services to be healthy
echo "Waiting for services to become healthy..."
echo "This can take several minutes depending on your hardware."

check_health() {
    local service=$1
    local status=$(docker-compose ps --format json "$service" | grep -o '"Health":"[^"]*"' | cut -d'"' -f4)
    echo "$status"
}

SERVICES=("flink-jobmanager" "kafka" "postgresql" "ssb-sse" "smm")

for service in "${SERVICES[@]}"; do
    echo -n "Checking $service... "
    while true; do
        HEALTH=$(docker-compose ps "$service" --format "{{.Health}}")
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
echo "CSA Installation Complete!"
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
