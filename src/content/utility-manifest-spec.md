<!--
  synced from bolt-api/docs/UTILITY_MANIFEST.md by scripts/sync-docs.sh
  do not edit by hand — edits will be overwritten on next build
-->
# Bolt Utility Manifest Spec (v1)

**Status:** Frozen for v1. Future spec versions ship under a new `schema_version` and are additive at the parser, never breaking.

**Audience:** Backend implementers (Rust runtime + linter), frontend implementers (wizard + YAML editor), admins authoring custom utilities, community contributors of bundled manifests.

This document is the single source of truth for what a Bolt utility is, how it loads, how it runs, and how it fails. If the code disagrees, the code is wrong.

---

## 1. What a utility is

A utility is a single launcher chip (e.g. `=jira`, `=team`, `=incidents`) that:

1. Exposes one or more **scopes** (sub-commands the user can pick after typing `=`).
2. Runs a **declarative flow** of MCP tool calls and HTTP calls to fetch data.
3. Emits rows of a known **canonical type** (`Person`, `Issue`, `Document`, ...).
4. Renders the rows in the **launcher autocomplete dropdown** (the existing one, no new component).
5. Optionally binds the selected row into a **right-rail widget** (the existing one: `card`/`map`/`image`/`date`/`calc`/`color`/`entity`/`entity_preview`/`weather`).
6. Exposes typed **actions** on rows (`url`, `tool`, `utility`, `composer`, `clipboard`).

Authoring is no-code first: bundled manifests ship with Bolt; admins enable them via the Gallery; custom manifests are authored via a wizard or YAML side panel. The wizard introspects MCP servers and binds tools by point-and-click.

Authentication is **per-user OAuth only**. There is no service-account mode. Ever.

---

## 2. Architecture

A manifest has three strictly-separated layers:

| Layer | Contents | Logic allowed |
|---|---|---|
| **Identity** | `id`, `chip`, `title`, `icon`, `description`, `emits`, `auth_profile_ref`, `requires` | none |
| **Flow** | `scopes[]`, `filters[]`, `actions[]`, a small DAG of MCP/HTTP calls | declarative DAG only |
| **Presentation** | `presentation` (widget, fields, right_widget bindings) | template substitution only |

The flow DAG has exactly **five node types**: `call`, `parallel`, `merge`, `transform`, `emit`. There are no conditionals, no loops, no `when:` predicates, no expression language. If a use case can't be expressed with these primitives, the answer is "write a custom MCP tool," not "extend the manifest."

The escape hatch for data shaping is `transform: jq '...'`, executed inside a sandboxed `jaq` interpreter with hard CPU/memory/output budgets. JQ has no I/O.

---

## 3. Frozen primitives

Adding to any of these lists is a spec version bump. Removing is a breaking change.

| Primitive set | Members |
|---|---|
| Flow node kinds | `call`, `parallel`, `merge`, `transform`, `emit` |
| Call kinds | `mcp` (default), `http` |
| Filter kinds | `enum`, `text`, `date_range` |
| Filter `apply` modes | `pre` (mutates flow args), `post` (filters emitted rows) |
| Action kinds | `url`, `tool`, `utility`, `composer`, `clipboard` |
| Action `target` | `row`, `list` |
| Widget types (list) | `list`, `table`, `cards`, `image_grid`, `detail` |
| Right-widget kinds | `card`, `map`, `image`, `date`, `calc`, `color`, `entity`, `entity_preview`, `weather`, `markdown`, `chart`, `table`, `cards`, `detail`, `json_tree`, `diff`, `image_grid` |
| Right-widget modes | `selected_row`, `list_data` |
| Canonical row types | `Person`, `Issue`, `Document`, `Event`, `File`, `Incident`, `Account`, `Place`, `Generic` |
| Template filters | `date`, `upper`, `lower`, `default`, `join`, `truncate`, `jql_escape`, `sql_escape`, `url_escape`, `html_escape` |
| Auth types | `oauth2_user` (per-user OAuth via MCP), `oauth2_user_http` (per-user OAuth via direct HTTP), `public` (no auth, public APIs only) |

Notes:
- Auth types `oauth2_client_credentials`, `bearer_token` (shared), `basic`, `mtls`, `signed_jwt_assertion`, `session_passthrough` from previous designs are **removed** in v1. Per-user OAuth only.
- The `public` auth type permits unauthenticated HTTP calls and is restricted to manifests where every `call:` is `kind: http` against an allowlisted public-API host.
- `table`, `cards`, `detail`, and `image_grid` also appear in the "Widget types (list)" row, but are currently rendered as **right-widget panes** via `presentation.right_widget.kind` (see §9.6); full-width main-presentation rendering of those is on the roadmap.

---

## 4. Top-level schema

```yaml
schema_version: 1                  # required, must equal 1
id: jira                           # required, lowercase ASCII slug, unique per org
chip: =jira                        # required, must start with '=' followed by id
title: "Jira Work"                 # required, human label
icon: jira                         # optional, lucide icon name or registered provider icon
description: "Search issues..."    # optional, one line
emits: Issue                       # required, canonical row type (or 'Generic')
auth_profile_ref: jira_user_obo    # required unless every call is kind:http auth:public

requires:                          # save-time gate; admin's env must satisfy
  - mcp: atlassian-jira            # MCP server id present in org catalog
    version: ^3                    # semver range
    tools: [search_issues, get_issue, list_projects, get_active_sprint, update_issue]
    scopes: [jira.read, jira.write]

scopes: [...]                      # required, >= 1, exactly one with default: true
filters: [...]                     # optional
actions: [...]                     # optional
presentation: { ... }              # required
```

### 4.1 Required fields

`schema_version`, `id`, `chip`, `title`, `emits`, `scopes`, `presentation`. Plus `auth_profile_ref` unless the manifest is `public` per §10.

### 4.2 Validation

All validation is **save-time**, not runtime. A manifest that passes the linter is guaranteed to load and dispatch (it may still fail at the MCP layer at runtime; that is a separate failure class with a separate UX).

See §11 for the complete linter rule list.

---

## 5. Scopes

A scope is a labeled "shape of answer" the utility can produce. Scopes are surfaced in the launcher's chip-row autocomplete after the user types the chip key.

Exactly one scope must have `default: true`. That scope fires when the user types the chip with no query (e.g. `=jira`, no args).

```yaml
scopes:
  - id: my                     # required, unique within manifest
    label: "My open issues"    # required, shown in chip-row autocomplete
    default: true              # required on exactly one scope
    flow: [...]                # required: list of flow nodes
    response_schema: { ... }   # optional, JSON Schema of the emitted row shape

  - id: search
    label: "Search"
    match:                     # optional: routes user input to a sub-flow
      - regex: '^[A-Z]{2,10}-\d+$'
        bind: { key: '{{match}}' }
        flow: [...]
      - text: '{{query}}'      # text: matches if query present
        flow: [...]
```

### 5.1 Match dispatch order

When a scope has `match:`, each entry is tried in declared order. First match wins. The two pattern keys are:

- `regex: '...'`, matched against the user query (post-chip). Validated for ReDoS at save time using the same probe set as `bare.patterns` in the legacy spec. The full match is exposed as `{{match}}`; named groups via `(?P<name>...)` are exposed as `{{groups.name}}`. Bindings declared in `bind:` populate the template context.
- `text: '{{query}}'`, matches whenever query text is non-empty. Use as the catch-all last entry.

If no entry matches, the scope returns an empty result set.

### 5.2 Default scope dispatch

When the user activates the chip with no query (`=jira` then Enter, or chip selected and query empty):

1. The scope marked `default: true` is dispatched.
2. If that default scope has `match:`, the `text:` branch is tried with empty query. If no `text:` branch exists, the scope's `flow:` (top-level, not under `match:`) is tried. If neither exists, the linter rejects this manifest at save time.

### 5.3 Reserved scope ids

