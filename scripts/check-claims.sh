#!/usr/bin/env bash
# Fails the build if a claim we cannot defend against live code reappears
# anywhere in the site or the decks.
#
# WHY THIS EXISTS
# ---------------
# The persona decks are 18 hand-maintained HTML files with byte-identical
# shared slides and no generator, so one sentence lives in up to 12 copies.
# On 2026-07-15 a copy sweep fixed the masking headlines and still missed the
# card headings and closing lines in 8 more files: not carelessness, just what
# happens when a rule has no owner. This script is that owner: the files stay
# forked (converging the deck pipeline is a separate job), but the RULE lives
# in exactly one place and the build enforces it.
#
# Every entry cites the code that makes the claim false. Before removing one,
# re-read the evidence and confirm the code changed: do not "fix" the guard.
# Companion: ~/private/Sparcle-LLC/verify-claims.sh proves the CAN-CLAIM side
# against bolt-api; this proves the DO-NOT-SAY side against the website.
#
# Usage: ./scripts/check-claims.sh   (runs in prebuild; exit 1 = a banned claim)

set -uo pipefail
cd "$(dirname "$0")/.."

fail=0

# ban_near <"a|b"> <"c|d"> <window> <"why">
# Flags a claim only when it sits within <window> chars of a disqualifying
# context. Some claims are true or false depending on what they attach to: # "gated and audited" is correct about the governed server and false about the
# free client: and a flat phrase ban would delete good copy along with bad.
ban_near() {
  local ctx="$1" claim="$2" window="$3" why="$4"
  local out
  out=$(CTX="$ctx" CLAIM="$claim" WIN="$window" python3 - <<'PY'
import os, re, pathlib, sys
ctx = re.compile(os.environ["CTX"], re.I)
claim = re.compile(os.environ["CLAIM"], re.I)
win = int(os.environ["WIN"])
roots = [pathlib.Path("public/decks"), pathlib.Path("src/pages"), pathlib.Path("src/fragments")]
hits = set()
for r in roots:
    if not r.exists():
        continue
    for f in list(r.rglob("*.html")) + list(r.rglob("*.astro")):
        if "legacy" in f.as_posix():
            continue
        t = f.read_text(errors="ignore")
        flat = re.sub(r"<[^>]+>", " ", t)
        for m in ctx.finditer(flat):
            seg = flat[m.start(): m.end() + win]
            if claim.search(seg):
                hits.add(f.as_posix())
for h in sorted(hits):
    print(h)
sys.exit(0)
PY
  )
  if [ -n "$out" ]; then
    echo "BANNED CLAIM (context): \"$claim\" near \"$ctx\""
    echo "  why: $why"
    echo "$out" | sed 's/^/    /'
    echo
    fail=1
  fi
}

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

# BYO-LLM asserted as the product's default rather than a choice the customer
# makes. Caught only when the persona pages surfaced this deck prose into
# indexable HTML: it sat in 9 decks while this guard reported clean, because
# the ban list held the strings I had already seen, not the rule they violate.
# A phrase list catches REGRESSIONS of known claims; it does not prove the
# absence of new phrasings of the same idea. When adding copy, ask whether the
# claim is true, not whether the guard is quiet.
ban "never leaves either" \
    "asserts BYO-LLM as the default; say \"point it at your own LLM and the rest stays inside your boundary\""
ban "the deal never leaves" \
    "conditional on BYO-LLM being configured; make the condition explicit"
ban "the document never leaves" \
    "conditional on BYO-LLM being configured; make the condition explicit"
# DELIBERATELY NOT BANNED: bare "never leaves" / "data never leaves".
#
# A substring cannot tell a claim from its own disclaimer. Banning
# "data never leaves" flagged exactly two files, and both were CORRECT:
#   - trust/where-the-model-runs.astro: "What we do not claim: We do not claim
#     that data never leaves your perimeter in Mode C. It does, in masked form."
#     The guard flagged the page for being honest. That is backwards.
#   - persona-overview: "Air-gap deployable: Runs with zero outbound calls;
#     citizen data never leaves the boundary." True, and scoped to the air-gap
#     tier (verified: zero phone-home).
# It is also TRUE of genuinely local surfaces: "searchable clipboard history,
# never leaves the device", "Local decode. The payload never leaves the box",
# "most of it never leaves your machine".
#
# The false CONSTRUCTIONS are banned individually above. That is the honest
# limit of a phrase list: it pins down claims we have already reasoned about,
# and it cannot judge a sentence it has not seen.

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
# keeps recall on the classic entity/keyword/recency ranking: exactly the
# behavior with no embedder."
ban "keyword-plus-vector" \
    "vector signal is off by default; say \"keyword and entity-overlap\""

# --- MCP transport --------------------------------------------------------
# bolt-api providers/mcp/discovery.rs McpTransportType has StreamableHttp,
# LegacySse, CustomRest, Unknown: there is NO stdio variant.
ban "connect any MCP server" \
    "MCP is HTTP-only (no stdio transport); say \"connect any HTTP MCP server\""

# --- Instant compliance ---------------------------------------------------
# 28 packs ship, 6 enabled by default; GovernanceProfile::Standard leaves the
# PDP inert ("byte-identical to pre-governance Bolt") and even Regulated only
# resolves config: enforcement wiring is explicitly a follow-up.
ban "Day 1 compliance" \
    "PDP is inert by default and 22/28 packs are opt-in; say \"configurable compliance policy packs\""
ban "Compliance readiness" \
    "same as above; say \"configurable compliance policy packs\""
ban "compliant from day one" \
    "compliance needs configuration and is not a product state; say what ships instead"

# --- Audit, stated unconditionally --------------------------------------
# The tamper-evident Merkle chain requires BOTH a Postgres pool AND a CMK/KMS
# provider. bolt-api state.rs names this exact marketing phrase as the thing it
# contradicts: without them the install "is NOT auditable despite the
# 'auditable from day one' claim", falling back to NoopAuditRepository (stdout).
# It IS guaranteed under the Regulated SERVER posture: that boot path refuses
# to start without a durable sink: but Standard is the default and degrades
# gracefully by design, and verify-claims.sh confirms no shipped config selects
# Regulated. So the claim is true ON THE GOVERNED SERVER and false as a blanket
# or free-client promise. Scope it; do not delete it.
ban "auditable from day one" \
    "audit needs Postgres + KMS; true on the governed server, not by default. Scope it."

# "gated and audited" is TRUE when scoped to the governed server: persona-cio's
# "Switch on the governed server ... and every action becomes masked, gated and
# audited" is correct and must not be flagged. It is FALSE only when attached to
# the free desktop client, which has no Postgres/CMK and therefore no durable
# sink. So this is a proximity rule, not a phrase ban.
ban_near "free client|free desktop|every support desktop|free build" \
         "gated and audited|governed and audited|masked, gated" 400 \
    "governance attached to the FREE client, which has no durable audit sink; scope it to the governed server"

if [ "$fail" -ne 0 ]; then
  echo "check-claims: FAILED: the copy above outruns what the code does."
  echo "If a claim became TRUE, update the evidence in this script and remove"
  echo "the ban in the same commit. Do not silence a guard to ship copy."
  exit 1
fi

echo "check-claims: clean"
