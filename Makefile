# Makefile for GenAI IDP Accelerator Terraform
# Based on AWS IA Terraform standards

.PHONY: help install-tools fmt validate lint security docs test clean all

# Default target
help: ## Show this help message
	@echo "GenAI IDP Accelerator - Terraform Development Commands"
	@echo "====================================================="
	@echo ""
	@echo "Available targets:"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / {printf "  %-20s %s\n", $$1, $$2}' $(MAKEFILE_LIST)
	@echo ""
	@echo "Examples:"
	@echo "  make install-tools  # Install all required tools"
	@echo "  make all           # Run all validation checks"
	@echo "  make fmt           # Format all Terraform files"
	@echo "  make test          # Run all tests"

# Tool installation
install-tools: ## Install required development tools
	@echo "Installing development tools..."
	@command -v terraform >/dev/null 2>&1 || { echo "Please install Terraform: https://www.terraform.io/downloads"; exit 1; }
	@command -v tflint >/dev/null 2>&1 || { echo "Installing tflint..."; curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash; }
	@command -v tfsec >/dev/null 2>&1 || { echo "Installing tfsec..."; curl -s https://raw.githubusercontent.com/aquasecurity/tfsec/master/scripts/install_linux.sh | sh; }
	@command -v terraform-docs >/dev/null 2>&1 || { echo "Installing terraform-docs..."; curl -sSLo terraform-docs.tar.gz https://terraform-docs.io/dl/v0.17.0/terraform-docs-v0.17.0-$$(uname)-amd64.tar.gz && tar -xzf terraform-docs.tar.gz && sudo mv terraform-docs /usr/local/bin/ && rm terraform-docs.tar.gz; }
	@command -v pre-commit >/dev/null 2>&1 || { echo "Installing pre-commit..."; pip install pre-commit; }
	@echo "✅ All tools installed successfully"

# Pre-commit setup
setup-pre-commit: ## Setup pre-commit hooks
	@echo "Setting up pre-commit hooks..."
	@pre-commit install
	@pre-commit install --hook-type commit-msg
	@echo "✅ Pre-commit hooks installed"

# Terraform formatting
fmt: ## Format all Terraform files
	@echo "Formatting Terraform files..."
	@terraform fmt -recursive .
	@echo "✅ Terraform files formatted"

# Terraform validation
validate: ## Validate all Terraform configurations
	@echo "Validating Terraform configurations in modules..."
	@for dir in modules/*/; do \
		if [ -f "$$dir/main.tf" ] || [ -f "$$dir/versions.tf" ]; then \
			echo "Validating $$dir"; \
			cd "$$dir" && terraform init -backend=false && terraform validate && cd - > /dev/null; \
		fi; \
	done
	@echo "✅ All Terraform module configurations are valid"

# TFLint
lint: ## Run TFLint on all Terraform files
	@echo "Running TFLint on modules..."
	@tflint --init
	@for dir in modules/*/; do \
		if [ -f "$$dir/main.tf" ] || [ -f "$$dir/versions.tf" ]; then \
			echo "Linting $$dir"; \
			cd "$$dir" && tflint --config="$(PWD)/.tflint.hcl" && cd - > /dev/null; \
		fi; \
	done
	@echo "✅ TFLint checks completed"

# TFSec security scanning
security: ## Run TFSec security scan
	@echo "Running TFSec security scan (excluding examples/ and sources/)..."
	@tfsec . --config-file .tfsec/config.yml
	@echo "✅ Security scan completed"

# Generate documentation
docs: ## Generate Terraform documentation
	@echo "Generating Terraform documentation for modules..."
	@for dir in modules/*/; do \
		if [ -f "$$dir/main.tf" ]; then \
			echo "Generating docs for $$dir"; \
			cd "$$dir" && terraform-docs markdown table . > README.md && cd - > /dev/null; \
		fi; \
	done
	@echo "✅ Documentation generated"

# Run all tests
test: fmt validate lint security ## Run all validation tests
	@echo "✅ All tests passed!"

# Clean temporary files
clean: ## Clean temporary files and directories
	@echo "Cleaning temporary files..."
	@find . -type d -name ".terraform" -exec rm -rf {} + 2>/dev/null || true
	@find . -name "*.tfplan" -delete 2>/dev/null || true
	@find . -name "*.tfstate*" -delete 2>/dev/null || true
	@find . -name ".terraform.lock.hcl" -delete 2>/dev/null || true
	@echo "✅ Cleanup completed"

# Clean untracked files with exclusions
clean-soft: ## Clean untracked files while preserving important patterns
	@echo "Cleaning untracked files (preserving important patterns)..."
	@git clean -fdn -e "*.tfvars" -e ".terraform/" -e "*.tfstate*" -e ".terraform.lock.hcl"
	@echo ""
	@echo "⚠️  This is a dry run. To actually delete these files, run:"
	@echo "    git clean -fd -e \"*.tfvars\" -e \".terraform/\" -e \"*.tfstate*\" -e \".terraform.lock.hcl\""
	@echo ""
	@echo "Or use:"
	@echo "    make clean-soft-force"
	@echo ""

clean-soft-force: ## Force clean untracked files while preserving important patterns
	@echo "Force cleaning untracked files (preserving important patterns)..."
	@git clean -fd -e "*.tfvars" -e ".terraform/" -e "*.tfstate*" -e ".terraform.lock.hcl"
	@echo "✅ Soft cleanup completed"

# Run all checks (CI equivalent)
all: fmt validate lint security docs ## Run all checks (equivalent to CI pipeline)
	@echo "🎉 All quality checks passed! Ready for merge."

# Check specific module
check-module: ## Check specific module (usage: make check-module MODULE=modules/web-ui)
	@if [ -z "$(MODULE)" ]; then echo "Usage: make check-module MODULE=modules/web-ui"; exit 1; fi
	@echo "Checking module: $(MODULE)"
	@cd "$(MODULE)" && terraform fmt -check
	@cd "$(MODULE)" && terraform init -backend=false && terraform validate
	@cd "$(MODULE)" && tflint --config="$(PWD)/.tflint.hcl"
	@tfsec "$(MODULE)" --config-file .tfsec/config.yml
	@echo "✅ Module $(MODULE) passed all checks"

# Check specific example
check-example: ## Check specific example (usage: make check-example EXAMPLE=examples/bedrock-llm-processor)
	@if [ -z "$(EXAMPLE)" ]; then echo "Usage: make check-example EXAMPLE=examples/bedrock-llm-processor"; exit 1; fi
	@echo "Checking example: $(EXAMPLE)"
	@cd "$(EXAMPLE)" && terraform fmt -check
	@cd "$(EXAMPLE)" && terraform init -backend=false && terraform validate
	@cd "$(EXAMPLE)" && tflint --config="$(PWD)/.tflint.hcl"
	@tfsec "$(EXAMPLE)" --config-file .tfsec/config.yml
	@echo "✅ Example $(EXAMPLE) passed all checks"

# Initialize new module
init-module: ## Initialize new module structure (usage: make init-module MODULE=my-new-module)
	@if [ -z "$(MODULE)" ]; then echo "Usage: make init-module MODULE=my-new-module"; exit 1; fi
	@echo "Creating new module: modules/$(MODULE)"
	@mkdir -p "modules/$(MODULE)"
	@echo "# $(MODULE) Module\n\nTODO: Add module description\n\n## Usage\n\n\`\`\`hcl\nmodule \"$(MODULE)\" {\n  source = \"./modules/$(MODULE)\"\n  # Add variables here\n}\n\`\`\`" > "modules/$(MODULE)/README.md"
	@touch "modules/$(MODULE)/main.tf"
	@touch "modules/$(MODULE)/variables.tf"
	@touch "modules/$(MODULE)/outputs.tf"
	@touch "modules/$(MODULE)/versions.tf"
	@echo "✅ Module modules/$(MODULE) created successfully"

# Show current status
status: ## Show current repository status
	@echo "Repository Status"
	@echo "================="
	@echo "Branch: $$(git branch --show-current)"
	@echo "Terraform version: $$(terraform version -json | jq -r '.terraform_version')"
	@echo "TFLint version: $$(tflint --version | head -n1)"
	@echo "TFSec version: $$(tfsec --version | head -n1)"
	@echo ""
	@echo "Modules:"
	@find modules -name "main.tf" -exec dirname {} \; | sort
	@echo ""
	@echo "Examples:"
	@find examples -name "main.tf" -exec dirname {} \; | sort
