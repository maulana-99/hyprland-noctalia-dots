--!nonstrict
-- Editor panel: add or edit one todo. Opened by the desktop widget (which sets
-- noctalia.state["edit"] = { id = string? } first) or by IPC:
--   noctalia msg panel-toggle iru/desk-todo:editor
-- Enter in the text field saves; Escape closes (host-reserved).

local Lib = require("./lib.luau")

local DUE_PRESETS = {
  { label = "tanpa", days = nil },
  { label = "hari ini", days = 0 },
  { label = "besok", days = 1 },
  { label = "+7 hari", days = 7 },
}

local editId = nil
local text = ""
local priority = 2
local doing = false
local dueText = "" -- what the date field holds; validated on save
local errorText = nil
local session = 0 -- bumped per open so inputs re-seed and the text field takes focus
local dueRev = 0 -- bumped when a preset rewrites the date field
local closeButton = true

local function load()
  local req = noctalia.state.get(Lib.EDIT_KEY)
  editId = req and req.id or nil
  -- Consume the request so a later IPC open starts a fresh "add".
  noctalia.state.set(Lib.EDIT_KEY, nil)

  local todo = editId and Lib.find(Lib.list(), editId) or nil
  if editId and not todo then
    editId = nil -- deleted meanwhile: fall back to adding
  end
  text = todo and todo.text or ""
  priority = todo and todo.priority or 2
  doing = todo ~= nil and todo.doing == true and not todo.done
  dueText = todo and todo.due or ""
  errorText = nil
  session += 1
  dueRev += 1
end

local function save()
  local clean = noctalia.string.trim(text):gsub("%s+", " ")
  if clean == "" then
    errorText = "isi todo masih kosong."
    return false
  end
  if #clean > 200 then
    errorText = "maksimal 200 karakter (sekarang " .. tostring(#clean) .. ")."
    return false
  end
  local due = noctalia.string.trim(dueText)
  if due ~= "" and not Lib.parseDate(due) then
    errorText = "tanggal harus YYYY-MM-DD, mis. " .. Lib.addDays(1) .. "."
    return false
  end
  due = due ~= "" and due or nil

  Lib.mutate(function(list)
    local todo = editId and Lib.find(list, editId) or nil
    if todo then
      todo.text = clean
      todo.priority = priority
      todo.due = due
      if not todo.done and (todo.doing == true) ~= doing then
        todo.doing = doing or nil
        todo.doingAt = doing and noctalia.nowMs() or nil
      end
    else
      list[#list + 1] = {
        id = Lib.newId(),
        text = clean,
        done = false,
        priority = priority,
        due = due,
        doing = doing or nil,
        doingAt = doing and noctalia.nowMs() or nil,
        createdAt = noctalia.nowMs(),
      }
    end
  end)
  return true
end

local render

local function submit()
  if save() then
    panel.close()
  else
    render()
  end
end

local function deleteTodo()
  if not editId then
    return
  end
  Lib.mutate(function(list)
    local _, i = Lib.find(list, editId)
    if i then
      table.remove(list, i)
    end
  end)
  panel.close()
end

-- ── pieces ───────────────────────────────────────────────────────────────────

local function fieldLabel(label)
  return ui.label({ text = label, width = 72, fontSize = 12, color = "tertiary" })
end

local function choice(label, selected, onClick)
  return ui.button({
    text = label,
    variant = selected and "secondary" or "ghost",
    controlSize = "sm",
    selected = selected,
    onClick = onClick,
    fontSize = 12,
  })
end

render = function()
  local title = editId and "edit todo" or "todo baru"

  local headerRow = {
    ui.glyph({ name = editId and "pencil" or "plus", size = 16, color = "primary" }),
    ui.label({ text = title, fontSize = 15, fontWeight = "bold", color = "on_surface", flexGrow = 1 }),
  }
  if closeButton then
    headerRow[#headerRow + 1] = ui.button({ glyph = "x", variant = "ghost", controlSize = "sm", onClick = function()
      panel.close()
    end })
  end

  local prioRow = { fieldLabel("prioritas") }
  for p = 1, 3 do
    prioRow[#prioRow + 1] = choice(Lib.PRIORITY_TAG[p] .. " " .. Lib.PRIORITY_NAME[p], priority == p, function()
      priority = p
      render()
    end)
  end

  local statusRow = {
    fieldLabel("status"),
    choice("belum", not doing, function()
      doing = false
      render()
    end),
    choice("dikerjakan", doing, function()
      doing = true
      render()
    end),
  }

  local presetRow = { fieldLabel("tenggat") }
  for _, preset in ipairs(DUE_PRESETS) do
    local value = preset.days and Lib.addDays(preset.days) or ""
    presetRow[#presetRow + 1] = choice(preset.label, noctalia.string.trim(dueText) == value, function()
      dueText = value
      errorText = nil
      dueRev += 1
      render()
    end)
  end

  local footerRow = {}
  if editId then
    footerRow[#footerRow + 1] = ui.button({ text = "hapus", glyph = "trash", variant = "destructive", controlSize = "sm", onClick = deleteTodo })
  end
  footerRow[#footerRow + 1] = ui.spacer({ flexGrow = 1 })
  footerRow[#footerRow + 1] = ui.button({ text = "batal", variant = "ghost", controlSize = "sm", onClick = function()
    panel.close()
  end })
  footerRow[#footerRow + 1] = ui.button({ text = "simpan", variant = "primary", controlSize = "sm", onClick = submit })

  panel.render(ui.column({ gap = 14, padding = 18 }, {
    ui.row({ align = "center", gap = 8 }, headerRow),
    ui.input({
      key = "text-" .. tostring(session),
      value = text,
      placeholder = "mau ngerjain apa?",
      fontSize = 14,
      focus = true,
      onChange = function(value)
        text = value
        if errorText then
          errorText = nil
          render()
        end
      end,
      onSubmit = function(value)
        text = value
        submit()
      end,
    }),
    ui.row({ align = "center", gap = 6 }, prioRow),
    ui.row({ align = "center", gap = 6 }, statusRow),
    ui.column({ gap = 8 }, {
      ui.row({ align = "center", gap = 6 }, presetRow),
      ui.row({ align = "center", gap = 6 }, {
        ui.box({ width = 72, height = 1 }), -- indent under the presets, past the label column
        ui.input({
          key = "due-" .. tostring(session) .. "-" .. tostring(dueRev),
          value = dueText,
          placeholder = "YYYY-MM-DD",
          controlSize = "sm",
          fontSize = 12,
          width = 140,
          onChange = function(value)
            dueText = value
            render() -- refresh the date preview; the stable key keeps the typed text
          end,
          onSubmit = function(value)
            dueText = value
            submit()
          end,
        }),
        ui.label({
          text = Lib.parseDate(noctalia.string.trim(dueText)) and Lib.formatDate(noctalia.string.trim(dueText)) or "",
          fontSize = 12,
          color = "on_surface_variant",
        }),
      }),
    }),
    ui.label({ text = errorText or " ", fontSize = 12, color = "error", visible = errorText ~= nil }),
    ui.spacer({ flexGrow = 1 }),
    ui.row({ align = "center", gap = 8 }, footerRow),
  }))
end

function onOpen(context)
  closeButton = noctalia.getSetting("shell.show_close_buttons") ~= false
  load()
  render()
end
