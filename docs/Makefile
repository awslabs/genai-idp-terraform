# Makefile for GenAI IDP Accelerator Documentation

.PHONY: help install serve build clean lint

# Default target
help:
	@echo "Available commands:"
	@echo "  install    Install documentation dependencies"
	@echo "  serve      Serve documentation locally"
	@echo "  build      Build documentation for production"
	@echo "  clean      Clean build artifacts"
	@echo "  lint       Lint documentation files"

# Install dependencies
install:
	pip install -r requirements.txt

# Serve documentation locally
serve:
	mkdocs serve -a 127.0.0.1:8000

# Build documentation
build:
	mkdocs build

# Clean build artifacts
clean:
	rm -rf site/
	find . -name "*.pyc" -delete
	find . -name "__pycache__" -delete

# Lint documentation
lint:
	# Check for broken links (requires linkchecker)
	@if command -v linkchecker >/dev/null 2>&1; then \
		mkdocs build && linkchecker site/; \
	else \
		echo "linkchecker not installed. Install with: pip install linkchecker"; \
	fi
	
	# Check markdown formatting (requires markdownlint)
	@if command -v markdownlint >/dev/null 2>&1; then \
		markdownlint content/; \
	else \
		echo "markdownlint not installed. Install with: npm install -g markdownlint-cli"; \
	fi

# Development server with auto-reload
dev:
	mkdocs serve -a 127.0.0.1:8000 --livereload

# Build and deploy (for CI/CD)
deploy:
	mkdocs gh-deploy --clean

# Check for broken internal links
check-links:
	@echo "Checking internal links..."
	@find content -name "*.md" -exec grep -l "\[.*\](.*\.md)" {} \; | while read file; do \
		echo "Checking $$file"; \
		grep -o "\[.*\](.*\.md)" "$$file" | sed 's/.*](\(.*\))/\1/' | while read link; do \
			if [ ! -f "content/$$link" ] && [ ! -f "$$link" ]; then \
				echo "  Broken link: $$link in $$file"; \
			fi; \
		done; \
	done

# Generate module documentation (requires terraform-docs)
generate-module-docs:
	@echo "Generating module documentation..."
	@if command -v terraform-docs >/dev/null 2>&1; then \
		find ../modules -name "*.tf" -exec dirname {} \; | sort -u | while read module; do \
			echo "Generating docs for $$module"; \
			terraform-docs markdown table "$$module" > "$$module/README.md"; \
		done; \
	else \
		echo "terraform-docs not installed. Install from: https://terraform-docs.io/user-guide/installation/"; \
	fi
