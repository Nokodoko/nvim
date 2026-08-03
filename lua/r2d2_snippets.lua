-- N-agent body generator for the r2-d2 / r2-d2-project markdown snippet
-- family (originally static entries in after/snippets/markdown.json).
--
-- Why this exists: the user's redundancy complaint after testing the r2-d2
-- family was that the roster lists N agents but the per-agent YAML runtime
-- config block only ever appeared once. Static JSON snippet bodies can't
-- repeat a block a variable number of times, so harness/project bodies are
-- generated here and inserted directly via MiniSnippets.default_insert()
-- (see the :R2D2Harness / :R2D2Project user commands in plugin/30_mini.lua),
-- bypassing the passive prefix-trigger path entirely for the "choose N" case.
--
-- Bare `r2-d2<Tab>` / `r2-d2-project<Tab>` still work exactly as before and
-- expand to the DEFAULT_AGENT_COUNT template with zero prompting -- that
-- path is unaffected function-loader logic in after/snippets/markdown.lua
-- that just calls M.harness_body(M.DEFAULT_AGENT_COUNT) / M.project_body(...).
--
-- r2-d2-agent is intentionally NOT covered here: it builds exactly ONE new
-- agent via a fixed collaborating PAIR (the pi-claude + pi-gpt-5.5 review
-- convention used throughout this file's other templates), which is not the
-- "N agents in a harness/roster" the user asked about. It stays a plain
-- static entry in after/snippets/markdown.json, unchanged.

local M = {}

M.DEFAULT_AGENT_COUNT = 2

local HARNESS_ART = {
  '      .-.',
  '     |_:_|',
  '    /(_Y_)\\',
  '   ( \\/M\\/ )',
  "   /`-._.-'\\",
  '  /         \\',
  '  |         |',
  '  |         |',
  '  |         |',
  '  |         |',
  '  |         |',
  '  |         |',
  '  |         |',
  "  '---------'",
}

--- Render the next sequential tabstop and advance the shared counter.
---@param counter table `{ id = <int> }`, mutated in place.
---@param default string
local function ts(counter, default)
  local s = string.format('${%d:%s}', counter.id, default)
  counter.id = counter.id + 1
  return s
end

local function append(dst, src)
  for _, line in ipairs(src) do
    table.insert(dst, line)
  end
end

--- One numbered "#### Agent N" runtime-config YAML block, tabstops starting
--- at `counter.id`. Verbatim copy of the block's static scaffolding (tools /
--- protected_files / data_dir / comments) -- only coding_agent, model,
--- thinking, ui_layout, a2a count, and custom layout_spec are tabstops.
local function agent_config_block(agent_no, counter)
  return {
    string.format('#### Agent %d', agent_no),
    '',
    '```yaml',
    '  coding_agent: ' .. ts(counter, 'icarus') .. '          # agent name, e.g. "icarus"',
    '  model: '
      .. ts(counter, 'PICK_MODEL')
      .. '   # provider/id — a bare pattern is ambiguous across providers; <Tab>-into opens a Telescope picker (see plugin/30_mini.lua)',
    '  thinking: ' .. ts(counter, 'medium') .. '                 # off | minimal | low | medium | high | xhigh | max',
    '  ui_layout: ' .. ts(counter, 'grid') .. '                       # off | grid | master/slave | custom',
    '  | a2a ' .. ts(counter, ''),
    '    custom: ' .. ts(counter, '') .. '                 # optional, only if ui_layout=custom',
    '  harness_engineering: []          # pi extensions loaded into the harness (-e)',
    '  # Roster-wide allowlist; any agent may override with its own list.',
    '  # NOTE: --tools filters extension and custom tools too, not just builtins. An agent',
    '  # whose harness_engineering extension registers a tool MUST name that tool in its own',
    '  # tools list — otherwise the extension loads and its tool is silently filtered out.',
    '  tools:',
    '    - read                         # read file contents',
    '    - bash                         # execute bash commands',
    '    - edit                         # find/replace edits',
    '    - write                        # create/overwrite files',
    '    - grep                         # search file contents  (pi default: OFF)',
    '    - find                         # find files by glob     (pi default: OFF)',
    '    - ls                           # list directories       (pi default: OFF)',
    '  # Off-limits to every agent that does not name them in its own `writes`.',
    '  # `tools` alone cannot protect these: bash runs `git checkout`, and write',
    '  # reaches any path. An agent must not be able to edit the machinery that',
    '  # decides whether its own work passed. Enforced in adw_modules/permissions.py.',
    '  #',
    '  # `writes:` per agent says what it may change IN THE REPO. It never restricts',
    '  # the session runtime under data_dir — context_handoff/, envelopes, prompts,',
    '  # raw output. Every agent can always write its own report; `writes: []` means',
    '  # read-only with respect to the repo, not mute.',
    '  protected_files:',
    '    - adws/adw_modules/',
    '    - adws/adw_sssf_config/',
    '    - adws/adw_*.py',
    '  data_dir: adws/adw_data          # runtime home: {data_dir}/sessions/{adw_id}/{agent_name}/',
    '```',
    '',
  }
