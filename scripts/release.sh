#!/usr/bin/env bash
# Tag a module release: <module>/v<semver>, e.g. vpc/v1.1.0. Consumers pin that tag:
#   source = "git::https://github.com/ravishekharg/terraform-module-library.git//modules/vpc?ref=vpc/v1.1.0"
# Refuses unless the version is valid semver, newer than the module's last tag, has a CHANGELOG
# entry, and the module's tests pass. Creates the tag locally; pushing it is a separate step.
#   bash scripts/release.sh vpc 1.1.0
set -euo pipefail
cd "$(dirname "$0")/.."
module=${1:?usage: release.sh <module> <version>}
version=${2:?usage: release.sh <module> <version>}
tag="$module/v$version"

[ -d "modules/$module" ] || { echo "no such module: modules/$module"; exit 1; }
[[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || { echo "version must be MAJOR.MINOR.PATCH"; exit 1; }
git rev-parse -q --verify "refs/tags/$tag" >/dev/null && { echo "$tag already exists"; exit 1; }
[ -z "$(git status --porcelain -- "modules/$module" CHANGELOG.md)" ] || { echo "commit modules/$module and CHANGELOG.md first"; exit 1; }

last=$(git tag -l "$module/v*" | sed "s|^$module/v||" | sort -V | tail -1)
if [ -n "$last" ] && [ "$(printf '%s\n%s\n' "$last" "$version" | sort -V | tail -1)" != "$version" ]; then
  echo "$version is not newer than the last release $last"; exit 1
fi
grep -q "^## $module $version" CHANGELOG.md || { echo "CHANGELOG.md has no '## $module $version' section"; exit 1; }

(cd "modules/$module" && terraform init -backend=false -input=false >/dev/null && terraform test >/dev/null) \
  || { echo "tests fail for $module"; exit 1; }

git tag -a "$tag" -m "$module $version"
echo "tagged $tag (previous: ${last:-none}). Push with: git push origin $tag"
