#!/usr/bin/env bash
set -euo pipefail

MYSQL_CONTAINER="${MYSQL_CONTAINER:-csa-mysql-source-1}"
MYSQL_ROOT_PASSWORD="${MYSQL_ROOT_PASSWORD:-root}"

if ! docker ps --format '{{.Names}}' | grep -q "^${MYSQL_CONTAINER}$"; then
  echo "[ERR] Container MySQL ${MYSQL_CONTAINER} non in esecuzione"
  exit 1
fi

docker exec "$MYSQL_CONTAINER" bash -lc "mysql -uroot -p$MYSQL_ROOT_PASSWORD inventory <<'SQL'
CREATE TABLE IF NOT EXISTS customers_live (
  id INT AUTO_INCREMENT PRIMARY KEY,
  full_name VARCHAR(255) NOT NULL,
  email VARCHAR(255) NOT NULL,
  city VARCHAR(100),
  created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO customers_live (full_name, email, city) VALUES
  ('Alice Rossi', CONCAT('alice.', UNIX_TIMESTAMP(), '@demo.local'), 'Milano'),
  ('Bruno Verdi', CONCAT('bruno.', UNIX_TIMESTAMP(), '@demo.local'), 'Roma'),
  ('Chiara Neri', CONCAT('chiara.', UNIX_TIMESTAMP(), '@demo.local'), 'Torino');

SELECT id, full_name, email, city, created_at
FROM customers_live
ORDER BY id DESC
LIMIT 10;
SQL"

echo "[OK] Record inseriti in inventory.customers_live"
