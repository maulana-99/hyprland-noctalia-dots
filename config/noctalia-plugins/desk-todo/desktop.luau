--!nonstrict
-- The list on the desktop. Desktop widgets are background layer-shell surfaces that
-- cannot take keyboard focus, so everything here is pointer-only: tick, delete (with a
-- short undo), filter, page and clear done. Adding and editing open the editor panel.

local Lib = require("./lib.luau")

local WIDTH = tonumber(noctalia.getConfig("width")) or 380
local PAGE_SIZE = tonumber(noctalia.getConfig("page_size")) or 8
local BG_OPACITY = tonumber(noctalia.getConfig("background_opacity")) or 0.72

local PAD = 14
local ROW_H = 26
local UNDO_MS = 6000
local IDLE_TICK_MS = 60000 -- enough to roll due labels over at midnight
local UNDO_TICK_MS = 1000 -- only while the undo offer is showing
-- The host keeps a desktop widget centred on its saved position, so a list that grows or
-- shrinks would move both edges. Render a fixed-height transparent surface sized for a
-- full page and pin the visible card to its top: the top edge stays, the bottom moves.
-- Chrome = padding + header + filter tabs + separators + footer + the gaps between them.
local SURFACE_H = PAD * 2 + 22 + 24 + 1 + 1 + 24 + 10 * 5 + PAGE_SIZE * ROW_H + (PAGE_SIZE - 1) * 2 + 8

local FILTERS = {
  { id = "all", label = "semua" },
  { id = "doing", label = "dikerjakan" },
  { id = "active", label = "aktif" },
  { id = "done", label = "selesai" },
}

local filter = "all"
local page = 1
local hovered = ""
local undo = nil -- { todo = table, expiresAt = ms }
local renderedDay = Lib.today()

-- Collapsed = only the header line shows. Kept in ui.json so it survives reloads and logins.
local dataDir = noctalia.pluginDataDir()
local prefsPath = dataDir and (dataDir .. "/ui.json") or nil
local collapsed = false
if prefsPath and noctalia.fileExists(prefsPath) then
  local prefs = noctalia.json.decode(noctalia.readFile(prefsPath) or "")
  collapsed = type(prefs) == "table" and prefs.collapsed == true
end

local render -- forward declaration; handlers below re-render

-- ── actions ──────────────────────────────────────────────────────────────────

local function openEditor(id)
  noctalia.state.set(Lib.EDIT_KEY, { id = id, at = noctalia.nowMs() })
  noctalia.togglePanel(Lib.PANEL_ID)
end

local function toggleDone(id)
  Lib.mutate(function(list)
    local todo = Lib.find(list, id)
    if todo then
      todo.done = not todo.done
      todo.doneAt = todo.done and noctalia.nowMs() or nil
      if todo.done then
        todo.doing = nil
        todo.doingAt = nil
      end
    end
  end)
end

local function toggleDoing(id)
  Lib.mutate(function(list)
    local todo = Lib.find(list, id)
    if todo and not todo.done then
      todo.doing = not todo.doing or nil
      todo.doingAt = todo.doing and noctalia.nowMs() or nil
    end
  end)
end

local function remove(id)
  Lib.mutate(function(list)
    local todo, i = Lib.find(list, id)
    if todo then
      table.remove(list, i)
      undo = { todo = todo, expiresAt = noctalia.nowMs() + UNDO_MS }
      noctalia.setUpdateInterval(UNDO_TICK_MS)
    end
  end)
end

