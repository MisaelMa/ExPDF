# Skill Registry

**Delegator use only.** Any agent that launches sub-agents reads this registry to resolve compact rules, then injects them directly into sub-agent prompts. Sub-agents do NOT read this registry or individual SKILL.md files.

See `_shared/skill-resolver.md` for the full resolution protocol.

## User Skills

| Trigger | Skill | Path |
|---------|-------|------|
| Creating a pull request, opening a PR, or preparing changes for review | branch-pr | /Users/amir/.claude/skills/branch-pr/SKILL.md |
| Creating a GitHub issue, reporting a bug, or requesting a feature | issue-creation | /Users/amir/.claude/skills/issue-creation/SKILL.md |
| User says "judgment day", "review adversarial", "dual review", "doble review", "juzgar" | judgment-day | /Users/amir/.claude/skills/judgment-day/SKILL.md |
| User asks to create a new skill, add agent instructions, or document patterns for AI | skill-creator | /Users/amir/.claude/skills/skill-creator/SKILL.md |
| Writing Go tests, using teatest, or adding test coverage | go-testing | /Users/amir/.claude/skills/go-testing/SKILL.md |

## Compact Rules

Pre-digested rules per skill. Delegators copy matching blocks into sub-agent prompts as `## Project Standards (auto-resolved)`.

### branch-pr
- Every PR MUST link an approved issue (`Closes #N` / `Fixes #N` / `Resolves #N`) — blank PRs are blocked
- Every PR MUST have exactly one `type:*` label
- Branch naming MUST match `^(feat|fix|chore|docs|style|refactor|perf|test|build|ci|revert)/[a-z0-9._-]+$`
- Use conventional commits; never use `Co-Authored-By` lines
- Wait for automated checks to pass before merge
- PR body must follow `.github/PULL_REQUEST_TEMPLATE.md` and start with the linked-issue line

### issue-creation
- Blank issues are disabled — MUST use a template (Bug Report or Feature Request)
- Every new issue auto-gets `status:needs-review`; a maintainer MUST add `status:approved` before any PR opens
- Search existing issues for duplicates before filing
- Questions go to GitHub Discussions, not issues
- Fill ALL required fields (description, repro/expected/actual for bugs; problem/solution/alternatives for features)
- Auto-labels are applied by the template — do not add `bug`/`enhancement` manually

### judgment-day
- Launch TWO sub-agent judges in parallel (async, never sequential); never review yourself as the orchestrator
- Both judges receive the SAME target with IDENTICAL prompts and the SAME `## Project Standards (auto-resolved)` block
- Judges work blind — no awareness of each other; no cross-contamination
- Resolve the registry (engram → `.atl/skill-registry.md`) BEFORE launching judges; warn if missing
- Synthesize verdicts in the orchestrator: Confirmed (both) > Suspect A/B (one) > Contradiction (disagree)
- Iterate at most 2 fix-then-rejudge rounds; escalate to human after that
- Inject project standards into the Fix Agent prompt as well, identical to the judges

### skill-creator
- Skill files live at `skills/{skill-name}/SKILL.md` with required frontmatter (`name`, `description` with `Trigger:`, `license`, `metadata`)
- Description must include a clear `Trigger:` line so AIs know when to load
- Keep SKILL.md under ~200 lines; offload long examples to `assets/` and link to `references/`
- Sections: `When to Use`, `Critical Patterns`, `Code Examples`, `Commands`, `Resources`
- Don't create a skill for trivial / one-off / already-documented patterns
- Compact rules in this registry are 5–15 lines per skill — actionable only, no fluff

### go-testing
- Use table-driven tests with `tests := []struct{ name, ... }` and `t.Run(tt.name, ...)`
- Assert errors with `(err != nil) != tt.wantErr` then early `return`
- Bubbletea TUI: use `teatest` for component testing
- Prefer golden files for large output assertions
- Built-in coverage: `go test -cover ./...`
- This project is Elixir, not Go — this skill rarely applies here

## Project Conventions

| File | Path | Notes |
|------|------|-------|
| (none) | — | No project-level convention files (`agents.md`, `CLAUDE.md`, `.cursorrules`, `GEMINI.md`, `copilot-instructions.md`) found in the project root |

Read the convention files listed above for project-specific patterns and rules. All referenced paths have been extracted — no need to read index files to discover more.
