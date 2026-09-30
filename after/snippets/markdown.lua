-- Dynamic markdown snippets (require Lua file support in mini.snippets'
-- `gen_loader.from_lang()`; see :h MiniSnippets-file-specification, "dynamic
-- snippet" note). Unlike after/snippets/markdown.json, entries here may be
-- functions: mini.snippets calls them fresh on every expand, so their body
-- reflects live state instead of a frozen string.

return {
  -- Prints the same provider/model list as icarus's Meh-M model picker
  -- (GET /provider on a running `icarus serve`; there is no working CLI
  -- equivalent -- see /tmp/claude-1000/-home-n0ko-test-spec/
  -- 50dbbba7-9c58-4bf1-ace5-ff862ab47886/scratchpad/icarus-meh-m-findings.md).
  -- Served from lua/icarus_models.lua's background-refreshed cache, NEVER a
  -- synchronous fetch: mini.snippets calls this function on every prepare
  -- (every completion round while typing, not just on expand), and a blocking
  -- curl here froze the editor for 1.6-2s per keystroke burst. The first call
  -- after startup returns the fallback body and triggers the fetch; the list
  -- is live from then on (refreshed when older than 30s).
  models = function(_)
    local icarus_models = require('icarus_models')
    local data = icarus_models.cached(30)
    if data == nil then
      return {
        prefix = 'models',
        description = 'icarus models (fetching, or icarus serve unreachable)',
        body = string.format('(icarus models not available yet from %s -- expand again)', icarus_models.addr),
      }
    end

    local lines = { '## icarus models (live from ' .. icarus_models.addr .. ')' }
    for _, provider in ipairs(data.all or {}) do
      local model_ids = {}
      for model_id, _ in pairs(provider.models or {}) do
        table.insert(model_ids, model_id)
      end
      table.sort(model_ids)
      table.insert(lines, string.format('- **%s**: %s', provider.id, table.concat(model_ids, ', ')))
    end

    -- Escape mini.snippets' tabstop syntax (`\` and `$`) so live model/provider
    -- names can never be misparsed as snippet placeholders.
    for i, line in ipairs(lines) do
      lines[i] = line:gsub('\\', '\\\\'):gsub('%$', '\\$')
    end

    return {
      prefix = 'models',
      description = 'icarus models (live from icarus serve GET /provider)',
      body = lines,
    }
  end,

  -- Bare `r2-d2<Tab>` / `r2-d2-project<Tab>` path: zero-prompt, default agent
  -- count (r2d2_snippets.DEFAULT_AGENT_COUNT). To choose a different agent
  -- count, use the :R2D2Harness / :R2D2Project commands (plugin/30_mini.lua)
  -- instead -- see lua/r2d2_snippets.lua for why the count can't live as an
  -- editable tabstop in this same static-default body (mini.snippets has no
  -- reactive re-render, and prompting synchronously inside a function loader
  -- would fire on every <Tab> press, not just this snippet's).
  ['r2-d2'] = function(_)
    local r2d2 = require('r2d2_snippets')
    return {
      prefix = 'r2-d2',
      description = 'R2-D2 harness build brief with UI layout, agents in use, and data types',
      body = r2d2.harness_body(r2d2.DEFAULT_AGENT_COUNT),
    }
  end,

  ['r2-d2-project'] = function(_)
    local r2d2 = require('r2d2_snippets')
    return {
      prefix = 'r2-d2-project',
      description = 'R2-D2 multi-agent project collaboration brief with roster and coordination model',
      body = r2d2.project_body(r2d2.DEFAULT_AGENT_COUNT),
    }
  end,
}
