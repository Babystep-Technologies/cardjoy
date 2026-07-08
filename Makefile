# Cardjoy developer shortcuts. Everything runs inside Docker — no local Ruby/Node needed.
# Run `make` (or `make help`) to see the available targets.

COMPOSE := docker compose

.DEFAULT_GOAL := help

# ANSI-clean, self-documenting help: any target with a `## comment` is listed.
.PHONY: help
help: ## Show this help
	@echo "Cardjoy — make targets:"
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) \
		| sort \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'

.PHONY: setup
setup: up wait-db env deps db ## First-time setup: build, start, seed — then run `make dev`
	@echo ""
	@echo "✅ Setup complete. Start the app with:  make dev"

.PHONY: up
up: ## Start the containers (db, redis, api, web, admin) in the background
	$(COMPOSE) up -d

.PHONY: down
down: ## Stop and remove the containers
	$(COMPOSE) down

.PHONY: restart
restart: down up ## Restart the containers

.PHONY: wait-db
wait-db: ## Wait until Postgres is ready to accept connections
	@echo "⏳ Waiting for Postgres..."
	@until $(COMPOSE) exec -T db pg_isready -U postgres >/dev/null 2>&1; do sleep 1; done
	@echo "✅ Postgres is ready."

.PHONY: env
env: ## Create .env.development files from the examples if missing
	@test -f web/.env.development   || cp web/.env.example   web/.env.development   && echo "web/.env.development ready"
	@test -f admin/.env.development || cp admin/.env.example admin/.env.development && echo "admin/.env.development ready"

.PHONY: deps
deps: ## Install frontend dependencies (web + admin)
	$(COMPOSE) exec -T web   yarn install --frozen-lockfile
	$(COMPOSE) exec -T admin yarn install --frozen-lockfile

.PHONY: db
db: ## Create/migrate the database and load seed data (styles, etc.)
	$(COMPOSE) exec -T api ./bin/rails db:prepare
	$(COMPOSE) exec -T api ./bin/rails db:seed

.PHONY: seed
seed: ## (Re)load seed data only
	$(COMPOSE) exec -T api ./bin/rails db:seed

.PHONY: dev
dev: up ## Start the dev servers (api :3000, web :3001, admin :3002) in the background
	@$(COMPOSE) exec -T api sh -c 'rm -f tmp/pids/server.pid'
	$(COMPOSE) exec -d api   sh -c './bin/server > /proc/1/fd/1 2>&1'
	$(COMPOSE) exec -d web   sh -c 'yarn dev      > /proc/1/fd/1 2>&1'
	$(COMPOSE) exec -d admin sh -c 'yarn dev      > /proc/1/fd/1 2>&1'
	@echo ""
	@echo "🚀 Dev servers starting:"
	@echo "   Web (consumer): http://localhost:3001"
	@echo "   Admin:          http://localhost:3002"
	@echo "   API (GraphQL):  http://localhost:3000/graphql"
	@echo ""
	@echo "   Follow logs with:  make logs"

.PHONY: logs
logs: ## Follow the api/web/admin server logs
	$(COMPOSE) logs -f api web admin

.PHONY: console
console: ## Open a Rails console
	$(COMPOSE) exec api ./bin/rails console

.PHONY: test
test: ## Run the backend test suite (RSpec)
	$(COMPOSE) exec -T api bundle exec rspec

.PHONY: lint
lint: ## Run all linters/formatters/type checks (api + web + admin)
	$(COMPOSE) exec -T api bundle exec rubocop
	$(COMPOSE) exec -T api bundle exec srb tc
	$(COMPOSE) exec -T web   yarn lint
	$(COMPOSE) exec -T web   yarn format-check
	$(COMPOSE) exec -T admin yarn lint
	$(COMPOSE) exec -T admin yarn format-check

.PHONY: build
build: ## Type-check and build the frontends (mirrors CI)
	$(COMPOSE) exec -T web   yarn build
	$(COMPOSE) exec -T admin yarn build

.PHONY: check
check: test lint build ## Run every quality gate (test + lint + build) — run before opening a PR
	@echo "✅ All checks passed."
