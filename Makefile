project_name = workero

DUNE = opam exec -- dune

.PHONY: help
help: ## Print this help message
	@echo "";
	@echo "List of available make commands";
	@echo "";
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2}';
	@echo "";

.PHONY: build
build: ## Build the library, the CLI and the examples
	$(DUNE) build

.PHONY: dev
dev: ## Build in watch mode
	$(DUNE) build -w

.PHONY: test
test: test-unit test-worker ## Run the unit tests and the worker tests

.PHONY: test-unit
test-unit: ## Run the alcotest unit tests (node)
	$(DUNE) test

.PHONY: test-worker
test-worker: ## Build test/worker with workero and run test/worker/tests.mjs in workerd
	DUNE="$(DUNE)" test/worker/run.sh

.PHONY: fmt
fmt: ## Format the code
	$(DUNE) build @fmt --auto-promote

.PHONY: example
example: ## Build examples/basic into _worker/
	$(DUNE) exec workero -- build examples/basic/main

.PHONY: docs
docs: ## Build the HTML and Markdown docs; copy the Markdown to docs/
	$(DUNE) build --cache=disabled @doc @doc-markdown
	rm -rf docs
	mkdir docs
	cp _build/default/_doc/_markdown/index.md docs/
	for p in $(basename $(wildcard *.opam)); do cp -R _build/default/_doc/_markdown/$$p docs/; done
	chmod -R u+w docs

.PHONY: clean
clean: ## Clean artifacts
	$(DUNE) clean
	rm -rf _worker _worker-test
