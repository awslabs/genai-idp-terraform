plugin "terraform" {
  enabled = true
  preset  = "recommended"
}

plugin "aws" {
  enabled = true
  version = "0.31.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

config {
  # Module inspection configuration
  call_module_type = "all"
}

# Core Terraform rules
rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

# Many resources in this module are gated by `count = var.enable_<x> ? 1 : 0`
# and reference IAM policy SIDs / ARNs that resolve to null at plan-time.
# The aws plugin's IAM-policy rules attempt to expand the policy JSON
# eagerly and crash with "expression result is null". Module-direct
# variables also intentionally include some pass-through interfaces that
# look unused at lint time. Disable just the offending rules so the rest
# of the AWS / Terraform ruleset still applies.
rule "terraform_unused_declarations" {
  enabled = false
}

rule "aws_iam_policy_sid_invalid_characters" {
  enabled = false
}

rule "aws_iam_policy_too_long_policy" {
  enabled = false
}

rule "aws_iam_policy_invalid_policy" {
  enabled = false
}

rule "aws_iam_role_policy_invalid_policy" {
  enabled = false
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = true
}

rule "terraform_naming_convention" {
  enabled = true
  format  = "snake_case"
}

rule "terraform_standard_module_structure" {
  enabled = true
}

rule "terraform_workspace_remote" {
  enabled = true
}
