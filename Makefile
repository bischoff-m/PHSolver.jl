.PHONY: format format-check format-diff test test-verbose help

help:
	@echo "Available targets:"
	@echo "  make format       - Format all Julia source files using jlfmt"
	@echo "  make format-check - Check if files are formatted without modifying them"
	@echo "  make format-diff  - Show diff of formatting changes"
	@echo "  make test         - Run tests"
	@echo "  make test-verbose - Run tests with verbose output"
	@echo "  make help         - Show this help message"

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
