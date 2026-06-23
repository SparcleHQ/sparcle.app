#!/usr/bin/env bash
# sync-docs.sh — build-time sync of utility-manifest docs from bolt-api → sparcle.app
#
# Single source of truth is bolt-api. This script pulls three artifacts into
# the Astro site so the gallery + spec pages render fresh content at build:
#
#   1. docs/UTILITY_MANIFEST.md           → src/content/utility-manifest-spec.md
#   2. config/utilities/builtin/*/manifest.yaml
#                                          → public/docs/utilities/samples/{name}.yaml
#   3. (generated) sample index            → src/data/utility-samples.json
#
# Re-runnable. Cleans the destination sample dir before copying so deletions in
# bolt-api propagate. Skips anything under .claude/worktrees/. Uses yq if
# available, falls back to grep/sed for the small set of top-level scalar
# fields the index needs.
#
# Wired into npm prebuild + the Makefile `sync-docs` target.

set -euo pipefail

SRC_REPO="/Users/rajendrapatil/dev/bolt-api"
DST_REPO="/Users/rajendrapatil/dev/sparcle.app"

SRC_SPEC="${SRC_REPO}/docs/UTILITY_MANIFEST.md"
SRC_MANIFESTS_DIR="${SRC_REPO}/config/utilities/builtin"

DST_SPEC="${DST_REPO}/src/content/utility-manifest-spec.md"
DST_SAMPLES_DIR="${DST_REPO}/public/docs/utilities/samples"
DST_INDEX="${DST_REPO}/src/data/utility-samples.json"

# --- pre-flight ----------------------------------------------------------------
# In environments where bolt-api isn't checked out alongside (Cloudflare Pages
# build container, CI runners that only clone this repo, contributors who don't
# have bolt-api locally), skip the sync and trust the pre-synced artifacts that
# are already committed to this repo. The script must exit 0 here, not 1 —
# `set -e` + non-zero exit from a prebuild step kills the entire `astro build`
# and Cloudflare serves the previous successful deploy indefinitely.
if [[ ! -f "${SRC_SPEC}" || ! -d "${SRC_MANIFESTS_DIR}" ]]; then
  echo "sync-docs: source repo not present (${SRC_REPO}); using committed snapshot of"
  echo "  src/content/utility-manifest-spec.md + public/docs/utilities/samples/*.yaml +"
  echo "  src/data/utility-samples.json. Run from a checkout with bolt-api alongside"
  echo "  to refresh."
  exit 0
fi

mkdir -p "$(dirname "${DST_SPEC}")"
mkdir -p "$(dirname "${DST_INDEX}")"
mkdir -p "${DST_SAMPLES_DIR}"

# --- 1. spec markdown ----------------------------------------------------------
# Source uses bolt-api's repo-relative paths like `examples/utility-jira.yaml`,
# but the site serves samples at `/docs/utilities/samples/jira.yaml` (no
# `utility-` prefix). Rewrite during sync so deep links work.
{
  printf '%s\n' '<!--'
  printf '%s\n' '  synced from bolt-api/docs/UTILITY_MANIFEST.md by scripts/sync-docs.sh'
  printf '%s\n' '  do not edit by hand — edits will be overwritten on next build'
  printf '%s\n' '-->'
  sed -E \
    -e 's#\(examples/utility-([a-z0-9-]+)\.yaml\)#(/docs/utilities/samples/\1.yaml)#g' \
    -e 's#\[examples/utility-([a-z0-9-]+)\.yaml\]#[samples/\1.yaml]#g' \
    "${SRC_SPEC}"
} > "${DST_SPEC}"

# --- 2. manifest YAML samples --------------------------------------------------
# Clean destination so removed manifests don't linger.
rm -f "${DST_SAMPLES_DIR}"/*.yaml

# Helper: extract a top-level scalar field from a YAML file.
# Prefers yq when present; falls back to a grep/sed that handles
# `key: value`, `key: "value"`, and `key: 'value'`.
have_yq=0
if command -v yq >/dev/null 2>&1; then
  have_yq=1
fi

extract_field() {
  local file="$1" key="$2" val=""
  if [[ "${have_yq}" -eq 1 ]]; then
    val="$(yq -r ".${key} // \"\"" "${file}" 2>/dev/null || true)"
    if [[ "${val}" == "null" ]]; then val=""; fi
  fi
  if [[ -z "${val}" ]]; then
    # First matching top-level (column-zero) scalar key.
    # Strip the `key:` prefix; trim a trailing ` #comment` (YAML requires whitespace
    # before `#` for an inline comment, so naked `#` inside the value survives —
    # e.g. github's `owner/repo#N`). Then unwrap matching outer quotes.
    val="$(grep -m1 -E "^${key}:[[:space:]]" "${file}" 2>/dev/null \
      | sed -E "s/^${key}:[[:space:]]*//; s/[[:space:]]+#.*$//; s/[[:space:]]+$//; s/^\"(.*)\"$/\1/; s/^'(.*)'$/\1/" \
      || true)"
  fi
  printf '%s' "${val}"
}

