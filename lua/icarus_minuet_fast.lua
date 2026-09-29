-- Minuet fast-path patches: no per-request fork, no full-buffer scan.
--
-- WHY (measured 2026-09-29 on the monty/qwen3.8-flash-next setup):
--   1. minuet's openai_base backend spawns `curl` per request via vim.system.
--      The fork+exec is synchronous on the UI loop: ~1.5 ms warm, 15-65 ms
--      when curl's pages are cold (first request after an idle period). That
--      is the pause felt when a suggestion fires. The transfer itself was
--      already async; removing the fork removes the stall. -> icarus_http
--      (plain vim.loop TCP) replaces the curl job.
--   2. utils.get_context reads the ENTIRE buffer (two nvim_buf_get_lines +
--      table.concat) before truncating to `context_window` chars: 0.7 ms at
--      150 KB, 8 ms at 2 MB, 20 ms at 5 MB. Only ~8k chars are ever used.
--      -> windowed read around the cursor, byte-identical output.
--
-- Both patches are monkey-patches on the plugin's own module tables (the
-- plugin dir is a lazy-nvim checkout that may be updated; do not fork it).
-- Every patch keeps the original reachable as `*_orig` and degrades to it on
-- any unexpected shape, so a plugin update cannot silently break completion.

local M = {}

-- ---------------------------------------------------------------------------
-- 2. Windowed context
-- ---------------------------------------------------------------------------
-- utils.get_context contract (minuet/utils.lua): lines_before/lines_after are
-- plain strings, joined to the cursor line with '\n', truncated to
-- config.context_window chars split by context_ratio, with opts flags. The
-- truncation keeps the LAST context_window*ratio chars of `before` and the
-- FIRST window*(1-ratio) of `after` -- so reading only the lines around the
-- cursor that can reach those bounds produces byte-identical output.

local CHUNK = 64 -- lines per read step while expanding the window

-- The band is sized in CHARACTERS, not bytes: minuet truncates with
-- vim.fn.strchars/strcharpart, so `want` must be compared against a character
-- count. Counting with `#` (bytes) stops the expansion early on multibyte
-- text -- at `window` bytes ~ window/1.4 chars for CJK -- and the patched
-- side then sees a total under `context_window` and skips truncation
-- altogether, returning a SHORTER context with is_incomplete_* left false.
-- Caught by the differential test (6/576 cases, all multibyte shapes).
local strchars = vim.fn.strchars

