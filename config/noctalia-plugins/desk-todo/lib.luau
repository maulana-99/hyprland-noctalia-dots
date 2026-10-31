--!nonstrict
-- Shared model helpers for the desktop widget, the editor panel and the service.
--
-- A todo: { id, text, done, doing (in progress, never with done), priority (1 low,
-- 2 medium, 3 high), due "YYYY-MM-DD"?, createdAt ms, doneAt ms?, doingAt ms? }. The list lives in noctalia.state["todos"]; entries never
-- mutate it in place - they build a new list and set it, and the service persists it.

local M = {}

M.STATE_KEY = "todos"
M.EDIT_KEY = "edit" -- { id = string? } request from the desktop widget to the editor
M.PANEL_ID = "iru/desk-todo:editor"

M.PRIORITY_TAG = { "!", "!!", "!!!" }
M.PRIORITY_COLOR = { "tertiary", "secondary", "primary" }
M.PRIORITY_NAME = { "rendah", "sedang", "tinggi" }

local MONTHS = { "jan", "feb", "mar", "apr", "mei", "jun", "jul", "agu", "sep", "okt", "nov", "des" }
local WEEKDAYS = { "min", "sen", "sel", "rab", "kam", "jum", "sab" }

function M.list()
  return noctalia.state.get(M.STATE_KEY) or {}
end

function M.copy(todo)
  local c = {}
  for k, v in pairs(todo) do
    c[k] = v
  end
  return c
end

-- Applies fn(list) to a shallow copy of the current list and publishes the result.
function M.mutate(fn)
  local next = {}
  for i, todo in ipairs(M.list()) do
    next[i] = M.copy(todo)
  end
  fn(next)
  noctalia.state.set(M.STATE_KEY, next)
end

function M.find(list, id)
  for i, todo in ipairs(list) do
    if todo.id == id then
      return todo, i
    end
  end
  return nil, nil
end

function M.newId()
  return string.format("%x%04x", math.floor(noctalia.nowMs()), math.random(0, 0xffff))
end

-- ── dates ────────────────────────────────────────────────────────────────────

-- Noon avoids DST edges when two dates are subtracted.
local function noon(y, m, d)
  return os.time({ year = y, month = m, day = d, hour = 12 })
end

function M.today()
  return os.date("%Y-%m-%d")
end

function M.addDays(days)
  local t = os.date("*t")
  return os.date("%Y-%m-%d", noon(t.year, t.month, t.day) + days * 86400)
end

-- "YYYY-MM-DD" -> noon timestamp, or nil when the string is not a real calendar date.
function M.parseDate(s)
  if type(s) ~= "string" then
    return nil
  end
  local y, m, d = s:match("^(%d%d%d%d)-(%d%d)-(%d%d)$")
  if not y then
    return nil
  end
  y, m, d = tonumber(y), tonumber(m), tonumber(d)
  if m < 1 or m > 12 or d < 1 or d > 31 then
    return nil
  end
  local t = noon(y, m, d)
  -- os.time normalises 2026-02-31 to March; reject anything that moved.
  if os.date("%Y-%m-%d", t) ~= s then
    return nil
  end
  return t
end

-- Whole days from today to `due` (negative = overdue), or nil without a valid due.
function M.daysUntil(due)
  local t = M.parseDate(due)
  if not t then
    return nil
  end
  local now = os.date("*t")
  return math.floor((t - noon(now.year, now.month, now.day)) / 86400 + 0.5)
end

-- Short due label and its color role, or nil when there is no due date.
function M.dueLabel(todo)
  local days = M.daysUntil(todo.due)
  if days == nil then
    return nil, nil
  end
  if todo.done then
    return M.formatDate(todo.due), "outline"
  end
  if days < 0 then
    return "lewat " .. tostring(-days) .. "h", "error"
  elseif days == 0 then
    return "hari ini", "primary"
  elseif days == 1 then
    return "besok", "on_surface"
  elseif days < 7 then
    local t = os.date("*t", M.parseDate(todo.due))
    return WEEKDAYS[t.wday], "on_surface_variant"
  end
  return M.formatDate(todo.due), "tertiary"
end

function M.formatDate(due)
  local t = M.parseDate(due)
  if not t then
    return ""
  end
  local d = os.date("*t", t)
  local label = tostring(d.day) .. " " .. MONTHS[d.month]
  if d.year ~= os.date("*t").year then
    label = label .. " " .. tostring(d.year)
  end
  return label
end

-- ── ordering ─────────────────────────────────────────────────────────────────

-- Open first: in progress, then priority high to low, then nearest due (none last), then oldest.
-- Done after: most recently completed first.
local function before(a, b)
  if a.done ~= b.done then
    return not a.done
  end
  if a.done then
    return (a.doneAt or 0) > (b.doneAt or 0)
  end
  if (a.doing == true) ~= (b.doing == true) then
    return a.doing == true
  end
  local pa, pb = a.priority or 2, b.priority or 2
  if pa ~= pb then
    return pa > pb
  end
  local da, db = M.parseDate(a.due), M.parseDate(b.due)
  if da ~= db then
    if da == nil then
      return false
    end
    if db == nil then
      return true
    end
    return da < db
  end
  return (a.createdAt or 0) < (b.createdAt or 0)
end

function M.sorted(list, filter)
  local out = {}
  for _, todo in ipairs(list) do
    if
      filter == "all"
      or (filter == "doing" and todo.doing and not todo.done)
      or (filter == "active" and not todo.done)
      or (filter == "done" and todo.done)
    then
      out[#out + 1] = todo
    end
  end
  table.sort(out, before)
  return out
end

function M.counts(list)
  local open, done, doing = 0, 0, 0
  for _, todo in ipairs(list) do
    if todo.done then
      done += 1
    else
      open += 1
      if todo.doing then
        doing += 1
      end
    end
  end
  return open, done, doing
end

return M