`__list__` is reserved for internal use. Scope ids must match `^[a-z][a-z0-9_]*$`.

---

## 6. Flow DAG

A `flow:` is an ordered list of nodes. Each node either calls a tool, runs nested flows in parallel, merges arrays, transforms data with jq, or emits the final result.

Nodes execute in declared order. Each node may declare a named output via `out: <name>`; subsequent nodes can reference it via `{{<name>...}}` in templates.

A flow must contain exactly one `emit:` node, and it must be the last node.

### 6.1 `call:` invoke one tool

```yaml
- call:
    kind: mcp                  # 'mcp' (default) or 'http'
    mcp: atlassian-jira        # required if kind:mcp; MCP server id from requires:
    tool: search_issues        # required if kind:mcp; tool from requires:.tools
    args:
      jql: "{{query | jql_escape}}"
      fields: "{{__projection}}"
      limit: "{{limit}}"
  out: r                       # required: name the output
  response_schema: { $ref: "schemas/jira/search_issues.json" }   # optional but recommended
  retry:                       # optional
    max: 2
    on: [503, 504, 429]        # status codes; HTTP only
    backoff_ms: [200, 800]
  timeout_ms: 5000             # optional, default per-tenant config (typically 8000)
```

For `kind: http`:

```yaml
- call:
    kind: http
    method: GET
    url: "https://nominatim.openstreetmap.org/search"
    query:                     # query string params, templated
      q: "{{query}}"
      format: json
      limit: "{{limit}}"
    headers:
      User-Agent: "Bolt/{{org.name}}"
    body: { ... }              # for POST/PUT/PATCH only
  out: places
  response_schema: { ... }
```

#### Arg typing for injection prevention

Each templated arg's intended type is inferred from the response schema (when provided) and the tool's input schema (fetched at save time from `tools/describe`). The linter rejects:

- Unparameterized `{{query}}` substitution into args typed as a query DSL (JQL, SOQL, KQL, NRQL, GraphQL) **unless** the template uses an explicit escape filter (`jql_escape`, `sql_escape`, etc.).
- Unparameterized substitution into URL host/path components without `url_escape`.

The escape filters are documented in §9.5.

### 6.2 `parallel:` run nested flows concurrently

```yaml
- parallel:
    - call: { mcp: pagerduty,  tool: list_incidents, args: { ... } }
      out: pd
    - call: { mcp: datadog,    tool: list_alerts,    args: { ... } }
      out: dd
    - call: { mcp: servicenow, tool: query,          args: { ... } }
      out: sn
  streaming: true              # optional; when true, results stream to client as branches complete
```

Each child node must declare `out:`. All children's outputs are added to the template context after the `parallel:` node completes (or after each branch completes, when `streaming: true`).

#### Failure semantics

- Default: if any branch fails, the entire `parallel:` fails. The error is surfaced with the failing branch's name.
- `tolerate_failures: true`: failed branches contribute an empty array under their `out` name; the flow continues. The UI surfaces a partial-result indicator.

#### Streaming semantics

- `streaming: true` only meaningful when the next node is `merge:` or `emit:`.
- Each branch's completion triggers an SSE event to the client carrying `{branch_name, rows}`.
- Client renders rows incrementally. When all branches complete (or fail), a final event signals end-of-stream.

### 6.3 `merge:` combine arrays into a unified row set

```yaml
- merge:
    inputs:
      - { from: pd, path: /incidents,  tag: pagerduty }
      - { from: dd, path: /alerts,     tag: datadog }
      - { from: sn, path: /result,     tag: servicenow }
    schema:
      id:       { pagerduty: id,        datadog: id,         servicenow: number }
      title:    { pagerduty: title,     datadog: alert_name, servicenow: short_description }
      severity: { pagerduty: urgency,   datadog: priority,   servicenow: severity }
      url:      { pagerduty: html_url,  datadog: url,        servicenow: link }
    source_tag_field: source              # optional; injects row.source = tag value
    dedupe_by: [title]                    # optional; keep first occurrence
    sort_by: severity                     # optional
    sort_order: desc                      # optional, asc|desc
  out: rows
```

