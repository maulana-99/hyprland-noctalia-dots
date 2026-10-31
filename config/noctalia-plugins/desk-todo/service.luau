--!nonstrict
-- Headless store: loads todos.json into noctalia.state at start and writes it back
-- whenever any entry publishes a new list. The file is the only durable copy;
-- noctalia.state is in-memory and shared by the desktop widget and the editor.

local Lib = require("./lib.luau")

local dataDir = noctalia.pluginDataDir()
local path = dataDir and (dataDir .. "/todos.json") or nil
local loaded = false

-- Keeps only well-formed rows so a hand-edited file cannot break rendering.
local function sanitize(items)
  local out = {}
  if type(items) ~= "table" then
    return out
  end
  for _, t in ipairs(items) do
    if type(t) == "table" and type(t.text) == "string" and t.text ~= "" then
      local p = tonumber(t.priority) or 2
      out[#out + 1] = {
        id = type(t.id) == "string" and t.id or Lib.newId(),
        text = t.text,
        done = t.done == true,
        doing = t.doing == true and t.done ~= true,
        priority = math.clamp(math.floor(p), 1, 3),
        due = Lib.parseDate(t.due) and t.due or nil,
        createdAt = tonumber(t.createdAt) or noctalia.nowMs(),
        doneAt = tonumber(t.doneAt),
        doingAt = tonumber(t.doingAt),
      }
    end
  end
  return out
end

local function load()
  if not path or not noctalia.fileExists(path) then
    return {}
  end
  local contents, err = noctalia.readFile(path)
  if not contents then
    noctalia.notifyError("Desk Todo", "Gagal membaca todos.json: " .. tostring(err))
    return {}
  end
  local data, decodeErr = noctalia.json.decode(contents)
  if data == nil then
    -- Keep the broken file for manual recovery instead of overwriting it.
    local backup = path .. ".broken-" .. os.date("%Y%m%d-%H%M%S")
    noctalia.renameFile(path, backup)
    noctalia.notifyError("Desk Todo", "todos.json rusak (" .. tostring(decodeErr) .. "), disalin ke " .. backup)
    return {}
  end
  return sanitize(data.items)
end

local function save(list)
  if not path then
    return
  end
  local body = noctalia.json.encode({ version = 1, items = list }, true)
  if not body then
    noctalia.notifyError("Desk Todo", "Gagal menyusun todos.json")
    return
  end
  -- Write then rename, so a crash mid-write never leaves a half file.
  local tmp = path .. ".tmp"
  local ok, err = noctalia.writeFile(tmp, body)
  if ok then
    ok, err = noctalia.renameFile(tmp, path)
  end
  if not ok then
    noctalia.notifyError("Desk Todo", "Gagal menyimpan todo: " .. tostring(err))
  end
end

if not path then
  noctalia.notifyError("Desk Todo", "Folder data plugin tidak tersedia; todo tidak akan tersimpan.")
end

noctalia.state.watch(Lib.STATE_KEY, function(list)
  if loaded then
    save(list or {})
  end
end)

noctalia.state.set(Lib.STATE_KEY, load())
loaded = true
