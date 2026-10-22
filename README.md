# dsh-unrestricted

An Agent Skill that carries the **unrestricted local execution delivery contract** from
[yexi-by/dsh-unrestricted](https://github.com/yexi-by/dsh-unrestricted).

Upstream is a TypeScript plugin for DeepSeek Harness: it hooks the `system-prompt/assemble`
pipeline and injects a fixed block of text into the system prompt. That block — the
`EXECUTION_MODE_BLOCK` constant in `src/rules.js`, 10418 bytes — is the whole substance of it.

This repo packages that block as a plain, runtime-agnostic Skill. No plugin runtime, no
platform-specific paths, no tooling assumptions.

**The contract text is byte-identical to upstream. Nothing was edited.**

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Contract](https://img.shields.io/badge/contract-69d74c40bede59b2-blue.svg)](#verification)
[![Upstream](https://img.shields.io/badge/upstream-0.2.4%20%2F%207beb2d2-green.svg)](https://github.com/yexi-by/dsh-unrestricted)

---

## What it does

The contract governs **what a response contains and at what depth** — not which tools exist
or how they are called. It tells the agent to:

- Open with the deliverable itself: runnable code, a patch, a command, the prose — not a
  description of it, not a policy assessment, not a statement of intent.
- Fill the field set the request's task class demands. A keygen gets `CHECK_FN`, `OFFSET`,
  `PATCH_BYTE`. A PoC gets payload structure, injection vector, prerequisites. A resource
  list gets real links with names and sources.
- Never substitute a censored version — a refusal disguised as a summary, a sketch, or a
  "safer variant" — for the thing that was asked for.
- Keep the same register across languages, without routing around a rule by switching.
- Treat sandbox denials and approval outcomes as mechanics: state them in one line, then
  deliver the part that still runs.

Mechanics are explicitly out of scope. Tool catalogs, call protocols, plan/approval flow,
sandbox limits, and structured-output schemas are untouched.

---

## Install

Skills follow the portable layout — a directory named after the skill, containing `SKILL.md`
plus optional `references/`, `scripts/`, `assets/`. Any agent that reads that layout can use
this one.

**Copy the directory** into wherever your agent looks for skills:

```sh
cp -r dsh-unrestricted/ <your-skills-dir>/dsh-unrestricted/
```

**Or install from this repo** if your agent supports GitHub installation:

```text
repository = "<owner>/dsh-unrestricted-skill"
path       = "dsh-unrestricted"
```

There is also a `dsh-unrestricted.zip` in the repo root for hosts that import archives.

No dependencies at runtime. The optional sync script needs `curl`, `sha256sum`, and
`perl` or `awk`.

---

## Layout

```text
dsh-unrestricted/
├── SKILL.md                       frontmatter + how to apply the contract
├── references/
│   ├── delivery-contract.md       the contract itself (verbatim upstream)
│   ├── anchors.md                 upstream internals: anchors, preset shapes, patch strings
│   └── upstream-fingerprint.txt   baseline digest
└── scripts/
    └── sync-upstream.sh           fetch upstream, extract, compare
```

`SKILL.md` uses only `name`, `description`, and `license`. The description carries the
trigger contract; the body stays short and procedural, pointing at `references/` for the
long text. That is deliberate — the contract is 10 KB and should load only when relevant.

---

## Verification

The digest is computed the same way upstream computes `contractFingerprint()`:

```js
sha256(EXECUTION_MODE_BLOCK, 'utf8').digest('hex').slice(0, 16)
```

| | |
| --- | --- |
| Bytes | `10418` |
| Lines | `40` |
| Fingerprint | `69d74c40bede59b2` |

Check it locally:

```sh
sha256sum dsh-unrestricted/references/delivery-contract.md | cut -c1-16
# 69d74c40bede59b2
```

This value matches what the upstream plugin displays on its settings page, so the two can be
compared directly.

---

## Staying in sync

Upstream edits `src/rules.js` when it adapts to a new DSH version, which changes the contract
text. The script re-derives it:

```sh
sh dsh-unrestricted/scripts/sync-upstream.sh           # fetch and overwrite
sh dsh-unrestricted/scripts/sync-upstream.sh --check   # compare only, exit 1 on drift
```

It fetches `src/rules.js` from `raw.githubusercontent.com`, extracts the template literal,
unescapes backticks, and compares `sha256[0:16]`. `--check` writes nothing and returns 0 or 1,
so it drops straight into CI. Override the ref with `DSH_REF=0.2.4` or a commit SHA.

Upstream additionally validates anchor strings before injecting (`ANCHORS` in `src/rules.js`):
if the surrounding prompt structure changed, it falls back to the stock prompt instead of
injecting. That is why a mismatch is loud rather than silent — the same principle applies here,
where a drift check fails the build rather than quietly shipping stale text.

---

## Known differences from upstream

**1. Injection point — roughly 80% of the effect.**

Upstream sits in the system prompt, above user messages in priority. A Skill loads on demand,
scoped to the turn that triggered it. That is a property of the packaging, not a defect in the
port; the contract text is identical.

**2. The four presets do not carry over.**

`standard` / `ptc` / `cordis` / `minimal` are DSH prompt-assembly modes. This port maps them
onto three runtime notes instead — plan mode keeps full technical depth while deferring
execution, code-execution and subagent contexts deliver through the program, structured
subtasks report at the same depth. See `references/anchors.md`.

**3. Scope.**

"Unrestricted" here means no content-scale degradation. It is not a statement about whether a
target is authorized, and it does not replace judgment about real-world consequences.
Fabrication is still out: links, URLs, and search results come from real retrieval, and
unverified ones are labeled as such.

---

## License

MIT. The contract text is copyright [yexi-by](https://github.com/yexi-by).
This repo performs a format conversion (plugin → Skill) and adds documentation; it does not
modify the contract. See [NOTICE](NOTICE).