`schema:` is a per-output-field map: each top-level key is the unified field name; each value maps source `tag` → JSON pointer (relative to that source's row) to extract.

If a source row lacks a path, the unified field is `null` for that row.

`dedupe_by` accepts a list of field names; rows with identical values across all listed fields are deduplicated, keeping the first.

### 6.4 `transform:` jq one-liner over the template context

```yaml
- transform: '.r.reports | map(select(.email != $user_email))'
  out: peers
  vars:                                   # optional; bound as $name in the jq program
    user_email: "{{user.email}}"
```

Hard limits, enforced per-execution:

- CPU time: 50 ms
- Memory: 16 MB
- Output JSON size: 1 MB

Exceeding any limit aborts the transform with a runtime error. The linter rejects manifests whose transforms exceed budget against a synthetic stress input at save time.

The jq program runs against an object whose keys are all named outputs from prior steps plus `$user`, `$org`, `$query`, `$limit`. It cannot read environment variables, files, network, or system clock.

### 6.5 `emit:` produce the final row set

```yaml
- emit: r                      # name of the output to emit (must be an array or single object)
  path: /issues                # optional: JSON pointer into the named output
  filter: ...                  # reserved (no expression language in v1; not implemented)
```

If the emitted value is a single object, it becomes a single-row result. If it's an array, each element is a row.

A flow must end with exactly one `emit:`. Nothing executes after `emit:`.

### 6.6 Implicit projection variable

Inside `call:` args, the special token `{{__projection}}` resolves to a comma-separated list of fields actually used by the manifest's `presentation` and `actions`. The runtime computes this set once per manifest at load time. Use this to push field projection into MCP/HTTP calls (e.g. Jira `fields=summary,status,priority`).

---

## 7. Filters

Filters are dropdown chips above the result list. They modify either the query (`apply: pre`) or the emitted rows (`apply: post`).

```yaml
filters:
  - id: project
    kind: enum
    label: Project
    apply: pre
    maps_to: jql.project           # injects "project=<value>" into the JQL fragment
    populate:                      # optional: how to source enum values
      - call: { mcp: atlassian-jira, tool: list_projects }
      - emit: projects.values
        as: { value: id, label: name }

  - id: status
    kind: enum
    static: [Open, "In Progress", Done]
    apply: pre
    maps_to: jql.status

  - id: keyword
    kind: text
    apply: post
    matches_field: fields.summary

  - id: due_window
    kind: date_range
    apply: pre
    maps_to: jql.duedate
```

### 7.1 `pre` filters: `maps_to` semantics

`maps_to` is a dotted path interpreted by the runtime to inject the filter value into a `call:` arg. The first dotted segment names the arg; subsequent segments compose with the existing value.

For Jira-style JQL injection, `maps_to: jql.project` appends `AND project=<value>` to the JQL string in the `jql` arg (using the `jql_escape` filter automatically).

For SOQL: `maps_to: where.AccountType` appends `AND AccountType='<value>'`.

For HTTP query strings: `maps_to: query.status` adds `?status=<value>` (or `&status=<value>`).

For arbitrary nested objects: `maps_to: body.filter.status` sets the corresponding nested field.

### 7.2 `post` filters

`post` filters operate on the row set after `emit:`. They are evaluated client-side (no extra round trip). `matches_field` declares which row field to test.

For `kind: text`: substring match, case-insensitive.
For `kind: enum`: exact equality on the row field.
For `kind: date_range`: row field must parse as a date and fall within the range.

### 7.3 Filter UI

Filter chips render in the launcher above the result list, in declared order. Enum filters with `populate:` lazily fetch their options on first dropdown open and cache for the session.

---

## 8. Actions

Actions are buttons attached either to each row (`target: row`) or to the list as a whole (`target: list`).

### 8.1 Action kinds

```yaml
actions:
  # url: open a URL (current tab or new tab per UX policy)
  - id: open
    target: row
    kind: url
    label: "Open in Jira"
    icon: external_link
    url_template: "https://{{org.jira_host}}/browse/{{row.key}}"

  # tool: invoke an MCP/HTTP tool with a confirmation prompt; runs server-side
  - id: assign_me
    target: row
    kind: tool
    label: "Assign to me"
    confirm: "Assign {{row.key}} to me?"
    flow:
      - call:
          mcp: atlassian-jira
          tool: update_issue
          args:
            key: "{{row.key}}"
            fields: { assignee: { accountId: "{{user.id}}" } }

  # utility: route to another utility (re-fires the launcher with a new chip+query)
  - id: see_team
    target: row
    kind: utility
    label: "Team"
    target_chip: "=team"
    query_template: "for:{{row.assignee.email}}"

  # composer: insert text into the chat composer
  - id: create
    target: list
    kind: composer
    label: "Create issue"
    insert: "=jira create "

  # clipboard: copy a templated value to the OS clipboard (client-side only)
  - id: copy_key
    target: row
    kind: clipboard
    label: "Copy key"
    value: "{{row.key}}"
```

`kind: clipboard` requires a `value:` template and runs entirely client-side; it never touches an MCP server or HTTP, so it carries none of the confirm/idempotency/audit machinery of `kind: tool`.

### 8.2 Confirmations

`kind: tool` actions require a `confirm:` template. The confirmation dialog reuses the existing chat confirmation workflow component.

### 8.3 Idempotency

Every `kind: tool` invocation is assigned an idempotency key derived deterministically from `(user_id, action_id, row_primary_key, time_bucket)` where the time bucket is 5 seconds. Repeated clicks within the bucket are coalesced server-side; a duplicate fire returns the original result.

The row primary key is derived from `presentation.row_key_field` (defaults to `id` if present, else the first field of `presentation.list_fields`).

### 8.4 Audit

Every `kind: tool` invocation writes an audit row with:

- timestamp (UTC)
- tenant id, user id, user email
- utility id, scope id (if known), action id
- MCP server id, tool name
- args (with templates resolved; PII fields auto-redacted by the existing PII pipeline)
- response status (success | error)
- error message (if failure)

Audit rows are written via the existing audit log pipeline (`audit_merkle_roots`-feeding writer). They participate in the existing nightly Merkle sealing.

### 8.5 Action permissions

Actions inherit the utility's `requires:.scopes` for the relevant MCP server. The linter rejects an action whose flow uses tools or scopes not declared in `requires:`.

---

## 9. Presentation

```yaml
presentation:
  widget: list                            # list | table | cards | image_grid | detail
  title_field: fields.summary             # required for list/cards/detail
  subtitle_field: key
  image_field: fields.assignee.avatarUrls.48x48    # for cards/image_grid
  primary_value_field: fields.priority.name        # for detail
  list_fields: [key, fields.summary, fields.status.name, fields.priority.name]
  table_columns: [...]                    # required for widget: table
  searchable: true
  search_fields: [key, fields.summary]
  filterable: true                        # whether to show the filter row above results
  sort_field: fields.updated
  sort_order: desc
  row_key_field: key                      # used by idempotency keys; default 'id'

  right_widget:
    kind: card                            # one of the 10 frozen right-widget kinds
    mode: selected_row                    # selected_row | list_data
    bind:
      title: "{{row.fields.summary}}"
      subtitle: "{{row.key}} - {{row.fields.status.name}}"
      image_url: "{{row.fields.assignee.avatarUrls.48x48}}"
      fields:
        - { label: Priority, value: "{{row.fields.priority.name}}" }
        - { label: Reporter, value: "{{row.fields.reporter.displayName}}" }
        - { label: Updated,  value: "{{row.fields.updated | date:'rel'}}" }
      actions: [open, assign_me]          # references to actions[].id
      links_for_type: Person              # optional: cross-utility links section
```

### 9.1 Widget rendering

The list widget reuses the existing launcher autocomplete dropdown. Each row is rendered with `title_field` as the primary text and `subtitle_field` underneath. `list_fields` populates a compact field strip on the right of each row.

The right_widget reuses the existing right-rail panel; `kind` selects one of the 10 widget components; `bind` provides per-component template bindings. `entity_preview` is the wide detail pane (media + title/subtitle + label/value facts + icon footer) rendered through the shared `EntityPreviewPane`, bound from the selected row's fields with the footer drawn from the manifest's `actions`.

#### `markdown`: rich, scrollable, sanitized body

`kind: markdown` renders a scrollable pane of **sanitized Markdown** (prose + syntax-highlighted code fences, one primitive covers both). It is available to admin **and** user/bridge utilities, for showing long or richly-formatted content (release notes, a rendered file, a diff, a report) that doesn't fit the fact-table shape of `card`/`entity_preview`.

```yaml
right_widget:
  kind: markdown
  mode: selected_row
  bind:
    title: "{{row.title}}"          # optional plain-text header
    subtitle: "{{row.env}}"         # optional plain-text subheader
    body: "{{row.release_notes}}"   # Markdown; ```lang fences auto-highlight
    actions: [open, copy]           # references to actions[].id (footer chips)
```

`bind.body` is a template resolved against the selected row (`{{row.<field>}}`, `{{count}}`), then rendered through the launcher's `renderRichMarkdown` pipeline: `marked` (GFM) → **DOMPurify sanitize** → DOM post-pass. The contract guarantees:

- The author supplies only a template string; the resolved string is **always sanitized** before injection. No raw HTML passthrough; script/event-handler attributes are stripped. Safe by construction.
- Links open in the **system browser** (never navigate the launcher), restricted to `http(s)`/`mailto`, with `rel="noopener noreferrer"`.
- **Remote images are blocked for user/bridge utilities** (replaced with an inert placeholder) to preserve the User-App "nothing leaves your machine" invariant; `data:` and loopback image sources are allowed. Admin utilities (which already egress) may render remote images.
- Code fences get a per-block **copy** button; the body pane is focusable (`Tab`) and scrolls with the keyboard.
- The body deliberately does **not** run entity annotation, so a User-App body never grafts onto the entity router.

A natural authoring pairing is `parse: json` rows carrying a short `title` plus a Markdown `body` field (so the result row stays a clean label while the pane shows the rendered content); `parse: raw` with `body: "{{raw}}"` also works for a single-document preview.

### 9.2 `links_for_type` cross-utility composition

When set, the right_widget renders an additional "Related" section with auto-generated links to other utilities that emit the named type. For example, with `links_for_type: Person` on a `=team` Person card, the registry knows `=jira-people` and `=salesforce-contacts` also emit `Person`, and renders link rows like:

```
Related
- 5 Jira issues assigned       -> fires =jira for:{{row.email}}
- 12 Salesforce activities     -> fires =salesforce for:{{row.email}}
```

The other utility must declare a `links_for_type:` provider to opt in (see §10.4).

### 9.3 Template paths

Template paths are dotted paths into the row object. Numeric and string segments are both supported. Bracket notation is not supported in v1; field names containing `.`, `-`, or `/` must be aliased via a `transform:` step before `emit:`.

When a path resolves to `undefined`, the template substitutes the empty string unless a `| default:` filter is present.

### 9.4 Standard variables

Always available in templates:

| Variable | Source |
|---|---|
| `{{user.id}}`, `{{user.email}}`, `{{user.name}}` | Calling user from session |
| `{{user.timezone}}`, `{{user.locale}}` | User profile |
| `{{org.id}}`, `{{org.name}}`, `{{org.domain}}` | Tenant |
| `{{org.jira_host}}`, etc. | Tenant-configured per-MCP host overrides |
| `{{query}}` | The user's query text after the chip |
| `{{limit}}` | Effective row limit for this fire (1..50, default 20) |
| `{{match}}` | Full regex match (in `match:` regex branches) |
| `{{groups.name}}` | Named regex groups |
| `{{__projection}}` | Comma-separated field projection (see §6.6) |
| `{{<step_out>...}}` | Any prior step's named output |
| `{{row.x}}` | Current row (in actions/right_widget) |

### 9.5 Template filter functions

| Filter | Behavior |
|---|---|
| `\| date:'rel'` | Relative date ("2h ago") |
| `\| date:'long'` | Long date ("April 27, 2026") |
| `\| date:'short'` | Short date ("4/27/26") |
| `\| upper`, `\| lower` | Case |
| `\| default:'xxx'` | Replace null/undefined/empty |
| `\| join:','` | Array to string |
| `\| truncate:80` | Cut to N chars with ellipsis |
| `\| jql_escape` | Escape value for JQL string literal |
| `\| sql_escape` | Escape for SOQL/SQL string literal |
| `\| url_escape` | Percent-encode for URL component |
| `\| html_escape` | Escape `<`, `>`, `&`, `"`, `'` |

Filter chains are left-to-right: `{{x | upper | truncate:20 | default:'?'}}`.

There are no other filters in v1. There are no expressions, no arithmetic, no comparisons, no conditionals, no function calls beyond this list.

### 9.6 Rich data-viz right-widgets

These render the parsed `rows` (plus a declarative `bind`) in the right rail; none bind to the entity graph (the router-binding `entity` kind stays separate, see §9.1). Multi-row widgets use `mode: list_data`; per-record widgets use `mode: selected_row`.

| `kind` | Renders | `bind` schema | mode |
|---|---|---|---|
| `chart` | SVG line/bar/sparkline chart | `{ type: line\|bar\|sparkline (default line), x?: <field>, y: <numeric field> }` OR `{ values?: <field holding a number[]>, label?: <field>, unit?: <string>, color?: <string> }` | `list_data` (one point per row) |
| `table` | scrollable data table | `{ columns?: [ { field, label?, align?: left\|right\|center } ] }`; omit `columns` to auto-infer from row keys | `list_data` |
| `cards` | responsive grid of tiles, one per row | `{ title, subtitle?, badge?, image?, footer? }` (all `{{row.x}}` templates) | `list_data` |
| `detail` | single-record key/value pane for the selected row | `{ title?, subtitle?, fields?: [ { label, value (template), copy?: bool } ] }`; omit `fields` to auto-derive from the row's keys (humanized) | `selected_row` |
| `json_tree` | collapsible recursive JSON tree | `{ source?: <field whose value is the object, or a JSON string to parse> }`; omit `source` to show the whole selected row | `selected_row` |
| `diff` | red/green LCS line diff | `{ left (template), right (template), leftLabel?, rightLabel? }`; with no bind and exactly two rows it falls back to `rows[0]` vs `rows[1]` | `selected_row` |
| `image_grid` | thumbnail grid, one image per row | `{ src (template → image URL or self-contained data: URL per row), caption?, alt?, columns?: <number> }` | `list_data` |

Per-kind details:

- `chart`: `list_data` maps one point per row.
- `table`: omit `columns` to auto-infer from row keys.
- `cards`: `badge` auto-colors: **green** (ok/healthy/up/success/active), **amber** (warn/degraded/pending), **red** (error/down/fail/critical).
- `detail`: omit `fields` to auto-derive from the row's keys (humanized).
- `json_tree`: the top two levels expand by default; click any node/leaf to copy; depth is capped at ~6.
- `diff`: capped at 1500 lines per side.
- `image_grid`: remote and `data:` URLs are both allowed here (unlike `markdown`, which blocks remote images for User Apps, §9.1). Click opens `src`.

```yaml
presentation:
  widget: list
  right_widget:
    kind: chart
    mode: list_data
    bind: { type: bar, x: mount, y: pct_num, unit: "%" }
```

---

## 10. Auth profiles

```yaml
# auth-profiles.yaml (separate file, shared across utilities)
version: 1
auth_profiles:
  - id: jira_user_obo
    type: oauth2_user                  # per-user OAuth via MCP; tokens stored encrypted per-user
    provider: atlassian-jira           # MCP server id whose OAuth flow this profile uses
    scopes: [jira.read, jira.write]

  - id: gmail_user
    type: oauth2_user
    provider: gmail
    scopes: [gmail.readonly]

  - id: osm_public
    type: public                       # only valid for kind:http calls to allowlisted public hosts
```

### 10.1 Removed profile types

The following types from previous designs are **removed** in v1 and the linter rejects manifests that reference them:

- `oauth2_client_credentials`
- `oauth2_on_behalf_of` (replaced by `oauth2_user`)
- `bearer_token` (when sourced from a shared secret)
- `basic`
- `mtls`
- `signed_jwt_assertion`
- `session_passthrough` (when used as a shared session)

Any profile of these types in existing `auth-profiles.yaml` files must be removed before upgrading to v1. The runtime refuses to load an org's manifests if any auth profile is of a removed type.

### 10.2 Per-user OAuth lifecycle

When a user fires a utility for the first time, the runtime checks for a stored MCP token for the manifest's `auth_profile_ref.provider`. If absent or expired, the runtime returns a `needs_oauth` payload; the launcher renders a "Connect <provider>" CTA that opens the existing MCP OAuth popup flow. After the user completes OAuth, the runtime retries the original utility fire.

### 10.3 Public auth (`type: public`)

Permitted only when:

- Every `call:` in the manifest has `kind: http`.
- Every URL host is in the per-tenant public-API allowlist (configured by ops; defaults include `nominatim.openstreetmap.org`, `api.openweathermap.org` (when public-tier), etc.).
- The manifest declares no `kind: tool` actions of `kind: http` writing to non-allowlisted hosts.

The linter enforces all three.

### 10.4 Cross-utility type registry

A separate file declares which utilities provide cross-type links:

```yaml
# config/utilities/types-registry.yaml
links:
  Person:
    - utility: jira
      query_template: "for:{{target.email}}"
      label_template: "{{count}} Jira issues"
      count_scope: my            # optional scope to count
    - utility: salesforce
      query_template: "for:{{target.email}}"
      label_template: "{{count}} Salesforce activities"
```

Counts are fetched lazily when a Person card opens, with a 30-second cache per (target, utility).

---

## 11. Save-time validation (linter)

A manifest must pass every check in this section before being persisted. Failures return structured errors to the wizard for inline display.

### 11.1 Schema checks

- `schema_version == 1`
- All required fields present
- `id` matches `^[a-z][a-z0-9_-]*$`, length 2..40
- `chip` equals `=` + `id`
- `emits` is one of the canonical types (§12) or `Generic`
- All enum values from §3 (frozen primitives) match exactly

### 11.2 Reference checks

- `auth_profile_ref` resolves in `auth-profiles.yaml`
- Every `requires[].mcp` is registered in the org's MCP catalog
- Every `requires[].tools[]` is exposed by the corresponding MCP server (validated via `tools/list`)
- Every action id referenced in `right_widget.bind.actions` exists in `actions[]`
- Every scope id referenced in `populate:` resolves to a real call output
- Every templated step output reference (`{{step_x.y}}`) resolves to an `out:` declared earlier in the same flow

### 11.3 Type checks

For each `call:` with a `response_schema:` (or one auto-derivable from `tools/describe`):

- All `path:` JSON pointers in subsequent `emit:` resolve in the schema
- All `merge.inputs[].path` pointers resolve
- All `presentation.list_fields`, `title_field`, `subtitle_field`, etc. resolve in the emitted-row schema
- All `right_widget.bind.{title,subtitle,image_url,fields[].value}` template paths resolve
- All `actions[].url_template`, `actions[].flow.*.args` template paths resolve

### 11.4 Security checks

- Every templated arg in a `call:` typed as a query DSL must use the appropriate escape filter (`jql_escape`, `sql_escape`, etc.) or be a non-templated literal
- Every `url_template` host is either a non-templated literal or templated only into the path/query (not the host)
- Every `bare`/`match.regex` passes the ReDoS probe set within 25ms each
- Every `transform:` jq program passes the resource budget against the synthetic stress input
- `auth_profile_ref` resolves to an allowed type (per §10.1)
- For `auth_profile_ref.type == public`, all §10.3 conditions hold

### 11.5 Field allowlist computation

The linter computes the **field allowlist** = union of:

- Every path used in `presentation.list_fields`, `title_field`, `subtitle_field`, `image_field`, `primary_value_field`, `table_columns`, `search_fields`, `sort_field`, `row_key_field`
- Every path referenced in `right_widget.bind.*`
- Every path referenced in `actions[].flow.*.args`
- Every path referenced in any `merge.inputs[].path` upstream of an `emit:`

The runtime serializer strips every other field from emitted rows before sending them to the client. The allowlist is recorded with the manifest at load time.

### 11.6 Default scope check

Exactly one scope has `default: true`. The default scope must be reachable with empty query (top-level `flow:` or a `text:` branch in `match:`).

### 11.7 Frozen-primitive check

Every flow node uses one of the 5 frozen kinds. Every filter/action/widget kind is in the frozen list. No unknown top-level keys (strict mode).

---

## 12. Canonical row types

Manifests declare `emits: <Type>` to opt into a canonical type contract. The contract specifies required fields, optional fields, and a default right-rail layout. Right-rail bindings (§9) override the default when present.

| Type | Required fields | Optional fields | Default right-widget |
|---|---|---|---|
| `Person` | `id`, `name`, `email` | `title`, `department`, `manager_name`, `manager_email`, `photo_url`, `location`, `timezone`, `start_date`, `pronouns` | `card` with photo, name, title, dept |
| `Issue` | `id`, `key`, `title` | `status`, `priority`, `assignee`, `reporter`, `updated`, `url` | `card` with title, key/status, priority |
| `Document` | `id`, `title`, `url` | `author`, `updated`, `space`, `excerpt`, `thumbnail_url` | `card` with title, author, excerpt |
| `Event` | `id`, `title`, `start`, `end` | `attendees`, `location`, `url`, `description` | `card` with title, time, attendees |
| `File` | `id`, `name`, `url` | `mime_type`, `size`, `owner`, `modified`, `thumbnail_url` | `card` with name, owner, modified |
| `Incident` | `id`, `title`, `severity`, `source` | `opened`, `assignee`, `url`, `service` | `card` with title, severity, source |
| `Account` | `id`, `name` | `domain`, `industry`, `owner`, `url`, `revenue` | `card` with name, owner, industry |
| `Place` | `id`, `name`, `address` | `lat`, `lon`, `phone`, `hours`, `url` | `map` widget |
| `Generic` | `id` | (any) | `card` with all fields as a key/value list |

Manifests can map their underlying response shape into the canonical type via `transform:` before `emit:`, or by returning rows that already match the contract (preferred).

The full type registry lives at `config/utilities/types-registry.yaml`. Each type also declares a default `list_fields`, `title_field`, `subtitle_field` used when the manifest omits these (rare).

---

## 13. Runtime semantics

### 13.1 Dispatch path

1. Launcher posts `POST /api/runtime/utility/<id>` with `{query, scope?, filters?, limit?}`.
2. Runtime loads contract from registry (refreshed at file change).
3. Resolves scope: explicit `scope` query param wins; else if `query` matches a `match:` regex, that branch fires; else if `query` is empty, default scope; else the scope's catch-all `text:` branch.
4. Checks per-user OAuth token for `auth_profile_ref.provider`. If missing/expired, returns `{needs_oauth: true, provider: "..."}`.
5. Builds template context: `{user, org, query, limit, match, groups, __projection}`.
6. Executes flow nodes in order (with parallel/SSE streaming if `streaming: true`).
7. Applies `pre` filters during flow execution (mutating call args).
8. After `emit:`, applies `post` filters client-side.
9. Strips row fields not in the field allowlist.
10. Serializes and returns (or streams via SSE).

### 13.2 Warm cache

The runtime maintains a warm cache for each user's default scope of each utility:

- Refresh interval: per-utility `cache_ttl_seconds` (default 300).
- On cache hit older than 30s, returns cached and triggers async refresh (SWR).
- On cache miss, blocks on first fetch.
- Per-user cache key: `(user_id, utility_id, default_scope_id)`. Filters are not part of the key (filters bypass cache).

### 13.3 Circuit breaker

Per `(utility_id, mcp_server_id)`:

- Window: 5 minutes rolling.
- Trip threshold: error rate > 10% over >= 20 calls.
- When tripped: return cached result if available with `stale: true` flag; else return error with `circuit_open: true`.
- Recovery: probe one call every 60 seconds; restore on success.

### 13.4 Rate limits

Per-tenant token bucket per MCP server. Default 100 calls/minute. Configurable per-tenant. Exceeded calls return error with `rate_limited: true` and a `retry_after_ms` hint.

### 13.5 Observability

Metrics emitted per call:

- `utility_flow_duration_seconds{utility, scope, mcp}` (histogram)
- `utility_action_invocations_total{utility, action, mcp, status}` (counter)
- `utility_cache_hits_total{utility, scope, hit}` (counter, hit ∈ {fresh, stale, miss})
- `utility_circuit_state{utility, mcp}` (gauge: 0=closed, 1=half_open, 2=open)

OTel spans wrap each `call:` with attributes `utility.id`, `utility.scope`, `mcp.server`, `mcp.tool`.

---

## 14. Authoring

### 14.1 Bundled manifests

Bundled manifests live at `config/utilities/builtin/<provider>/`:

```
config/utilities/builtin/jira/
  manifest.yaml
  fixtures/
    search_issues__my.json
    get_issue__PROJ-123.json
    list_projects.json
    get_active_sprint.json
    update_issue.json
  golden/
    my.json
    sprint.json
    direct_lookup.json
  schemas/
    search_issues.response.json
    get_issue.response.json
```

Each bundled manifest is identified by its content-addressed SHA-256 of normalized canonical YAML. The runtime registry stores the SHA alongside the manifest. Updates ship as new SHAs; the registry never mutates a SHA in place.

### 14.2 Custom manifests

Admin-authored manifests live at `config/utilities/<id>.yaml` (existing convention). They are validated identically to bundled manifests but do not require fixtures or goldens (recommended but not enforced).

### 14.3 CLI

```
bolt utility init <provider>          # scaffold a new manifest from template
bolt utility lint <path>              # run all save-time linter checks
bolt utility test <path> [--fixture F]# run flows against fixtures, diff against goldens
bolt utility preview <path> [--scope S --query Q]
                                      # render result list against fixtures, print as table
bolt utility publish <path>           # POST to /api/admin/utility-contracts (requires admin token)
```

### 14.4 Mock MCP

A built-in mock MCP server replays fixture JSON for any `tools/list` and `tools/call` request:

- `mcp.mock_dir`: filesystem path containing `<provider>/<tool>__<scenario>.json`
- The wizard's "Live preview" pane calls the mock when no real MCP token is present.
- The CLI's `bolt utility test` always uses the mock.

---

## 15. Examples

### 15.1 `=jira` (single MCP, multiple scopes)

See [samples/jira.yaml](/docs/utilities/samples/jira.yaml) (shipped with bundled catalog).

### 15.2 `=team` (Person type, composite actions)

See [samples/team.yaml](/docs/utilities/samples/team.yaml).

### 15.3 `=incidents` (multi-MCP parallel + merge)

See [samples/incidents.yaml](/docs/utilities/samples/incidents.yaml).

### 15.4 `=cafes` (HTTP-only public API, type Place)

See [samples/cafes.yaml](/docs/utilities/samples/cafes.yaml).

---

## 16. Versioning

This document specifies `schema_version: 1`. Future changes:

- **Additive non-breaking** (e.g. new template filter, new widget kind): bump to `schema_version: 2`; v1 manifests load identically; v2 manifests carry `schema_version: 2` and may use new fields.
- **Breaking**: never. If a breaking change is required, it ships as a new spec entirely (`schema_version: 3` etc.) with a clear migration path documented separately.

The `schema_version` field is the only versioning mechanism. There is no implicit version inference, no "latest" mode.

---

## 17. Out of scope for v1

Documented here so that no one re-asks:

- Service-account auth in any form. Per-user OAuth only.
- Conditional execution (`when:`, `if:`, ternary in templates).
- Loops or iteration in flows.
- Stateful multi-turn flows ("ask user, then call, then ask again"). Use a skill or agent loop.
- Custom JS/Python adapters. The escape hatch is jq + custom MCP tools.
- Drag-and-drop visual flow editor. Wizard cards + YAML side panel cover authoring.
- A public manifest registry / marketplace. Local repo + CLI for community.
- Manifest signing (sigstore). Bundled manifests are SHA-pinned; signing comes later.
- Webhook-driven cache invalidation.
- OpenAPI -> MCP wrapper generator. Useful, but a separate tool.
- Cross-utility flow composition at the data-plane level (one utility's emit feeds another utility's flow). Use `kind: utility` actions for navigation; this is sufficient for v1.
- Voice input parsing into filters.

---

## 18. Definition of done for v1

- This document frozen and committed to `bolt-api`.
- Backend flow engine implemented with all 5 node kinds, jaq sandbox, linter, type checker, field allowlist, warm cache, streaming parallel, circuit breaker, idempotency keys, audit log.
- Backend runtime endpoint `POST /api/runtime/utility/<id>` returns rows or `needs_oauth` per §13.1.
- Frontend wizard implements all five Add/Edit cards with MCP introspection and YAML side panel.
- CLI `bolt utility init/lint/test/preview/publish` works end-to-end with mock MCP.
- Three reference manifests work end-to-end: `=jira`, `=team`, `=incidents`. Plus `=cafes` for HTTP-only validation.
- All bundled manifests have fixtures, goldens, and pass CI.
- Per-utility metrics visible in admin observability dashboard.
- The pre-existing `service_user`, `bearer_token` (shared), `basic`, `mtls`, `signed_jwt_assertion`, `oauth2_client_credentials`, `oauth2_on_behalf_of`, `session_passthrough` auth profile types are removed from `auth-profiles.yaml` and rejected by the loader.

---

## 19. Bridge runtime (User Apps)

The same manifest schema supports a family of **local runtimes** for User Apps. An author opts in by setting `runtime:` at the top level to one of the user-authorable transports. As of this version there are two: `bridge` (argv-only shell command) and `http_local` (a single read against a loopback service). Both run on the end user's machine under their own OS identity, with no admin-controlled fields, no flow DAG, no MCP wiring, and no auth profile: just a data source, an output parser, a presentation block, and a small set of declared actions.

Customer-facing name: **User App**. Codename in code and YAML: `utility` / `runtime: bridge` (or `runtime: http_local`).

> **Why two runtimes.** Shell (`bridge`) covers pre-authenticated CLIs (`git`, `gh`, `kubectl`, `aws`). Loopback HTTP (`http_local`) covers local daemons that speak HTTP but have no CLI worth shelling out to: Docker, Ollama, a dev server, a browser's CDP endpoint. Both are local-only by construction.

### 19.1 Discriminator

```yaml
runtime: bridge        # or: http_local
```

`runtime` is required and must be one of the values in `ALLOWED_RUNTIME`, currently `bridge` or `http_local`. The set is reserved so future transports (`wasm`, `subprocess`, `sql`, `osa`, …) can be added without breaking parsers; a runtime not in the set is rejected at load.

Other top-level rules the loader enforces for user manifests:
- `schema_version` must equal `1`.
- `id` and `chip` must each match `^[a-z0-9][a-z0-9-]{0,63}$` (lowercase-kebab). Unlike admin manifests (§4), the User App `chip` is a **bare key with no `=` prefix**: the launcher adds the leading `=` when it surfaces the chip.
- `emits` must be one of the canonical types (§12) or `Generic`.
- Exactly one transport block must be present and must match the declared runtime: `runtime: bridge` requires a `bridge:` block and rejects an `http:` block; `runtime: http_local` requires an `http:` block and rejects a `bridge:` block.

### 19.2 Forbidden fields

The runtime rejects every admin-only field at load time. Presence is the rejection; the loader does not silently ignore. A manifest that sets any of the following fails to load and the user sees a per-file error in Settings:

- `auth_profile_ref`
- `requires`
- `scopes` (v1 User Apps have a single implicit scope)
- `filters`
- `cache_ttl_seconds`
- `provisioning_mode`, `departments`, `roles`, `groups`
- `actions[].kind` other than `url`, `composer`, or `utility`
- `actions[].flow`, `actions[].confirm` (these are admin tool-action fields)
- `bridge.command.<os>` (and `detect.auth_check.<os>`) containing `;`, `&&`, `||`, `|`, backtick, or `$(...)` outside a `{{…}}` placeholder. Multi-statement shell is rejected at validate time, before the manifest ever loads.
- `bridge.env.<KEY>` with an inline literal. Keys must match `^[A-Z_][A-Z0-9_]*$` and values must match exactly `^\$\{env:[A-Z_][A-Z0-9_]*\}$`; secrets come from the real process env, never the manifest.

Forbidden-field errors include the offending field name so authors can fix without grepping the spec.

### 19.3 Forced fields

The loader / parser stamps these on every emitted row regardless of what the YAML (or the command's own JSON output) asks for. They are write-once by the runtime; an author who emits `canEscalateAi: true` from a `parse: json` command sees it forced back to `false`:

- `canEscalateAi: false`
- `aiSuggestedQuery: null`
- `quickQaActionQuery: null`
- `escalationPrompt: null`
- `source: "user_bridge"`, the lineage tag the PWA and audit log key on

User Apps are also forced to `dispatch.mode: confirm` (§19.7). Authors can customize the confirm label/hint text but cannot turn confirm off. Shell exec on incremental keystrokes is not a thing the runtime ships.

### 19.4 The `bridge:` block (`runtime: bridge`)

```yaml
bridge:
  command:
    macos:   "git -C ~/dev/{{repo}} log --oneline -{{limit | default: 20}}"
    linux:   "git -C ~/dev/{{repo}} log --oneline -{{limit | default: 20}}"
    windows: 'git -C C:\\dev\\{{repo}} log --oneline -{{limit | default: 20}}'
  parse: lines
  timeout_seconds: 5
  env:
    GH_TOKEN: "${env:GH_TOKEN}"
```

Fields:
- `command.<os>`: templated command for that OS. At least one of `macos`, `linux`, `windows` required. Templating supports `{{var}}` and `{{var | default: X}}`. Each present command must be argv-splittable and free of the forbidden shell metacharacters (§19.2).
- `parse`: `lines` (one row per non-empty stdout line, fields `{line, idx}`), `json` (expects a top-level array or `{rows: [...]}`), or `raw` (one row total, field `{raw}`).
- `timeout_seconds`: optional, clamped to `1..=60`, default `10`. On timeout the child is killed and reaped.
- `env`: optional env-var refs that must already be set in the user's process. `${env:VARNAME}` form only; the loader rejects inline literals.

### 19.5 The `http:` block (`runtime: http_local`)

A single read request to a service listening on the loopback interface. The loopback-host gate is the load-bearing rule: it makes "this utility cannot egress off-box" a property an auditor can confirm from the manifest alone, not a promise.

```yaml
runtime: http_local
http:
  port: 11434                  # loopback TCP port the local service listens on
  host: 127.0.0.1              # optional; one of 127.0.0.1 | ::1 | localhost (default 127.0.0.1)
  request:
    method: GET                # GET (default) or POST — read-first v1
    path: "/api/tags"          # must start with '/'; templated, values percent-encoded
  parse: json                  # json | lines | raw (same row shapes as the bridge parser)
  rows_path: models            # optional dotted path to the row array inside a JSON object
  timeout_seconds: 5           # optional, clamped to 1..=60
  headers:
    Authorization: "${env:OLLAMA_TOKEN}"   # ${env:VAR} ref or a plain literal
```

Fields:
- `port`: required, non-zero loopback port.
- `host`: optional, restricted to `127.0.0.1`, `::1`, or `localhost` (default `127.0.0.1`). Any other host is rejected at load; there is intentionally no way to point this transport off-box.
- `request.method`: `GET` (default) or `POST`. Mutating verbs are out of scope for this read-first version.
- `request.path`: required, must start with `/`. Templated with `{{var}}`; values are **percent-encoded** at expand time (never shell-quoted) so a query term cannot break out of the path or inject extra parameters.
- `parse`: same `json` / `lines` / `raw` modes and row shapes as `bridge.parse`.
- `rows_path`: optional dotted path to the row array inside a JSON object response (e.g. `models` for Ollama's `{ "models": [...] }`). Absent ⇒ the body must be a top-level array or `{ rows: [...] }`.
- `timeout_seconds`: optional, clamped to `1..=60`.
- `headers`: optional static request headers. Keys match `[A-Za-z0-9-]+`; values accept a `${env:VAR}` ref or a plain literal (a local service often wants a static token).

### 19.6 The `args:` block

Both runtimes can declare named arguments derived from the user's query, referenced as `{{name}}` inside `command.<os>` / `request.path`, in action templates, and in `dispatch.choices[].args`.

```yaml
args:
  - { name: repo,  from: "query.word(0)" }
  - { name: limit, from: "query.word(1)", default: 20 }
```

- `name`: non-empty identifier.
- `from`: how to source the value. Only `query.word(N)` (zero-indexed whitespace token of the post-chip query) is supported in v1; anything else is rejected.
- `default`: optional fallback when the query word is absent.

### 19.6.1 Input forms (`inputs:`)

A `runtime: bridge` or `runtime: http_local` User App may declare an `inputs:` block to collect typed values via a rendered form **before** running, instead of parsing the query string. When `inputs` is non-empty the launcher shows a typed form; on submit each field value is passed as an invoke arg and binds as `{{<name>}}` in the command/templates (caller args take precedence over query-derived args). It is purely declarative; there is intentionally no `show_if` / computed / validation-expression surface (logic belongs in the script). All values are strings (`toggle` = `"true"`/`"false"`).

Frozen field types (adding one is a spec version bump): `text`, `number`, `date`, `select`, `toggle`, `secret`.

```yaml
inputs:
  - name: <matches ^[a-z][a-z0-9_]*$, unique within the form>
    type: text | number | date | select | toggle | secret
    label: <non-empty>
    required: <bool, default false>
    default: <value; for date, "today" resolves to the local date>
    placeholder: <string>             # text | number | secret
    options: [<string>, ...]          # select only — REQUIRED for select
    min: <number>  max: <number>  step: <number>   # number constraints
    max_length: <int>                 # text constraint
submit:
  label: <submit button label, default "Run">
  confirm: <bool, default false>
```

Validation (save-time): each `name` matches the regex and is unique; `type` is in the frozen set; `label` is non-empty; a `select` must declare non-empty `options`.

Example (`=expense`):

```yaml
inputs:
  - { name: amount, type: number, label: Amount, required: true, min: 0, step: 0.01 }
  - { name: category, type: select, label: Category, default: Meals, options: [Meals, Travel, Software, Office, Other] }
  - { name: date, type: date, label: Date, default: today }
  - { name: description, type: text, label: Description, max_length: 120 }
  - { name: billable, type: toggle, label: Billable, default: true }
submit: { label: Log expense }
bridge:
  command:
    macos: "bash {{scripts_dir}}/bolt-expense.sh {{amount}} {{category}} {{date}} {{description}} {{billable}}"
  parse: json
```

The bundled `=demo-chart`, `=demo-table`, `=demo-cards`, `=demo-detail`, `=demo-tree`, and `=demo-diff` sample apps showcase every right-widget (§9.6) with zero setup.

### 19.7 The `dispatch:` block

User Apps fire on intentional Enter, not on every keystroke. `dispatch.mode` is forced to `confirm`; declaring `auto` is rejected. The block is optional; absent ⇒ a single confirm row with default label/hint.

```yaml
dispatch:
  mode: confirm                          # only allowed value; default if block omitted
  confirm_label: "Search Jira for \"{{query}}\""
  confirm_hint: "Press Enter or Tab to run"
```

Or, for a multi-verb chip, a chooser of synthetic rows:

```yaml
dispatch:
  mode: confirm
  choices:
    - { id: save,   label: "Save \"{{query}}\"",   args: { verb: save } }
    - { id: search, label: "Search \"{{query}}\"", args: { verb: search } }
```

Rules:
- `confirm_label` / `confirm_hint` customize the single confirm row's text.
- `choices[]` renders one synthetic row per entry instead of a single confirm row. Each choice has a unique `id`, a templated `label`, an optional `hint`, and an `args` map merged onto the query-derived args when the row activates. Every `args` key must reference a declared `args[].name`; a chooser cannot smuggle arbitrary template vars.
- `choices` and `confirm_label`/`confirm_hint` are **mutually exclusive**: pick one chooser pattern per chip.

### 19.8 The `detect:` block (device probe)

Optional. When present, the launcher only surfaces the chip after confirming the backing binary is installed, new enough, and (optionally) authenticated, so a `gh`/`kubectl`/`aws` chip stays hidden on machines where it can't actually run. Absent ⇒ the chip is always available (legacy behaviour). Purely additive.

```yaml
detect:
  binary: gh                       # bare program name resolved on PATH (never an absolute path)
  version_min: "2.40.0"            # optional; loose semver compare against `<binary> --version`
  auth_check:                      # optional per-OS auth-status command (exit 0 ⇒ authenticated)
    macos:  "gh auth status"
    linux:  "gh auth status"
  config_hint: ["~/.config/gh"]    # optional; presence boosts detection confidence, never required
  refresh: on_focus                # on_boot | on_focus | manual (default on_focus)
```

`binary` must be a bare name (PATH lookup), never a path. `auth_check` commands go through the **same argv-only, no-shell-metacharacter gate** as `bridge.command`, and by review of the curated pack are restricted to read-only status verbs. This is the user-tier shape: the admin curated pack carries the same block plus capability bindings, but capabilities/ACL stay admin-only: a user-authored `detect` can light a chip but cannot grant itself governed verbs.

### 19.9 argv-only execution

For `runtime: bridge`, the command template is expanded with the args block, every interpolated value is shell-quoted, and the result is tokenized into argv via POSIX shell-words and spawned directly. There is no `/bin/sh -c`. The shell-metacharacter rejection at validate time means the argv-split is always unambiguous; ambiguity is a reject. The child runs with the user's `$HOME` as its working directory, stdin closed, and stdout/stderr captured separately.

This is the runtime mechanism behind the "Bolt does not multiply the user's authority" claim. The command can only do what a single binary invocation could do, the same constraint the user's terminal has when they type the command themselves. For `runtime: http_local`, the equivalent guarantee is the loopback-host pin: the request can only reach a process already listening on the user's own machine.

### 19.10 Presentation: current restrictions

User Apps render through the **same** launcher dropdown and right-rail components as admin utilities (the PWA does not branch on runtime). Today the user-tier `presentation` block is a deliberate subset of the admin shape (§9):

- `widget`: `list`, `table`, `cards`, or `detail`. `image_grid` is **not** allowed in v1.
- Supported presentation fields: `title_field`, `subtitle_field`, `searchable`, and `right_widget`. The richer admin fields (`list_fields`, `table_columns`, `image_field`, `primary_value_field`, `search_fields`, `filter_fields`, `sort_field`/`sort_order`, `row_key_field`, `filterable`) are not yet part of the user-tier `presentation`.
- `right_widget.kind`: `card`, `map`, `image`, `calc`, `color`, `weather`, `date`, `markdown` (see §9.1), `entity_preview` (the wide rich-detail pane: media + title/subtitle + label/value facts + an optional rendered-Markdown `body`; remote images in the body are blocked for no-egress), or the rich data-viz panes `chart`, `table`, `cards`, `detail`, `json_tree`, `diff`, `image_grid` (see §9.6, these render the parsed `rows` and do not bind to the entity graph). Only `entity` is rejected, and `links_for_type` is unavailable. The validator names the rejection so authors don't assume a typo:

> `presentation.right_widget.kind 'entity' not in [card, map, image, calc, color, weather, date, markdown, entity_preview, chart, table, cards, detail, json_tree, diff, image_grid] (entity kind is not allowed for user utilities)`

`entity_preview` is presentation-only; it renders through the shared `EntityPreviewPane` and does **not** bind to the launcher's entity router. The router-binding `entity` kind (and `links_for_type`) remain excluded so a User App can't graft itself onto the entity graph or grant itself governed verbs. See §19.15.

- `actions[].kind`: `url`, `composer`, or `utility`. `tool` (server-side MCP invocation) and `clipboard` are not available to User Apps in v1. A `url` action requires `url_template`; `composer` requires `insert`; `utility` requires `target_chip` (with optional `query_template`) and rejects `url_template`/`insert`.

### 19.11 Install model

Drop a `.yaml` into the user-apps folder and click Reload in Settings. There is no file picker, no consent modal, no two-step handshake. The act of copying the file into the folder IS the consent. Removing the App via Settings deletes the file from disk.

Per-OS folder paths (resolved via Tauri's app-data dir):
- macOS: `~/Library/Application Support/<bundle>/user-utils/`
- Linux: `~/.local/share/<bundle>/user-utils/`
- Windows: `%APPDATA%/<bundle>/user-utils/`

### 19.12 Org / device policy

Admins on managed devices can disable the entire User App tier with a single toggle. When off:
- The chip list returned to the launcher is empty.
- The launcher detector stops proposing user keys, and chip-pill conversion no longer fires for them.
- Invocation refuses at the runtime boundary with a clear error.
- Manifest files on disk are not touched. Re-enabling restores the user's setup identically.

Storage: `<app_data>/user-apps-policy.json` with `{ "enabled": bool }`. Admins managing an OS image (MDM, JAMF, Intune) can pre-write the file to `{ "enabled": false }` before the user ever opens Bolt. An org-pushed policy that propagates the gate from the admin tenant down to managed devices is a follow-up.

### 19.13 Audit shape

User App invocations produce an optional audit ping when the device is configured to send one. The payload is metadata only: `{utility_id, ts, ok, duration_ms}`. No query, no arguments, no output, no stdout, no stderr. The Bolt service is not in the request path, and Sparcle servers are not in the data path.

### 19.14 Examples

A complete `runtime: bridge` User App, with an optional `detect` gate so the chip only appears when `git` is installed:

```yaml
schema_version: 1
runtime: bridge
id: git-log
chip: git-log
title: Recent commits
icon: git-branch
description: Show recent commits in a local git repo under ~/dev
placeholder_examples: ["my-app", "infra 30"]
emits: Generic

detect:
  binary: git
  version_min: "2.30.0"
  refresh: on_focus

bridge:
  command:
    macos:   "git -C ~/dev/{{repo}} log --oneline -{{limit | default: 20}}"
    linux:   "git -C ~/dev/{{repo}} log --oneline -{{limit | default: 20}}"
    windows: 'git -C C:\\dev\\{{repo}} log --oneline -{{limit | default: 20}}'
  parse: lines
  timeout_seconds: 5

args:
  - { name: repo,  from: "query.word(0)" }
  - { name: limit, from: "query.word(1)", default: 20 }

presentation:
  widget: list
  title_field: line
  subtitle_field: idx

actions:
  - { id: copy, kind: composer, target: row, label: Copy SHA, insert: "{{line}}" }
```

A complete `runtime: http_local` User App reading the local Ollama daemon's model list:

```yaml
schema_version: 1
runtime: http_local
id: ollama-models
chip: ollama-models
title: Local Ollama models
icon: cpu
description: List models pulled into the local Ollama daemon
emits: Generic

http:
  port: 11434
  request:
    method: GET
    path: "/api/tags"
  parse: json
  rows_path: models
  timeout_seconds: 5

presentation:
  widget: list
  title_field: name
  subtitle_field: details.parameter_size
```

The runtime takes care of confirm-row dispatch, argv-only spawn (or the loopback read), output parsing, row construction, forced-field stamping, and rendering. The author writes ~25 lines of YAML and no code.

### 19.15 Parity roadmap (planned, not yet enforced)

The design intent is that a User App should reach **the full admin presentation and format surface** (§9, §12), the only enduring difference being *where the data comes from* (a local shell command or loopback HTTP, rather than an admin's MCP/HTTP flow). The strict subset in §19.10 reflects what the loader enforces *today*, not the target.

Shipped so far:

- **Rich Markdown pane (`right_widget.kind: markdown`).** Scrollable, DOMPurify-sanitized Markdown + syntax-highlighted code, available to admin and User Apps, with the no-egress remote-image block (see §9.1).
- **`entity_preview` for User Apps + optional Markdown `body`.** The wide rich-detail pane (facts + a rendered Markdown body) is now available to User Apps; the `entity_preview` pane also gained an optional `body` for admin utilities, so a card can show facts AND a rendered description. Only the router-binding `entity` kind + `links_for_type` remain excluded for User Apps.
- **Rich data-viz right-widgets (`chart`, `table`, `cards`, `detail`, `json_tree`, `diff`, `image_grid`).** Available to admin and User Apps via `right_widget.kind`; they render the parsed `rows` (plus a declarative `bind`) and do not bind to the entity graph (see §9.6). The bundled `=demo-*` sample apps showcase each.
- **Input forms (`inputs:`).** A declarative typed form (`text`/`number`/`date`/`select`/`toggle`/`secret`) that collects values before a User App runs and binds them as invoke args (see §19.6.1).

Planned additions, each additive and gated behind the same load-time validator:

- **Full presentation parity.** Admit the remaining `presentation` fields (`list_fields`, `table_columns`, `image_field`, `primary_value_field`, `search_fields`, `filter_fields`, `sort_field`/`sort_order`, `row_key_field`, `filterable`) and the full-width main-presentation `image_grid`/`table`/`cards`/`detail` widgets (these ship today only as right-widget panes, §3, §9.6). These are pure client-side rendering with no security surface; the PWA already renders them on the admin path, so this is a contract relaxation plus matching user-tier types.
- **`clipboard` actions.** Client-side only (copy a templated value); safe to admit alongside `url`/`composer`/`utility`.
- **Entity router surface (remaining).** `entity_preview` already landed for User Apps (above). Still planned: the router-binding `entity` kind and `links_for_type` cross-utility links, so User Apps can participate in the entity router and the cross-utility "Related" section. That step requires the router to treat `source: "user_bridge"` rows as first-class without letting a manifest grant itself governed verbs (the §19.2–§19.3 gates continue to hold).

What stays out of scope for User Apps regardless of presentation parity: the admin **data plane**, namely `auth_profile_ref`, `requires`, MCP/HTTP flow DAGs, `kind: tool` actions, server-side execution, and credential-bearing transports. A User App presents like an admin utility; it does not acquire an admin utility's authority.
