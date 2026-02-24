.PHONY: help init-db check-db start-db stop-db clean-db build run test install-sqlx db-url db-create migrate-add migrate-run migrate-revert

# Default values
DB_PORT ?= 5433
CONTAINER_NAME ?= postgres
SUPERUSER ?= postgres
APP_USER ?= app
APP_USER_PWD ?= secret
APP_DB_NAME ?= newsletter

# Database URL
DATABASE_URL := postgres://$(APP_USER):$(APP_USER_PWD)@localhost:$(DB_PORT)/$(APP_DB_NAME)
export DATABASE_URL

help:
	@echo "Available commands:"
	@echo ""
	@echo "Database Management:"
	@echo "  make init-db        - Initialize database (creates and starts container)"
	@echo "  make check-db       - Check database status"
	@echo "  make start-db       - Start existing database container"
	@echo "  make stop-db        - Stop database container"
	@echo "  make clean-db       - Remove database container and volume"
	@echo "  make db-url         - Display DATABASE_URL"
	@echo "  make db-create      - Create database using sqlx"
	@echo ""
	@echo "SQLx Commands:"
	@echo "  make install-sqlx              - Install sqlx-cli"
	@echo "  make migrate-add name=<NAME>   - Create a new migration"
	@echo "  make migrate-run               - Run pending migrations"
	@echo "  make migrate-revert            - Revert last migration"
	@echo ""
	@echo "Development:"
	@echo "  make build          - Build the Rust project"
	@echo "  make run            - Run the application"
	@echo "  make test           - Run tests"

# Check if database is initialized and running
check-db:
	@if docker ps -a --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
		if docker ps --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
			echo "✓ Database container '$(CONTAINER_NAME)' is running"; \
			if [ "$$(docker inspect -f '{{.State.Health.Status}}' $(CONTAINER_NAME) 2>/dev/null)" = "healthy" ]; then \
				echo "✓ Database is healthy"; \
			else \
				echo "⚠ Database is running but not healthy yet"; \
			fi; \
		else \
			echo "⚠ Database container '$(CONTAINER_NAME)' exists but is stopped"; \
		fi; \
	else \
		echo "✗ Database container '$(CONTAINER_NAME)' does not exist"; \
	fi

# Initialize database - runs init_db.sh only if container doesn't exist
init-db:
	@if docker ps -a --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
		echo "Database container '$(CONTAINER_NAME)' already exists."; \
		if docker ps --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
			echo "Container is already running."; \
		else \
			echo "Starting existing container..."; \
			docker start $(CONTAINER_NAME); \
		fi; \
	else \
		echo "Initializing new database..."; \
		./scripts/init_db.sh; \
	fi

# Start the database container if it exists but is stopped
start-db:
	@if docker ps -a --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
		if docker ps --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
			echo "Database is already running"; \
		else \
			echo "Starting database container..."; \
			docker start $(CONTAINER_NAME); \
			echo "Waiting for database to be healthy..."; \
			until [ "$$(docker inspect -f '{{.State.Health.Status}}' $(CONTAINER_NAME) 2>/dev/null)" = "healthy" ]; do \
				echo "Waiting..."; \
				sleep 1; \
			done; \
			echo "✓ Database is ready!"; \
		fi; \
	else \
		echo "Error: Database container does not exist. Run 'make init-db' first."; \
		exit 1; \
	fi

# Stop the database container
stop-db:
	@if docker ps --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
		echo "Stopping database container..."; \
		docker stop $(CONTAINER_NAME); \
	else \
		echo "Database container is not running"; \
	fi

# Remove the database container and volume (clean slate)
clean-db:
	@if docker ps -a --format '{{.Names}}' | grep -q "^$(CONTAINER_NAME)$$"; then \
		echo "Removing database container..."; \
		docker rm -f $(CONTAINER_NAME); \
		echo "Database container removed"; \
	else \
		echo "No database container to remove"; \
	fi

# Build the Rust project
build:
	cargo build

# Run the application (ensures database is running first)
run: init-db
	cargo run

# Run tests (ensures database is running first)
test: init-db
	cargo test

# Install sqlx-cli
install-sqlx:
	@if command -v sqlx > /dev/null 2>&1; then \
		echo "sqlx-cli is already installed"; \
		sqlx --version; \
	else \
		echo "Installing sqlx-cli..."; \
		cargo install --version='~0.8' sqlx-cli \
		--no-default-features --features rustls,postgres; \
	fi

# Display DATABASE_URL
db-url:
	@echo "DATABASE_URL=$(DATABASE_URL)"

# Create database using sqlx
db-create: start-db
	@echo "Creating database $(APP_DB_NAME)..."
	sqlx database create
	@echo "✓ Database created successfully!"

# Create a new migration
migrate-add:
	@if [ -z "$(name)" ]; then \
		echo "Error: Migration name is required."; \
		echo "Usage: make migrate-add name=<migration_name>"; \
		echo "Example: make migrate-add name=create_subscriptions_table"; \
		exit 1; \
	fi
	@echo "Creating migration: $(name)"
	sqlx migrate add $(name)

# Run pending migrations
migrate-run: db-create
	@echo "Running migrations..."
	sqlx migrate run

# Revert last migration
migrate-revert: db-create
	@echo "Reverting last migration..."
	sqlx migrate revert
