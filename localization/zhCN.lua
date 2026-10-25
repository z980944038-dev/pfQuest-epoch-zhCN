-- pfQuest-epoch-zhCN: display translations without mutating English lookup keys.
-- English text is the server's quest/object identity in many 3.3.5a clients.
-- Modifying pfDB[db].loc or pfDB[db].enUS breaks matching and map pins.

pfQuestEpochZhCN = pfQuestEpochZhCN or {}
local zh = pfQuestEpochZhCN
zh.enabled = (pfQuest_epoch_zhCNEnabled ~= false)
local kinds = { "quests", "items", "units", "objects", "zones", "professions" }

local function notify(text)
  if DEFAULT_CHAT_FRAME then
    DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-epoch-zhCN:|r " .. text)
  end
end

SLASH_PFQUESTEPOCHZH1 = "/pfqzh"
SlashCmdList.PFQUESTEPOCHZH = function(command)
  command = (command or ""):lower():match("^%s*(.-)%s*$")
  if command == "on" then
    pfQuest_epoch_zhCNEnabled = true
    pfQuest_epoch_zhCNInitialized = nil
    notify("简体中文已启用，请输入 /reload 生效。")
  elseif command == "off" then
    pfQuest_epoch_zhCNEnabled = false
    if pfQuest_config and pfQuest_config.translate == "zhCN" then
      pfQuest_config.translate = nil
    end
    notify("简体中文已关闭，请输入 /reload 生效。")
  else
    notify("状态：" .. (zh.enabled and "已启用" or "已关闭") .. "。命令：/pfqzh on 或 /pfqzh off")
  end
end

if zh.enabled and pfDB and pfDB.locales then
  -- pfQuest core has already loaded, removed unused locales and merged its
  -- expansion databases. We register zhCN only *after* upstream data patching.
  pfDB.locales.zhCN = "简体中文"

  for _, kind in ipairs(kinds) do
    local container = pfDB[kind]
    local extra = container and container["zhCN-epoch"]
    if container and extra then
      local current = container.zhCN or {}
      for id, value in pairs(extra) do current[id] = value end
      if getmetatable(current) == nil then
        -- Translation button and display helper may access a missing ID. The
        -- vanilla EN record is used only as fallback; its values stay intact.
        setmetatable(current, { __index = container.enUS })
      end
      container.zhCN = current
    end
  end

  -- pfQuest-WotLK already contains maintained zhCN UI phrasing. The fork
  -- embeds only that MIT-licensed locale table, without touching the base.
  if pfQuest_Loc and pfQuestEpochZhCN_UI then
    for key, value in pairs(pfQuestEpochZhCN_UI) do
      pfQuest_Loc[key] = value
    end
  end

  -- A one-time default; a user's later language selection is never reset.
  if not pfQuest_epoch_zhCNInitialized then
    if pfQuest_config and not pfQuest_config.translate then
      pfQuest_config.translate = "zhCN"
    end
    pfQuest_epoch_zhCNInitialized = true
  end
end

function zh.Name(kind, id, fallback)
  if not zh.enabled or not pfDB or not pfDB[kind] then return fallback end
  local translated = pfDB[kind]["zhCN-epoch"]
  local text = translated and translated[id]
  if kind == "quests" and type(text) == "table" then text = text.T end
  return (text and text ~= "") and text or fallback
end

function zh.Quest(id)
  if not zh.enabled or not pfDB or not pfDB.quests then return nil end
  return pfDB.quests["zhCN-epoch"] and pfDB.quests["zhCN-epoch"][id]
end

if zh.enabled and pfDatabase then
  -- Only look up Chinese names when vanilla English matching has no hit.
  -- This preserves quest ID resolution on English Project Epoch clients.
  local originalGetIDByName = pfDatabase.GetIDByName
  if type(originalGetIDByName) == "function" then
    function pfDatabase:GetIDByName(name, kind, partial, server)
      local result = originalGetIDByName(self, name, kind, partial, server)
      if next(result or {}) or type(name) ~= "string" or not kind then
        return result
      end
      -- ASCII lookups are always handled by the original implementation.
      if not string.find(name, "[\128-\255]") then return result end
      local entries = pfDB[kind] and pfDB[kind]["zhCN-epoch"]
      if not entries then return result end
      result = result or {}
      for id, localized in pairs(entries) do
        local label = type(localized) == "table" and localized.T or localized
        local permit = not server or (pfQuest_server and pfQuest_server[kind] and pfQuest_server[kind][id])
        if label and permit then
          local matched = false
          if partial == true then
            matched = string.find(string.lower(label), string.lower(name), 1, true) ~= nil
          elseif partial == "LOWER" then
            matched = string.lower(label) == string.lower(name)
          else
            matched = label == name
          end
          if matched then result[id] = label end
        end
      end
      return result
    end
  end

  local displayNamesCache = nil
  local function getDisplayNames()
    if displayNamesCache then return displayNamesCache end
    local displayNames = {}
    for _, kind in ipairs({"items", "units", "objects"}) do
        local db = pfDB[kind]
        if db and db.enUS and db["zhCN-epoch"] then
          for entryID, translated in pairs(db["zhCN-epoch"]) do
            local original = db.enUS[entryID]
            if type(original) == "string" and original ~= translated then
              if displayNames[original] and displayNames[original] ~= translated then
                displayNames[original] = false -- avoid ambiguous English homonyms
              elseif displayNames[original] == nil then
                displayNames[original] = translated
              end
            end
          end
        end
      end
    displayNamesCache = displayNames
    return displayNamesCache
  end

  -- Render Chinese in pfQuest's extended tooltip after its original logic
  -- completes; the English source records and search keys never change.
  local originalTooltip = pfDatabase.ShowExtendedTooltip
  if type(originalTooltip) == "function" then
    function pfDatabase:ShowExtendedTooltip(id, tooltip, ...)
      local result = originalTooltip(self, id, tooltip, ...)
      local record = zh.Quest(id)
      if not record then return result end
      local source = pfDB.quests.enUS and pfDB.quests.enUS[id]
      local target = tooltip or GameTooltip
      if not source or not target or not target.GetName or not target.NumLines then
        return result
      end
      local name = target:GetName()
      if not name then return result end
      local replacements = {}
      for _, field in ipairs({"T", "O", "D"}) do
        if record[field] and source[field] and record[field] ~= source[field] then
          local originalText = self:FormatQuestText(source[field])
          local chineseText = self:FormatQuestText(record[field])
          replacements[originalText] = chineseText
        end
      end
      -- Quest Start/End NPC/item/object names are rendered as right-hand
      -- tooltip rows; translate only exact known English names, never IDs.
      local displayNames = getDisplayNames()
      for line = 1, target:NumLines() do
        local label = _G[name .. "TextLeft" .. line]
        if label and label.GetText and label.SetText then
          local current = label:GetText()
          if current and replacements[current] then
            label:SetText(replacements[current])
          end
        end
        local right = _G[name .. "TextRight" .. line]
        if right and right.GetText and right.SetText then
          local raw = right:GetText()
          if raw then
            local localized = string.gsub(raw, "([^,]+)", function(piece)
              local left, original, rightSpace = string.match(piece, "^(%s*)(.-)(%s*)$")
              local replacement = displayNames[original]
              if not replacement then return piece end
              return left .. replacement .. rightSpace
            end)
            if localized ~= raw then right:SetText(localized) end
          end
        end
      end
      if target.Show then target:Show() end
      return result
    end
  end
end