end

--- Defaults for a roster row's Agent/role-ish fields: row 1 and row 2 mirror
--- the file's canonical "Agent" / "pi-claude (claude-opus-4-8)" convention
--- (used identically across r2-d2, r2-d2-agent, r2-d2-project); rows beyond
--- 2 fall back to the row-1 pattern since there is no established 3rd slot.
local function roster_defaults(agent_no)
  if agent_no == 2 then return 'pi-claude', 'claude-opus-4-8' end
  return 'Agent', 'openai-codex/model'
end

local function clamp_agent_count(n)
  n = tonumber(n)
  if n == nil or n < 1 then return M.DEFAULT_AGENT_COUNT end
  return math.floor(n)
end

--- Generate the r2-d2 (harness) body for `agent_count` agents.
---@param agent_count integer|nil Defaults to `M.DEFAULT_AGENT_COUNT`.
---@return string[]
function M.harness_body(agent_count)
  agent_count = clamp_agent_count(agent_count)
  local c = { id = 1 }
  local lines = { 'R2-D2:', '', '## Harness Name: ' .. ts(c, 'name') }
  append(lines, HARNESS_ART)
  append(lines, {
    '',
    '## Summary',
    '',
    ts(c, 'Brief description of the harness.'),
    '',
    '## UI Layout',
    '<!-- zellij layout for the harness  -->',
    '<!-- canonical 3-pane starting point: ~/.claude/layouts/r2d2-ui.kdl -->',
    '',
    ts(c, ''),
    '',
    '## Agents in Use',
    '<!-- number of agents, server color, and position in the harness build -->',
    '<!-- provider/model: openai-codex = default; deepseek-v4-flash-distill = quota-fallback -->',
    '<!-- pi-claude MUST be claude-opus-4-8 (NOT claude-fable-5 -> 404) -->',
    '',
  })
  for i = 1, agent_count do
    local agent_default, model_default = roster_defaults(i)
    table.insert(
      lines,
      string.format('%d. %s - %s - %s - [ prompt ]', i, ts(c, agent_default), ts(c, 'color'), ts(c, model_default))
    )
  end
  append(lines, {
    '',
    '## coms project namespace: ' .. ts(c, 'ra-autonomy-eval'),
    '',
    '### Per-Agent Runtime Config',
    '<!-- one block per agent listed above; `tools` / `protected_files` / `data_dir` are roster-wide defaults -->',
    '',
  })
  for i = 1, agent_count do
    append(lines, agent_config_block(i, c))
  end
  append(lines, {
    '## Data Types',
    '<!-- Types of data assets that are required to complete the task -->',
    '',
    ts(c, ''),
    '',
    '## Implementation Details',
    '<!-- Technical breakdown: file paths, code changes, config, integration points -->',
    '',
    ts(c, ''),
    '',
    '## Considerations',
    '<!-- Edge cases, trade-offs, alternatives, dependencies, open questions -->',
    '',
    ts(c, '-'),
    '',
    '## Teardown',
    '<!-- kill zellij panes; deregister agents from coms; remove session files -->',
    ts(c, '- '),
    '',
    '# Outcome',
    ts(c, '- '),
    '',
    '<!-- # Outputs -->',
    '<!-- List concrete deliverable files -->',
    '$0',
  })
  return lines
