#!/usr/bin/env bash
# Proves semver_check.py on real Terraform: copies modules/s3-bucket, makes one kind of change to the copy, and
# checks the bump that terraform-docs + semver_check derive from it. Runs in CI (needs Docker or terraform-docs).
set -euo pipefail
cd "$(dirname "$0")/.."
work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
pass=0 fail=0

# --- the edits, each applied to a fresh copy (current directory = the copy) ---
no_change() { :; }
reword_description() { sed -i 's/Bucket ARN\./The bucket ARN./' outputs.tf; }
add_optional_input() {
  cat >> variables.tf <<'HCL'

variable "object_lock" {
  description = "Enable S3 Object Lock."
  type        = bool
  default     = false
}
HCL
}
add_output() {
  cat >> outputs.tf <<'HCL'

output "bucket_domain_name" {
  description = "Bucket domain name."
  value       = aws_s3_bucket.this.bucket_domain_name
}
HCL
}
remove_output() {
  python - <<'PY'
import pathlib, re
p = pathlib.Path("outputs.tf")
p.write_text(re.sub(r'output "regional_domain_name" \{.*?\n\}\n', "", p.read_text(), flags=re.DOTALL))
PY
}
change_default() { sed -i '/variable "force_destroy"/,/^}/ s/default     = false/default     = true/' variables.tf; }
rename_resource() {
  sed -i 's/resource "aws_s3_bucket_policy" "this"/resource "aws_s3_bucket_policy" "tls_only"/; s/aws_s3_bucket_policy\.this/aws_s3_bucket_policy.tls_only/g' main.tf
}
rename_resource_with_moved() {
  rename_resource
  printf '\nmoved {\n  from = aws_s3_bucket_policy.this\n  to   = aws_s3_bucket_policy.tls_only\n}\n' >> main.tf
}
raise_provider_minimum() { sed -i 's/version = ">= 5.70, < 7.0"/version = ">= 6.0, < 7.0"/' versions.tf; }

expect() {   # expect <expected level> <edit function>
  local want=$1 edit=$2 got
  rm -rf "$work/head" && cp -r modules/s3-bucket "$work/head"
  (cd "$work/head" && "$edit")
  if [ "$edit" != no_change ] && diff -rq modules/s3-bucket "$work/head" > /dev/null; then
    echo "FAIL $edit: the edit changed nothing (stale test)"; fail=$((fail + 1)); return
  fi
  got=$(python scripts/semver_check.py --json --base-dir modules/s3-bucket --head-dir "$work/head" \
        | python -c 'import json, sys; print(json.load(sys.stdin)["level"])')
  if [ "$got" = "$want" ]; then echo "PASS $edit -> $got"; pass=$((pass + 1))
  else echo "FAIL $edit -> $got (expected $want)"; fail=$((fail + 1)); fi
}

expect none no_change
expect patch reword_description
expect minor add_optional_input
expect minor add_output
expect major remove_output
expect major change_default
expect major rename_resource
expect patch rename_resource_with_moved
expect major raise_provider_minimum

echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
