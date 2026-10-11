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

## Other notes

- `claude -p` runs launched from inside a Claude session must clear the session variables first, otherwise they run as child sessions.
- A `SessionEnd hook ... failed: Hook cancelled` line from a plugin appears at the end of some `-p` runs; harmless.