end

--- Generate the r2-d2-project body for `agent_count` agents.
---@param agent_count integer|nil Defaults to `M.DEFAULT_AGENT_COUNT`.
---@return string[]
function M.project_body(agent_count)
  agent_count = clamp_agent_count(agent_count)
  local c = { id = 1 }
  local lines = { 'R2-D2 (project):', '', '## Project: ' .. ts(c, 'name') }
  append(lines, HARNESS_ART)
  append(lines, {
    '',
    '## Objective',
    '',
    ts(c, 'The overarching goal of the project.'),
    '',
    '## Scope & Milestones',
    '<!-- major phases / milestones with rough sequencing -->',
    '',
    ts(c, ''),
    '',
    '## Agent Roster',
    '<!-- each agent: role / model / color -->',
    '<!-- provider/model: openai-codex = default; deepseek-v4-flash-distill = quota-fallback -->',
    '<!-- pi-claude MUST be claude-opus-4-8 (NOT claude-fable-5 -> 404) -->',
    '',
  })
  for i = 1, agent_count do
    local agent_default, model_default = roster_defaults(i)
    table.insert(
      lines,
      string.format(
        '%d. %s - %s - %s - %s',
        i,
        ts(c, agent_default),
        ts(c, 'role'),
        ts(c, model_default),
        ts(c, 'color')
      )
    )
  end
  append(lines, {
    '',
    '## coms project namespace: ' .. ts(c, 'ra-autonomy-eval'),
    '',
    '### Per-Agent Runtime Config',
    '<!-- one block per agent listed above; `tools` / `protected_files` / `data_dir` are roster-wide defaults -->',
    '',
  })
  for i = 1, agent_count do
    append(lines, agent_config_block(i, c))
  end
  append(lines, {
    '## Coordination Model',
    '<!-- how agents divide and sync work over coms -->',
    '',
    ts(c, ''),
    '',
    '## Data Types',
    '<!-- data assets required across the project -->',
    '',
    ts(c, ''),
    '',
    '## Implementation Details',
    '<!-- file paths, code changes, config, integration points -->',
    '',
    ts(c, ''),
    '',
    '## Risks & Considerations',
    '<!-- edge cases, trade-offs, dependencies, open questions -->',
    '',
    ts(c, '-'),
    '',
    '## Teardown',
    '<!-- kill zellij panes; deregister agents from coms; remove session files -->',
    ts(c, '- '),
    '',
    '# Outcome',
    ts(c, '- '),
    '',
    '<!-- # Deliverables / Outputs -->',
    '<!-- List concrete deliverable files -->',
    '$0',
  })
  return lines
end

--- Prompt for an agent count (blocking `vim.fn.input`, default
--- `M.DEFAULT_AGENT_COUNT` on bare Enter) and insert the generated body as a
--- fresh mini.snippets session via `MiniSnippets.default_insert()`.
---@param kind '"harness"'|'"project"'
function M.insert(kind)
  local body_fn = kind == 'harness' and M.harness_body or M.project_body
  local prefix = kind == 'harness' and 'r2-d2' or 'r2-d2-project'

  local raw = vim.fn.input(string.format('Number of agents (default %d): ', M.DEFAULT_AGENT_COUNT))
  local n = clamp_agent_count(raw ~= '' and raw or nil)

  require('mini.snippets').default_insert({
    prefix = prefix,
    body = body_fn(n),
    desc = string.format('R2-D2 %s (%d agent%s)', kind, n, n == 1 and '' or 's'),
  })
end

return M