local function restore()
  if not undo then
    return
  end
  local todo = undo.todo
  undo = nil
  noctalia.setUpdateInterval(IDLE_TICK_MS)
  Lib.mutate(function(list)
    if not Lib.find(list, todo.id) then
      list[#list + 1] = todo
    end
  end)
end

local function clearDone()
  Lib.mutate(function(list)
    for i = #list, 1, -1 do
      if list[i].done then
        table.remove(list, i)
      end
    end
  end)
end

local function setFilter(id)
  filter = id
  page = 1
  render()
end

local function toggleCollapsed()
  collapsed = not collapsed
  hovered = ""
  if prefsPath then
    noctalia.writeFile(prefsPath, noctalia.json.encode({ collapsed = collapsed }) or "{}")
  end
  render()
end

local function setPage(p)
  page = p
  render()
end

local function onRowHover(state, key)
  if state == "true" then
    hovered = key
  elseif hovered == key then
    hovered = ""
  end
  render()
end

-- ── pieces ───────────────────────────────────────────────────────────────────

-- A bare glyph that acts as a button: TUI look, no button chrome.
local function iconButton(name, color, onClick, size)
  return ui.row({
    width = 22,
    height = 22,
    align = "center",
    justify = "center",
    onClick = onClick,
  }, {
    ui.glyph({ name = name, size = size or 15, color = color }),
  })
end

-- A text tab/link: selected = bright with an accent rule underneath.
local function textButton(label, selected, onClick, color)
  return ui.column({ gap = 2, onClick = onClick, paddingV = 2 }, {
    ui.label({
      text = label,
      fontSize = 12,
      fontWeight = selected and "semibold" or "normal",
      color = color or (selected and "on_surface" or "tertiary"),
    }),
    ui.box({ height = 1, fill = selected and "primary" or "#00000000" }),
  })
end

local function header(open, doing, total)
  return ui.row({ align = "center", gap = 8 }, {
    ui.glyph({ name = "checklist", size = 16, color = "primary" }),
    ui.label({ text = "todo", fontSize = 15, fontWeight = "bold", color = "on_surface" }),
    ui.spacer({ flexGrow = 1 }),
    ui.label({
      text = total == 0 and "kosong"
        or ((doing > 0 and (tostring(doing) .. " dikerjakan · ") or "") .. tostring(open) .. " aktif · " .. tostring(total)),
      fontSize = 11,
      color = "tertiary",
    }),
    iconButton("plus", "primary", function()
      openEditor(nil)
    end, 17),
    iconButton(collapsed and "chevron-down" or "chevron-up", "on_surface_variant", toggleCollapsed, 16),
  })
end

local function filterBar()
  local tabs = {}
  for _, f in ipairs(FILTERS) do
    tabs[#tabs + 1] = textButton(f.label, filter == f.id, function()
      setFilter(f.id)
    end)
  end
  return ui.row({ gap = 12, align = "end" }, tabs)
end

local function todoRow(todo)
  local isHover = hovered == todo.id
  local dueText, dueColor = Lib.dueLabel(todo)
  local p = todo.priority or 2
  local doing = todo.doing and not todo.done
  local textWidth = WIDTH - PAD * 2 - 8 - 22 - 26 - 66 - (dueText and 60 or 0) - 6 * 4

  local box, boxColor = "square", "on_surface_variant"
  if todo.done then
    box, boxColor = "square-check", "outline"
  elseif doing then
    box, boxColor = "square-dot", "primary"
  end

  local children = {
    iconButton(box, boxColor, function()
      toggleDone(todo.id)
    end),
    ui.row({ width = 26 }, {
      ui.label({
        text = todo.done and "·" or Lib.PRIORITY_TAG[p],
        fontSize = 12,
        fontWeight = "bold",
        color = todo.done and "outline" or Lib.PRIORITY_COLOR[p],
      }),
    }),
    -- Clicking the text opens it in the editor.
    ui.row({ flexGrow = 1, align = "center", onClick = function()
      openEditor(todo.id)
    end }, {
      ui.label({
        text = todo.text,
        fontSize = 13,
        maxLines = 1,
        maxWidth = textWidth,
        fontWeight = doing and "semibold" or "normal",
        color = todo.done and "outline" or "on_surface",
      }),
    }),
  }
  if dueText then
    children[#children + 1] = ui.label({
      text = dueText,
      width = 60,
      textAlign = "end",
      fontSize = 11,
      color = dueColor,
    })
  end
  -- Actions stay visible (hover may not reach a background surface) but recede until hovered.
  children[#children + 1] = ui.row({ gap = 0, opacity = isHover and 1 or 0.45 }, {
    -- Start/stop working on it; done rows keep the slot so the columns stay aligned.
    todo.done and ui.box({ width = 22, height = 22 })
      or iconButton(doing and "player-pause" or "player-play", doing and "primary" or "on_surface_variant", function()
        toggleDoing(todo.id)
      end, 14),
    iconButton("pencil", "on_surface_variant", function()
      openEditor(todo.id)
    end, 14),
    iconButton("trash", isHover and "error" or "on_surface_variant", function()
      remove(todo.id)
    end, 14),
  })

  return ui.row({
    key = todo.id,
    gap = 6,
    align = "center",
    height = ROW_H,
    paddingH = 4,
    fill = isHover and "surface_variant/0.55" or (doing and "primary/0.08" or "#00000000"),
    onHover = onRowHover,
  }, children)
