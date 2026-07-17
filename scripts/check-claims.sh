#!/usr/bin/env bash
# Fails the build if a claim we cannot defend against live code reappears
# anywhere in the site or the decks.
#
# WHY THIS EXISTS
# ---------------
# The persona decks are 18 hand-maintained HTML files with byte-identical
# shared slides and no generator, so one sentence lives in up to 12 copies.
# On 2026-07-15 a copy sweep fixed the masking headlines and still missed the
# card headings and closing lines in 8 more files — not carelessness, just what
# happens when a rule has no owner. This script is that owner: the files stay
# forked (converging the deck pipeline is a separate job), but the RULE lives
# in exactly one place and the build enforces it.
#
# Every entry cites the code that makes the claim false. Before removing one,
# re-read the evidence and confirm the code changed — do not "fix" the guard.
# Companion: ~/private/Sparcle-LLC/verify-claims.sh proves the CAN-CLAIM side
# against bolt-api; this proves the DO-NOT-SAY side against the website.
#
# Usage: ./scripts/check-claims.sh   (runs in prebuild; exit 1 = a banned claim)

set -uo pipefail
cd "$(dirname "$0")/.."

fail=0

# ban <"phrase"> <"why it is false + the evidence"> [grep-flags]
ban() {
  local phrase="$1" why="$2"
  local hits
  hits=$(grep -ril --exclude-dir=legacy -- "$phrase" public/decks src/pages src/fragments 2>/dev/null || true)
  if [ -n "$hits" ]; then
    echo "BANNED CLAIM: \"$phrase\""
    echo "  why: $why"
    echo "$hits" | sed 's/^/    /'
    echo
    fail=1
  fi
}

# --- Absolutist no-egress -------------------------------------------------
# False the moment a customer selects a public LLM, which the same decks sell
# as a feature. The defensible claim is already in the body copy underneath:
# "No Sparcle server sits in the path" (verify-claims.sh: no-hosted-saas).
ban "Data never leaves your boundary" \
    "false on any public-LLM path; say \"You define the boundary\""
ban "nothing leaves your boundary" \
    "false on any public-LLM path; say \"you define the boundary\""
ban "Leak nothing" \
    "unqualified no-egress guarantee; say \"keep the identifiers yours\""

# --- Absolute masking / recall -------------------------------------------
# bolt-api config.rs GlinerConfig: name detection is an HTTP SIDECAR whose
# `endpoint` defaults to empty, and `fail_mode: open` "returns the text
# unchanged" when unreachable. Recall is not 100% and names are not on by
# default, so no "never"/"100% masked" guarantee is defensible.
ban "the model never does" \
    "NER is a BYO sidecar (GlinerConfig.endpoint defaults empty); say \"the model sees a token\""
ban "never reach the model" \
    "sub-100% recall; say \"detected identifiers are tokenized before the model\""
ban "never reaches the model" \
    "sub-100% recall; say \"routed through masking before the model\""

# --- Hosted path ----------------------------------------------------------
# No hosted Bolt exists; it is the moat, not a gap (verify-claims.sh:
# no-hosted-saas, and subprocessor-disclosure.md says so verbatim).
ban "yours or ours" \
    "implies a hosted Sparcle model path that does not exist; say \"yours\""

# --- Vector / semantic search --------------------------------------------
# bolt-api config.rs EpisodicEmbeddingConfig: "enabled = false (the default)
# keeps recall on the classic entity/keyword/recency ranking — exactly the
# behavior with no embedder."
ban "keyword-plus-vector" \
    "vector signal is off by default; say \"keyword and entity-overlap\""

# --- MCP transport --------------------------------------------------------
# bolt-api providers/mcp/discovery.rs McpTransportType has StreamableHttp,
# LegacySse, CustomRest, Unknown — there is NO stdio variant.
ban "connect any MCP server" \
    "MCP is HTTP-only (no stdio transport); say \"connect any HTTP MCP server\""

# --- Instant compliance ---------------------------------------------------
# 28 packs ship, 6 enabled by default; GovernanceProfile::Standard leaves the
# PDP inert ("byte-identical to pre-governance Bolt") and even Regulated only
# resolves config — enforcement wiring is explicitly a follow-up.
ban "Day 1 compliance" \
    "PDP is inert by default and 22/28 packs are opt-in; say \"configurable compliance policy packs\""
ban "Compliance readiness" \
    "same as above; say \"configurable compliance policy packs\""

if [ "$fail" -ne 0 ]; then
  echo "check-claims: FAILED — the copy above outruns what the code does."
  echo "If a claim became TRUE, update the evidence in this script and remove"
  echo "the ban in the same commit. Do not silence a guard to ship copy."
  exit 1
fi

echo "check-claims: clean"
