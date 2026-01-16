# Variables
LUACHECK_CONFIG := .luacheckrc
STYLUA_CONFIG := .stylua.toml
LUACOV_CONFIG := .luacov
TEST_DIR := lua/neopilot/test
MINIMAL_INIT := scripts/tests/minimal.vim

# Default target
.DEFAULT_GOAL := help

# Help target to display available commands
.PHONY: help
help:
	@echo "NeoPilot Agent Development Commands"
	@echo ""
	@echo "Formatting:"
	@echo "  fmt           Format Lua code with stylua"
	@echo "  fmt-check     Check Lua code formatting without making changes"
	@echo ""
	@echo "Linting & Static Analysis:"
	@echo "  lint          Run luacheck for static code analysis"
	@echo ""
	@echo "Testing:"
	@echo "  test          Run all tests"
	@echo "  test-file     Run a specific test file (e.g., make test-file TEST=test_file_spec.lua)"
	@echo "  test-coverage Run tests with coverage report"
	@echo ""
	@echo "Development:"
	@echo "  clean         Clean temporary files"
	@echo "  deps          Install development dependencies"
	@echo "  pr-ready      Run all checks required before creating a PR"

# Formatting
.PHONY: fmt
fmt:
	@echo "===> Formatting Lua code"
	@stylua --config-path=$(STYLUA_CONFIG) lua/

.PHONY: fmt-check
fmt-check:
	@echo "===> Checking Lua code formatting"
	@stylua --config-path=$(STYLUA_CONFIG) --check lua/

# Linting
.PHONY: lint
lint:
	@echo "===> Running linter"
	@luacheck --config $(LUACHECK_CONFIG) lua/

# Testing
.PHONY: test
test:
	@echo "===> Running tests"
	@nvim --headless --noplugin -u $(MINIMAL_INIT) \
		-c "PlenaryBustedDirectory $(TEST_DIR) {minimal_init = '$(MINIMAL_INIT)}'"

.PHONY: test-file
test-file:
	@if [ -z "$(TEST)" ]; then \
		echo "Error: Please specify a test file with TEST=path/to/test.lua"; exit 1; \
	fi
	@echo "===> Running test: $(TEST)"
	@nvim --headless --noplugin -u $(MINIMAL_INIT) \
		-c "PlenaryBustedFile $(TEST) {minimal_init = '$(MINIMAL_INIT)}'"

.PHONY: test-coverage
test-coverage:
	@echo "===> Running tests with coverage"
	@rm -f luacov.*.out
	@LUACOV_CONFIG=$(LUACOV_CONFIG) nvim --headless --noplugin -u $(MINIMAL_INIT) \
		-c "lua require('plenary.busted').run('$(TEST_DIR)', {minimal_init = '$(MINIMAL_INIT)'})" \
		-c "lua os.exit()"
	@luacov
	@echo "Coverage report generated at luacov.report.html"

# Dependencies
.PHONY: deps
deps:
	@echo "===> Installing dependencies"
	@luarocks install luacheck
	@luarocks install stylua
	@luarocks install luacov

# Cleanup
.PHONY: clean
clean:
	@echo "===> Cleaning temporary files"
	@rm -f /tmp/lua_*
	@rm -f luacov.*.out
	@rm -f luacov.stats.out luacov.report.out luacov.report.html

# PR Ready
.PHONY: pr-ready
pr-ready: lint test fmt-check
	@echo ""
	@echo "✅  All checks passed! Ready for PR!"

# Aliases for backward compatibility
lua_fmt: fmt
lua_fmt_check: fmt-check
lua_lint: lint
lua_test: test
lua_clean: clean
