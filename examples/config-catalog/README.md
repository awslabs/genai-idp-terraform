# Config catalog

Drop-in folder for extra document-processing configuration versions. Each YAML
here can be seeded as an additional, editable configuration version that shows
up in the web UI's Configuration Version dropdown next to the default.

The YAML files in this folder are gitignored (only this README and `.gitkeep`
are tracked), so your configs stay local and are never committed. If you want to
version-control your configs instead, drop the `examples/config-catalog/*.yaml`
rule from the repo `.gitignore` and they will be tracked like any other file.

## How to wire configs

1. Add a YAML config file to this folder, for example `invoices.yaml`. Anything
   not set inherits from the system defaults, so a sparse file is fine.

2. List it in the processor example's `terraform.tfvars` under
   `additional_config_files`, as `version_name => path`:

   ```hcl
   additional_config_files = {
     invoices = "../config-catalog/invoices.yaml"
     receipts = "../config-catalog/receipts.yaml"
   }
   ```

   The map key is the version name shown in the UI; the value is the path to the
   YAML, relative to the example directory (or absolute). `.tfvars` cannot call
   `yamldecode`/`file`, so the example resolves the path for you.

3. Run `terraform apply`. Each entry is seeded as a non-active, editable version
   (`Managed = false`), selectable in the UI and editable like a "Save as
   Version" copy.

Supported by all three processor examples: `bedrock-llm-processor`,
`bda-processor`, and `sagemaker-udop-processor`.

## Notes

- The active/default version still comes from the processor's `config`
  (`config_file_path`); `additional_config_files` only adds extra versions.
- Version names must be unique. A name of `default` or one matching a managed
  baseline (`fake-w2`, `docsplit`, `ocr-benchmark`, `realkie-fcc-verified`) is
  ignored so it cannot overwrite those rows.
- Removing an entry stops Terraform from managing that version but does NOT
  delete the already-seeded version from the configuration table. Delete it from
  the UI if you no longer want it.
