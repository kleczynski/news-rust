#!/usr/bin/env bash
set -x
set -eo pipefail

# Check if sqlx-cli is installed
if ! [ -x "$(command -v sqlx)" ]; then
    echo >&2 "Error: sqlx is not installed."
    echo >&2 "Use:"
    echo >&2 "    cargo install --version='~0.8' sqlx-cli \\"
    echo >&2 "    --no-default-features --features rustls,postgres"
    echo >&2 "to install it."
    exit 1
fi

# Default values
DB_PORT="${POSTGRES_PORT:=5433}"
SUPERUSER="${SUPERUSER:=postgres}"
SUPERUSER_PWD="${SUPERUSER_PWD:=password}"
CONTAINER_NAME="postgres"

# 1. Run Postgres with an explicit Healthcheck
# Note: We map host port ${DB_PORT} to container port 5432
docker run \
    --env POSTGRES_USER="${SUPERUSER}" \
    --env POSTGRES_PASSWORD="${SUPERUSER_PWD}" \
    --publish "${DB_PORT}":5432 \
    --detach \
    --name "${CONTAINER_NAME}" \
    --health-cmd="pg_isready -U ${SUPERUSER} -d postgres" \
    --health-interval=1s \
    --health-timeout=5s \
    --health-retries=5 \
    postgres -N 1000

# 2. Wait for Postgres to be ready
# Now that we defined --health-cmd, this loop will work
until [ "$(docker inspect -f "{{.State.Health.Status}}" "${CONTAINER_NAME}")" == "healthy" ]; do
    >&2 echo "Postgres is still unavailable - sleeping"
    sleep 1
done

>&2 echo "Postgres is up and running on port ${DB_PORT}!"

# 3. Setup Application User and Database
APP_USER="${APP_USER:=app}"
APP_USER_PWD="${APP_USER_PWD:=secret}"
APP_DB_NAME="${APP_DB_NAME:=newsletter}"

# Create User
CREATE_USER_QUERY="CREATE USER ${APP_USER} WITH PASSWORD '${APP_USER_PWD}';"
docker exec "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -c "${CREATE_USER_QUERY}"

# Grant Permissions
GRANT_QUERY="ALTER USER ${APP_USER} CREATEDB;"
docker exec "${CONTAINER_NAME}" psql -U "${SUPERUSER}" -c "${GRANT_QUERY}"

>&2 echo "User ${APP_USER} created and granted CREATEDB permissions."

# 4. Create database using sqlx
DATABASE_URL=postgres://${APP_USER}:${APP_USER_PWD}@localhost:${DB_PORT}/${APP_DB_NAME}
export DATABASE_URL

>&2 echo "Creating database ${APP_DB_NAME} using sqlx..."
sqlx database create

>&2 echo "Database setup complete!"
>&2 echo "DATABASE_URL=${DATABASE_URL}"
