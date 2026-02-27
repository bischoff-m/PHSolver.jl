.PHONY: help format format-check format-diff test test-verbose docs-build docs-serve examples schema

help:
	@echo "Available targets:"
	@echo "  make docs-build   - Build the documentation"
	@echo "  make docs-serve   - Serve the documentation locally"
	@echo "  make format       - Format all Julia source files using jlfmt"
	@echo "  make format-check - Check if files are formatted without modifying them"
	@echo "  make format-diff  - Show diff of formatting changes"
	@echo "  make test         - Run tests"
	@echo "  make test-verbose - Run tests with verbose output"
	@echo "  make examples     - Run example scripts"
	@echo "  make schema       - Generate JSON schema"
	@echo "  make help         - Show this help message"

docs-build:
	julia --project=docs docs/make.jl

docs-serve:
	julia --project=docs -e 'using LiveServer; servedocs(port=8001)'

format:
	jlfmt --inplace -v src/

format-check:
	jlfmt --check -v src/

format-diff:
	jlfmt --diff src/

test:
	julia --project=. scripts/quiet_test.jl

test-verbose:
	julia --project=. -e 'using Pkg; Pkg.test()'

examples:
	julia --project=. scripts/examples.jl

schema:
	julia --project=. scripts/update_schema.jl