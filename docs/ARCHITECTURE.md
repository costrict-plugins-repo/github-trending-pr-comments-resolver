# Architecture

This repository is a **multi-agent skill plugin**. A single source is compiled into
per-agent variants for Claude Code, Codex, Augment, Junie, and Roo Code. You never
edit the compiled output by hand — you edit the sources and run the build.

## The core idea: one source, many targets

```
core/ + adapters/<agent>/        scripts/build.sh           generated, committed
─────────────────────────  ──────────────────────────▶  ─────────────────────────
core/kernel.md                                            skills/                (claude)
core/platforms/*.md                                       dist/<agent>/...       (codex, augment, junie, roo)
adapters/<agent>/frontmatter.yaml                         plugins/<agent>/...    (marketplace bundles)
adapters/<agent>/prelude.md
adapters/<agent>/snippets/*.md
```

## Source files (edit these)

| Path | Purpose |
|------|---------|
| `core/kernel.md` | The shared skill body for **all** agents. Contains `<!-- ADAPTER: <key> -->` placeholders. |
| `core/platforms/*.md` | Per-platform modules (`github`, `gitlab`, `bitbucket`, `azure`). Also contain adapter placeholders. |
| `adapters/<agent>/frontmatter.yaml` | The YAML frontmatter for that agent's `SKILL.md`. |
| `adapters/<agent>/prelude.md` | Agent-specific intro prepended before the kernel. |
| `adapters/<agent>/snippets/<key>.md` | Replacement text for each `<!-- ADAPTER: <key> -->` placeholder. A missing snippet substitutes to empty (the agent omits that step). |
| `.claude-plugin/plugin.json`, `.codex-plugin/plugin.json`, `.augment-plugin/plugin.json` | Manifest **sources**. |
| `.claude-plugin/marketplace.json`, `.augment-plugin/marketplace.json`, `.agents/plugins/marketplace.json` | Marketplace definitions. |
| `scripts/`, `tests/` | Build / install / validate / smoke-test. |

## Generated artifacts (never edit — `build.sh` overwrites them)

| Path | What | Used by |
|------|------|---------|
| `skills/resolve-comments/` | Claude's built skill | Claude discovers skills under `skills/` at the repo root, so Claude's output lives here instead of under `dist/`. |
| `dist/<agent>/...` | Built skills for the **other four** agents | `scripts/install.sh` (codex, roo, junie copy from here) and as the source for bundling (codex, augment). |
| `plugins/<agent>/pr-comments-resolver/` | Ready-to-distribute marketplace bundles | The three marketplace agents: **claude, codex, augment**. Each bundle = manifest dir + `icon.png` + `skills/`. The `marketplace.json` files point here. |

**Junie and Roo deliberately have no `plugins/` bundle and no `plugin.json`** — they have
no marketplace format and are installed only via `scripts/install.sh`.

## How the build works (`scripts/build.sh`)

For each agent:

1. Concatenate `---` + `adapters/<agent>/frontmatter.yaml` + `---` + `adapters/<agent>/prelude.md` + the substituted kernel.
2. `scripts/substitute.py` replaces every `<!-- ADAPTER: <key> -->` in `core/kernel.md` (and each `core/platforms/*.md`) with the matching `adapters/<agent>/snippets/<key>.md`.
3. Write the result to the agent's output path (`skills/` for claude, `dist/<agent>/...` for the rest), plus a sibling `platforms/` directory.
4. `package_marketplace_plugin` copies the built skill tree + manifest + icon into `plugins/<agent>/pr-comments-resolver/` (claude, codex, augment only).

```bash
bash scripts/build.sh all      # build every agent
bash scripts/build.sh claude   # build a single agent
```

## Per-agent `plugin.json`

The distinguishing field is `skills`:

| Agent | `skills` field | Notes |
|-------|----------------|-------|
| **Claude** | *(none)* | Claude auto-discovers `skills/`. Manifest has `name`, `version`, `description`, `author`, `homepage`, `license`, `icon`, `keywords`. |
| **Codex** | `"./dist/codex/skills/"` in source → rewritten to `"./skills/"` when bundled into `plugins/codex/` | Additionally carries a Codex-specific `interface` block (`displayName`, `shortDescription`, `defaultPrompt`, `brandColor`, `composerIcon`, …). |
| **Augment** | `"./dist/augment/skills/"` in source → rewritten to `"./skills/"` when bundled | Minimal manifest: `name`, `version`, `description`, `author`, `keywords`. |

The `skills`-path rewrite happens in `build.sh` (`package_marketplace_plugin`) because the
bundle ships the skills relatively under its own `skills/` directory.

## Graphify integration

The kernel opens with **Step 0: Graphify Availability**. If a `graphify` skill is available
in the running agent, the skill is *required* to use it wherever it needs to understand code,
map cross-file relationships, or make a design decision — specifically Step 4 (comment context),
Step 4b (deferred items), and Step 6 (self-review). If Graphify is absent, the flow proceeds
normally.

Detection is adapter-specific via the `<!-- ADAPTER: graphify-availability -->` placeholder
(`adapters/<agent>/snippets/graphify-availability.md`): the Claude adapter checks the harness
skills registry, while the others — which expose no registry — treat Graphify as available only
when the project demonstrably ships it. Availability is a transient session fact and is never
persisted.

## Validation (`scripts/validate.py`)

Checks every generated `SKILL.md`: required frontmatter keys (`name`, `description`),
the `description` starts with `Use when` and is ≤ 500 chars, no stray `<!-- ADAPTER: -->`
placeholders remain, all four platform modules exist per agent, and the three plugin
bundles are present and complete.

## CI/CD flow

Two workflows, distinct roles:

### `verify-build.yml` — on every pull request

Builds all agents, validates, runs the smoke test. It does **not** require contributors
to commit generated artifacts (`skills/`, `dist/`, `plugins/`) — those are produced
automatically after merge.

### `release.yml` — on push to `main`

A single ordered pipeline:

1. Determine the next SemVer version (dry-run, no tag yet).
2. Sync that version into all manifests (`.claude-plugin/`, `.codex-plugin/`, `.augment-plugin/`).
3. `bash scripts/build.sh all` — regenerate `skills/`, `dist/`, `plugins/`.
4. Validate + smoke-test.
5. Commit the regenerated artifacts + manifests back to `main` (only if changed), with `[skip ci]`.
6. Create and push the version tag **on that artifact commit** (not on the triggering merge commit).

The tag therefore always points at a commit that already contains the freshly generated
artifacts. When Claude or Codex download the repo at a tag, `skills/`, `dist/`, `plugins/`
and the versioned manifests are all present.

**Loop prevention:** commits pushed with the default `GITHUB_TOKEN` do not trigger new
workflow runs; `[skip ci]` is a second safeguard; tag pushes don't trigger the workflow.

**Branch-protection requirement:** `github-actions[bot]` (via `GITHUB_TOKEN` with
`contents: write`) must be allowed to push directly to `main`. If `main` requires pull
requests, the bot must be on the bypass list — otherwise step 5 fails.

## Working on the project

1. Edit `core/` (content) and/or `adapters/<agent>/` (per-agent), or a `.X-plugin/plugin.json` (manifest).
2. Run `bash scripts/build.sh all`.
3. Run `python3 scripts/validate.py` and `bash tests/build_test.sh`.
4. Never hand-edit `skills/`, `dist/`, or `plugins/` — they are regenerated.
