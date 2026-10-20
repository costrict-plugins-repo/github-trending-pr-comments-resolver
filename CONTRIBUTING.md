# Contributing to PR Comments Resolver

Thank you for your interest in contributing! This document explains how to get started.

## Ways to Contribute

- **Bug reports** — open an issue describing what happened and what you expected
- **Feature requests** — open an issue with the label `enhancement`
- **Pull requests** — fixes, improvements, or new platform support

## Development Setup

This repository ships generated outputs for multiple agents. The canonical logic lives in `core/` and `adapters/`; built artifacts are committed in `skills/` and `dist/`.

1. Fork the repository and clone your fork
2. Build all generated outputs:
   ```bash
   bash scripts/build.sh all
   ```
3. Install the flavor you want to test:
   Claude:
   ```
   /plugin install /path/to/your/fork
   ```
   Codex:
   ```bash
   bash scripts/install.sh codex --user
   ```
4. Open a repository with open PR/MR review comments and invoke the skill to test

## Project Structure

```
.claude-plugin/          Claude plugin manifests
.codex-plugin/           Codex plugin manifest
.agents/plugins/         Codex repo-scoped marketplace manifest
.augment-plugin/         Augment plugin manifests
plugins/                 Generated marketplace-ready plugin bundles
core/                    Canonical workflow and platform modules
adapters/                Per-agent frontmatter, prelude, and snippets
skills/resolve-comments/ Claude build output
dist/                    Generated outputs for Codex, Augment, Junie, and Roo
```

## Making Changes

### Editing the Skill

Edit the canonical files, not the generated outputs:

- `core/kernel.md`
- `core/platforms/*.md`
- `adapters/<agent>/...`

Then rebuild:

```bash
bash scripts/build.sh all
python3 scripts/validate.py
bash tests/build_test.sh
```

### Adding a New Skill

1. Create `skills/<skill-name>/SKILL.md` with the required YAML frontmatter:
   ```yaml
   ---
   name: skill-name
   description: "Use when ..."
   trigger: /skill-name
   ---
   ```
2. Follow the existing step structure
3. Update `README.md` to document the new skill

### Editing Manifests

- `.claude-plugin/plugin.json` — Claude plugin identity
- `.claude-plugin/marketplace.json` — Claude marketplace listing
- `.codex-plugin/plugin.json` — Codex plugin identity and skill path
- `.agents/plugins/marketplace.json` — Codex repo-scoped marketplace listing
- `.augment-plugin/*.json` — Augment manifests
- `plugins/<agent>/pr-comments-resolver/` — generated marketplace install bundles

## Commit Style

This project uses [Conventional Commits](https://www.conventionalcommits.org/):

```
feat: add Azure DevOps support
fix: handle missing glab binary gracefully
docs: update installation instructions
```

Types: `feat`, `fix`, `docs`, `refactor`, `chore`

## Pull Request Guidelines

- One concern per PR
- Reference the related issue if one exists (`Closes #42`)
- Update `CHANGELOG.md` under `[Unreleased]` with a brief description of your change
- Keep the PR description concise — what changed and why

## Releasing

Releases and generated artifacts are fully automated by the GitHub Actions workflows in `.github/workflows/`. You do **not** need to build or commit generated outputs (`skills/`, `dist/`, `plugins/`) — edit only the sources under `core/` and `adapters/`.

- On a pull request, `verify-build.yml` builds the sources and runs validation + smoke tests as a sanity check (it does not enforce drift against committed outputs).
- After a merge to `main`, `release.yml` runs a single ordered pipeline: it resolves the next version, syncs it into the manifests, rebuilds all artifacts, validates and smoke-tests them, commits the regenerated artifacts back to `main` (only if anything changed), and finally tags that commit. The tag therefore always points at the commit containing the freshly generated artifacts.

If you want to sanity-check the build locally before opening a PR:

```bash
bash scripts/build.sh all
python3 scripts/validate.py
bash tests/build_test.sh
```

## Code of Conduct

Be respectful and constructive. Issues and PRs that are hostile or off-topic will be closed.

## License

By contributing you agree that your changes will be licensed under the [MIT License](LICENSE).
