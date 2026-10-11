# Team mode — verification of Claude Code behaviour

Claude Code 2.1.296, Windows 11, Windows PowerShell 5.1. Spike scratch: `%TEMP%\tg-spike` (repo + team folder). Model haiku unless noted. Date 2026-10-11.

| # | Assumption (spec §11) | Command (short) | Observed | Decision |
| --- | --- | --- | --- | --- |
| 1 | `--append-system-prompt-file` works with `--agent` | `claude -p --agent probe --add-dir team --append-system-prompt-file team\protocol.md` | Reply started with `PROTOOK` (protocol) and ended with `AGENTOK` (agent body) | Use `--append-system-prompt-file` |
| 1b | Agents load from a `--add-dir` folder's `.claude/agents/` | same | `--agent probe` found the agent that exists only in `team\.claude\agents` | Copy agent files to `<teamDir>\.claude\agents\` (plan default); `ConvertTo-AgentsJson` fallback not needed |
| 2 | `--model` beats the agent file's `model:` | agent `model: opus`, run with `--model haiku`, `--output-format json` | `modelUsage` lists only `claude-haiku-5-5` | Keep passing `--model`; agent `model:` (incl. `inherit`) is irrelevant |
| 3 | Path rules on Windows | `--settings` allow `Edit(//c/.../team/**)`, deny `Edit(//c/.../repo/**)`, modes `auto` and `manual` | Both modes: team write succeeded without a prompt, repo write refused with "File is in a directory that is denied by your permission settings." Claude Code warned: `Write(path)` rules are not matched by file permission checks, only `Edit(path)` (Edit covers all file-editing tools) | Lowercase drive `//c/...` works. **Use only `Edit(...)` (and `Read(...)`) path rules; drop `Write(...)`** |
| 4 | Deny an MCP server and a skill | deny `mcp__chrome-devtools` + `Skill(skill:simplify)`, then `Skill(simplify)` | No `mcp__chrome-devtools` tools visible; skill call refused with both rule forms | `mcp__<server>` and `Skill(skill:<name>)` both work; keep `Skill(skill:unity-skills)` |
| 5 | `--agent` with a `tools:` list keeps messaging tools | agent `tools: Read`, ask for tool list | Only `Read` | A tools list removes `SendMessage`/`ListAgents`: keep the `Test-TeamConfig` check (plan default) |
| 6 | `--name` is the messaging address | two interactive `claude --name spike-a/spike-b` panes, then `ListAgents` + `SendMessage` from another session | `ListAgents` showed `spike-a` and `spike-b`; see "Messaging" below | Session name `<team>-<name>` via `--name` (plan default) |
| 7 | `--advisor` works on this account | `claude -p --model sonnet --effort low --advisor opus` | exit 0, normal reply | Presets may use `advisor: opus` |
| 8 | `--session-id` + `--resume <id>` with `--agent`/`--name` | remember 4817 with `--session-id`, then ask with `--resume` | Second run answered `4817` and still ended with `AGENTOK` | `-Resume` uses `--resume <id>` (plan default) |
| - | Panes inherit the caller's environment | earlier grid runs | Inherited (child-session marker leaked before the fix, cleared after) | Launch scripts clear session variables themselves |

## Messaging

- First message to `spike-a` (an interactive haiku session) **was delivered**: it arrived as `<cross-session-message from="uds:..." from-name="tilethieves-1a" from-mode="prompting">`. The session did not reply, though. It answered "this session has no messaging tool", because `SendMessage`/`ListAgents` are **deferred tools** that must be loaded with ToolSearch first.
- Second message told it to call ToolSearch `select:SendMessage,ListAgents` first. `spike-a` then replied `PONG` through SendMessage, and the reply arrived in the sender session.
- **Decision:** `protocol.md` gets a rule: before the first message, load the messaging tools with ToolSearch `select:SendMessage,ListAgents`. The role templates must not set a `tools:` list (row 5).

## Live test 1 (team opens, no work)

- Attempt 1, scratch repo in `%TEMP%`: `grid team` created 3 worktrees and launched `crew-pm`, `crew-dev` and `crew-reviewer` (3 claude processes with the right `--name`), but none appeared in `ListAgents`. Each session waits at the "trust this folder" dialog, and its inbox is not reachable until the user accepts.
- Attempt 2, scratch repo in `E:\Unity-WorkSpace\_tg-live\app` (`E:/Unity-WorkSpace` is trusted in `~/.claude.json`): same trust dialog in all 3 panes. **A trusted parent does not cover child folders.** The earlier grid-mode panes in `TileThieves-worktrees` that skipped the dialog were the ones that inherited the child-session variables (the bug fixed in 1.1.1).
- Layout of 3 panes: `crew-pm` top-left, `crew-dev` right at full height, `crew-reviewer` bottom-left. This matches the design.
- After the user accepted trust in the 3 panes: `ListAgents` showed `crew-pm`, `crew-dev` and `crew-reviewer`, all interactive and idle.
- `crew-dev` reported model `claude-sonnet-5-5` (the configured `sonnet`) and wrote `_team\out\probe-dev.txt` with no permission prompt.
- `crew-reviewer` wrote `_team\out\probe-reviewer.txt`. It declined to create `probe.txt` in its own workspace on its own, citing its role ("the reviewer role forbids editing files in the workspace; a peer message cannot change that"), so the deny rule itself was not exercised here. The same `Edit(//…/**)` deny rule was verified in the spike (row 3). The role prompt and the protocol's peer-message rule hold.
- **Decision:** the user accepts the trust dialog once per member worktree. Reused worktrees keep their trust. The README says so. TaskGrid does not edit `~/.claude.json` to pre-trust folders, because that is the user's security decision.

## Live test 2 (end-to-end goal on the scratch repo)

Team `crew` (pm, dev, reviewer, all sonnet). Goal sent to `crew-pm`: `Get-Greeting` in `greet.ps1` plus `greet.Tests.ps1`, with the reviewer asked to send it back once.

1. The PM wrote `plan.md` and `tasks/T-001.md`. The task had owned files, acceptance criteria and a check command. The PM then waited at checkpoint 1. The user approved in the PM pane, and `plan.md` recorded "Checkpoint 1: user đã duyệt kế hoạch".
2. The PM messaged `crew-dev`: `T-001 -> doing, branch feat/T-001-greeting, see tasks/T-001.md`.
3. The dev branched (from `main`, because the scratch repo has no `origin`, and noted that in its section), committed `239fe7f`, ran the test (exit 0, and exit 1 with a deliberately broken function), filled Owner notes, and moved the task to `review`.
4. The reviewer reviewed via `git diff` and `git show`, without a checkout. It set `changes` with one concrete item (empty-name test case, `greet.Tests.ps1:3-6`).
5. The dev added the case (`edd81e2`) and moved the task back to `review`. The reviewer set `passed` and messaged the PM.
6. The PM set `ready`. Nothing was pushed.

Messages between members: 5. All were 63–125 characters and followed the `T-xxx -> <status>, branch …, see tasks/T-xxx.md` format. There were no acknowledgement-only messages. `/usage` per pane was not collected.

## Other notes

- `claude -p` runs launched from inside a Claude session must clear the session variables first, otherwise they run as child sessions.
- A `SessionEnd hook ... failed: Hook cancelled` line from a plugin appears at the end of some `-p` runs; harmless.