# Escape a string for safe embedding inside a JSON double-quoted scalar.
json_escape() {
  local s="$1"
  s="${s//\\/\\\\}"   # backslash first
  s="${s//\"/\\\"}"   # double quote
  s="${s//$'\t'/\\t}"
  s="${s//$'\r'/}"
  s="${s//$'\n'/\\n}"
  printf '%s' "${s}"
}

samples_copied=0
parse_failures=()
index_entries=()

# Iterate dirs (sorted, deterministic). Skip anything under .claude/worktrees/.
while IFS= read -r dir; do
  case "${dir}" in
    *"/.claude/worktrees/"*) continue ;;
  esac
  name="$(basename "${dir}")"
  manifest="${dir}/manifest.yaml"
  [[ -f "${manifest}" ]] || continue

  # Copy raw YAML.
  cp "${manifest}" "${DST_SAMPLES_DIR}/${name}.yaml"

  # Pull index fields.
  id="$(extract_field "${manifest}" id)"
  title="$(extract_field "${manifest}" title)"
  chip="$(extract_field "${manifest}" chip)"
  description="$(extract_field "${manifest}" description)"
  emits="$(extract_field "${manifest}" emits)"

  if [[ -z "${id}" || -z "${title}" || -z "${chip}" ]]; then
    parse_failures+=("${name} (missing one of id/title/chip)")
    rm -f "${DST_SAMPLES_DIR}/${name}.yaml"
    continue
  fi

  index_entries+=("$(printf '  {"id": "%s", "title": "%s", "chip": "%s", "description": "%s", "emits": "%s", "tier": "admin", "filename": "%s.yaml"}' \
    "$(json_escape "${id}")" \
    "$(json_escape "${title}")" \
    "$(json_escape "${chip}")" \
    "$(json_escape "${description}")" \
    "$(json_escape "${emits}")" \
    "$(json_escape "${name}")")")
  samples_copied=$((samples_copied + 1))
done < <(find "${SRC_MANIFESTS_DIR}" -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort)

# --- 2b. user-app samples (bolt-native) ---------------------------------------
# User Apps (runtime: bridge | http_local | transform) live in bolt-native's
# sample-user-utils dir as flat YAML files — not in bolt-api's builtin tree — so
# pull them too. This surfaces the user-authorable tier (including the pure
# `transform` packs) in the gallery next to the admin connectors. Each entry is
# tagged `tier: user` (+ its `runtime`) so the gallery can group them.
SRC_USER_SAMPLES_DIR="/Users/rajendrapatil/dev/bolt-native/src-tauri/resources/sample-user-utils"
user_samples_copied=0
if [[ -d "${SRC_USER_SAMPLES_DIR}" ]]; then
  while IFS= read -r manifest; do
    name="$(basename "${manifest}" .yaml)"
    # Never clobber an admin sample of the same basename (admin wins).
    if [[ -f "${DST_SAMPLES_DIR}/${name}.yaml" ]]; then
      parse_failures+=("${name} (user-app name collides with an admin sample — skipped)")
      continue
    fi
    id="$(extract_field "${manifest}" id)"
    title="$(extract_field "${manifest}" title)"
    chip="$(extract_field "${manifest}" chip)"
    description="$(extract_field "${manifest}" description)"
    emits="$(extract_field "${manifest}" emits)"
    runtime="$(extract_field "${manifest}" runtime)"
    if [[ -z "${id}" || -z "${title}" || -z "${chip}" ]]; then
      parse_failures+=("${name} (missing one of id/title/chip)")
      continue
    fi
    cp "${manifest}" "${DST_SAMPLES_DIR}/${name}.yaml"
    # User-App chips are bare keys; show them with the launcher's leading '='.
    index_entries+=("$(printf '  {"id": "%s", "title": "%s", "chip": "=%s", "description": "%s", "emits": "%s", "runtime": "%s", "tier": "user", "filename": "%s.yaml"}' \
      "$(json_escape "${id}")" \
      "$(json_escape "${title}")" \
      "$(json_escape "${chip}")" \
      "$(json_escape "${description}")" \
      "$(json_escape "${emits}")" \
      "$(json_escape "${runtime}")" \
      "$(json_escape "${name}")")")
    user_samples_copied=$((user_samples_copied + 1))
  done < <(find "${SRC_USER_SAMPLES_DIR}" -maxdepth 1 -name '*.yaml' | LC_ALL=C sort)
fi

# --- 3. samples index JSON -----------------------------------------------------
{
  printf '[\n'
  if [[ "${#index_entries[@]}" -gt 0 ]]; then
    last=$((${#index_entries[@]} - 1))
    for i in "${!index_entries[@]}"; do
      if [[ "${i}" -eq "${last}" ]]; then
        printf '%s\n' "${index_entries[$i]}"
      else
        printf '%s,\n' "${index_entries[$i]}"
      fi
    done
  fi
  printf ']\n'
} > "${DST_INDEX}"

# --- summary -------------------------------------------------------------------
if [[ "${#parse_failures[@]}" -gt 0 ]]; then
  echo "parse failures:" >&2
  for f in "${parse_failures[@]}"; do echo "  - ${f}" >&2; done
fi

echo "synced 1 spec + ${samples_copied} admin + ${user_samples_copied:-0} user-app samples"