end

local function emptyState(total)
  local text
  if total == 0 then
    text = "belum ada todo. klik + untuk menambah."
  elseif filter == "doing" then
    text = "belum ada yang dikerjakan. klik ikon play di todo."
  elseif filter == "active" then
    text = "semua beres. tidak ada todo aktif."
  else
    text = "belum ada yang selesai."
  end
  return ui.row({ height = ROW_H * 2, align = "center", paddingH = 4 }, {
    ui.label({ text = text, fontSize = 12, color = "tertiary" }),
  })
end

local function footer(pages, doneCount)
  local left
  if undo then
    left = ui.row({ gap = 10, align = "center" }, {
      ui.label({ text = "dihapus", fontSize = 12, color = "tertiary" }),
      textButton("urungkan", true, restore),
    })
  elseif pages > 1 then
    left = ui.row({ gap = 6, align = "center" }, {
      iconButton("chevron-left", page > 1 and "on_surface" or "outline", function()
        if page > 1 then
          setPage(page - 1)
        end
      end),
      ui.label({ text = tostring(page) .. "/" .. tostring(pages), fontSize = 12, color = "on_surface_variant" }),
      iconButton("chevron-right", page < pages and "on_surface" or "outline", function()
        if page < pages then
          setPage(page + 1)
        end
      end),
    })
  else
    left = ui.spacer({ width = 1 })
  end

  local right = doneCount > 0
      and textButton("bersihkan selesai (" .. tostring(doneCount) .. ")", false, clearDone, "on_surface_variant")
    or ui.spacer({ width = 1 })

  return ui.row({ align = "center", justify = "space_between", height = 24 }, { left, right })
end

-- ── render ───────────────────────────────────────────────────────────────────

render = function()
  local list = Lib.list()
  local open, doneCount, doingCount = Lib.counts(list)
  local visible = Lib.sorted(list, filter)
  local pages = math.max(1, math.ceil(#visible / PAGE_SIZE))
  page = math.clamp(page, 1, pages)

  local rows = {}
  local first = (page - 1) * PAGE_SIZE + 1
  for i = first, math.min(#visible, first + PAGE_SIZE - 1) do
    rows[#rows + 1] = todoRow(visible[i])
  end
  if #rows == 0 then
    rows[1] = emptyState(#list)
  end

  local body = { header(open, doingCount, #list) }
  if not collapsed then
    body[#body + 1] = filterBar()
    body[#body + 1] = ui.separator({ color = "outline", thickness = 1 })
    body[#body + 1] = ui.column({ gap = 2 }, rows)
    body[#body + 1] = ui.separator({ color = "outline", thickness = 1 })
    body[#body + 1] = footer(pages, doneCount)
  end

  desktopWidget.render(ui.column({ width = WIDTH, height = SURFACE_H, justify = "start" }, {
    ui.column({
      padding = PAD,
      gap = 10,
      radius = 0,
      fill = "surface/" .. tostring(BG_OPACITY),
    }, body),
  }))
end

-- Ticks once a minute to roll due labels over at midnight, and once a second only
-- while an undo offer is showing, to expire it on time.
function update()
  local dirty = false
  if undo and noctalia.nowMs() >= undo.expiresAt then
    undo = nil
    noctalia.setUpdateInterval(IDLE_TICK_MS)
    dirty = true
  end
  local day = Lib.today()
  if day ~= renderedDay then
    renderedDay = day
    dirty = true
  end
  if dirty then
    render()
  end
end

-- noctalia msg plugin iru/desk-todo:desktop all toggle   (e.g. from a Hyprland keybind)
function onIpc(event)
  if event == "toggle" then
    toggleCollapsed()
  end
end

noctalia.state.watch(Lib.STATE_KEY, function()
  render()
end)

noctalia.setUpdateInterval(IDLE_TICK_MS)
render()
