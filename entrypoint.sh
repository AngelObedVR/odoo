#!/bin/bash
set -e

# Define defaults if not set
: "${DB_HOST:=${HOST:-db}}"
: "${DB_PORT:=${PORT:-5432}}"
: "${DB_USER:=${USER:-odoo}}"
: "${DB_PASSWORD:=${PASSWORD:-odoo}}"

# Write configuration file
mkdir -p /etc/odoo
cat <<EOF > /etc/odoo/odoo.conf
[options]
addons_path = /opt/odoo/odoo/addons,/opt/odoo/addons
data_dir = /var/lib/odoo
db_host = ${DB_HOST}
db_port = ${DB_PORT}
db_user = ${DB_USER}
db_password = ${DB_PASSWORD}
EOF

# Wait for PostgreSQL
until pg_isready -h "$DB_HOST" -p "$DB_PORT" -U "$DB_USER"; do
  echo "Waiting for PostgreSQL at $DB_HOST:$DB_PORT..."
  sleep 1
done

echo "PostgreSQL is ready! Starting Odoo..."
exec "$@"