local function windowed_get_context(cmp_context)
  local config = require('minuet').config
  local api = vim.api
  local cursor = cmp_context.cursor
  local window = config.context_window

  local line_count = api.nvim_buf_line_count(0)
  -- Read a band around the cursor, expanding until each side holds `want`
  -- chars or the buffer edge is reached. `want` = window is a safe bound:
  -- truncation never keeps more than `window` chars from either side.
  local want = window

  -- Chunks are collected outward from the cursor; flattened in order at the
  -- end (before: farthest chunk first, lines top-down within each chunk).
  local before_chunks, after_chunks = {}, {}
  local lo, hi = cursor.line, cursor.line + 1 -- 0-based half-open band
  local n_before, n_after = 0, 0
  while true do
    if n_before < want and lo > 0 then
      local new_lo = math.max(0, lo - CHUNK)
      local chunk = api.nvim_buf_get_lines(0, new_lo, lo, false)
      before_chunks[#before_chunks + 1] = chunk
      lo = new_lo
      n_before = n_before + strchars(table.concat(chunk, '\n')) + 1
    elseif n_after < want and hi < line_count then
      local new_hi = math.min(line_count, hi + CHUNK)
      local chunk = api.nvim_buf_get_lines(0, hi, new_hi, false)
      after_chunks[#after_chunks + 1] = chunk
      hi = new_hi
      n_after = n_after + strchars(table.concat(chunk, '\n')) + 1
    else
      break
    end
  end

  local function flatten(chunks, reverse_chunks)
    local out = {}
    if reverse_chunks then
      for i = #chunks, 1, -1 do
        local c = chunks[i]
        for j = 1, #c do out[#out + 1] = c[j] end
      end
    else
      for i = 1, #chunks do
        local c = chunks[i]
        for j = 1, #c do out[#out + 1] = c[j] end
      end
    end
    return table.concat(out, '\n')
  end

  local lines_before = flatten(before_chunks, true)
  local lines_after = flatten(after_chunks, false)
  lines_before = lines_before .. '\n' .. cmp_context.cursor_before_line
  lines_after = cmp_context.cursor_after_line .. '\n' .. lines_after

  local opts = { is_incomplete_before = false, is_incomplete_after = false }
  local strcharpart = vim.fn.strcharpart
  local n_chars_before = strchars(lines_before)
  local n_chars_after = strchars(lines_after)

  if n_chars_before + n_chars_after > window then
    if n_chars_before < window * config.context_ratio then
      lines_after = strcharpart(lines_after, 0, window - n_chars_before)
      opts.is_incomplete_after = true
    elseif n_chars_after < window * (1 - config.context_ratio) then
      lines_before = strcharpart(lines_before, n_chars_before + n_chars_after - window)
      opts.is_incomplete_before = true
    else
      lines_after = strcharpart(lines_after, 0, math.floor(window * (1 - config.context_ratio)))
      lines_before = strcharpart(lines_before, n_chars_before - math.floor(window * config.context_ratio))
      opts.is_incomplete_before = true
      opts.is_incomplete_after = true
    end
  end

  return { lines_before = lines_before, lines_after = lines_after, opts = opts }
end

-- ---------------------------------------------------------------------------
-- 1. Fork-free request transport
-- ---------------------------------------------------------------------------
-- Replaces openai_compatible.complete. The original builds the same request
-- (transform -> tmp file -> curl args -> vim.system); we build the same body
-- and hand it to icarus_http. Post-processing reuses minuet's own decoders so
-- response semantics cannot drift from the plugin's.

local function make_fast_complete(orig)
  local http = require('icarus_http')
  return function(context, callback)
    local ok, err = pcall(function()
      local utils = require('minuet.utils')
      local common = require('minuet.backends.common')
      local base = require('minuet.backends.openai_base')
      local config = require('minuet').config
      local options = vim.deepcopy(config.provider_options.openai_compatible)

      -- Cancel our previous in-flight request (mirrors terminate_all_jobs).
      if M._active and not M._active.done then M._active:cancel() end

      local ctx = utils.make_chat_llm_shot(context, options.chat_input)
      ctx = common.create_chat_messages_from_list(ctx)
      local few_shots = vim.deepcopy(utils.get_or_eval_value(options.few_shots))
      local system = utils.make_system_prompt(options.system, config.n_completions)
      table.insert(few_shots, 1, { role = 'system', content = system })
      vim.list_extend(few_shots, ctx)

      local data = { model = options.model, messages = few_shots, stream = options.stream }
      data = vim.tbl_deep_extend('force', data, options.optional or {})
      local headers = {
        ['Content-Type'] = 'application/json',
        ['Authorization'] = 'Bearer ' .. utils.get_api_key(options.api_key),
      }
      local td = common.apply_transforms(options.transform, options.end_point, headers, data)
      local body_file = utils.make_tmp_file(td.body)
      if not body_file then callback() return end

      local req = http.post_json(td.end_point, td.headers, body_file,
        { timeout_ms = (config.request_timeout or 30) * 1000 })
      M._active = req

      function req.on_done() vim.uv.fs_unlink(body_file) end

      req.cb = function(rerr, status, body)
        if rerr then
          utils.notify('minuet fast transport: ' .. rerr, 'debug')
          callback()
          return
        end
        if not status or status >= 400 then
          utils.notify('minuet request failed with HTTP ' .. tostring(status), 'warn')
          callback()
          return
        end
        local fake = { code = 0, stdout = body or '', stderr = '' }
        local items_raw = options.stream
            and utils.stream_decode(fake, '/dev/null', options.name, base.openai_get_text_fn_stream)
            or utils.no_stream_decode(fake, '/dev/null', options.name, base.openai_get_text_fn_no_stream)
        if not items_raw then callback() return end
        local items = common.parse_completion_items(items_raw, options.name)
        items = common.filter_context_sequences_in_items(items, context)
        items = utils.trim_completion_items(items)
        callback(items)
      end
    end)
    if not ok then
      vim.schedule(function()
        vim.notify('minuet fast transport error, falling back to curl: ' .. tostring(err), vim.log.levels.WARN)
      end)
      orig(context, callback)
    end
  end
end

-- ---------------------------------------------------------------------------

function M.apply()
  -- (2) windowed context
  local utils = require('minuet.utils')
  if not utils.get_context_icarus_patched then
    utils.get_context_orig = utils.get_context
    utils.get_context = windowed_get_context
    utils.get_context_icarus_patched = true
  end

  -- (1) fork-free transport. virtualtext.trigger() does
  -- `require('minuet.backends.' .. provider)` per request, so patching the
  -- module table is enough; keep the original for fallback.
  local backend = require('minuet.backends.openai_compatible')
  if not backend.complete_icarus_patched then
    local orig = backend.complete
    backend.complete_orig = orig
    backend.complete = make_fast_complete(orig)
    backend.complete_icarus_patched = true
  end
end

return M
