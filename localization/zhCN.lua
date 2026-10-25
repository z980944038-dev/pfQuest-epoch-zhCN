-- 仅在本插件的 ADDON_LOADED 之后读取存档；英文数据库和服务端 API 不做替换。
pfQuestEpochZhCN = { enabled = false, ready = false, version = "zhCN-beta.2" }
local zh = pfQuestEpochZhCN
local kinds = { "quests", "items", "units", "objects", "zones", "professions" }
local direct, byPrefix, ownedQuestText

local function chinese(text)
  return type(text) == "string" and string.find(text, "[\128-\255]") ~= nil
end

local function addPhrase(index, original, translated)
  if type(original) ~= "string" or type(translated) ~= "string" or
      original == "" or translated == "" or original == translated then return end
  if index[original] == nil then
    index[original] = translated
  elseif index[original] ~= translated then
    index[original] = false -- 同名异译不凭遍历顺序选择；有 ID 的显示另行精确处理。
  end
end

local function buildDisplayIndex()
  if direct then return end
  direct, byPrefix, ownedQuestText = {}, {}, {}
  for _, kind in ipairs(kinds) do
    local db = pfDB and pfDB[kind]
    if db then
      for id, value in pairs(db["zhCN-epoch"] or {}) do
        local original = db.enUS and db.enUS[id]
        if kind == "quests" then
          if type(original) == "table" and type(value) == "table" then
            for _, field in ipairs({"T", "O", "D"}) do
              addPhrase(direct, original[field], value[field])
              if chinese(value[field]) then ownedQuestText[value[field]] = true end
            end
          end
        else
          addPhrase(direct, original, value)
        end
      end
    end
  end
  for key, value in pairs(pfQuestEpochZhCN_UI or {}) do direct[key] = value end
  for key, value in pairs(pfQuestEpochZhCN_ExtraUI or {}) do direct[key] = value end
  for text, translated in pairs(direct) do
    -- 完整段落走精确匹配，短语索引只处理名称与短标签。
    if translated and #text >= 3 and #text <= 160 and not string.find(text, "[\n\r|]") then
      local first = string.sub(text, 1, 3)
      local bucket = byPrefix[first] or {}
      bucket[#bucket + 1] = { text, translated }
      byPrefix[first] = bucket
    end
  end
  for _, bucket in pairs(byPrefix) do
    table.sort(bucket, function(a,b)
      if #a[1] == #b[1] then return a[1] < b[1] end
      return #a[1] > #b[1]
    end)
  end
end

local function plainText(text)
  if direct[text] then return direct[text] end
  local out, pos, mark = {}, 1, 1
  while pos <= #text do
    local before = pos > 1 and string.sub(text, pos-1, pos-1) or ""
    local bucket = byPrefix[string.sub(text,pos,pos+2)]
    local matched
    if bucket and not string.find(before, "[%w_]") then
      for _, phrase in ipairs(bucket) do
        local last = pos + #phrase[1] - 1
        local after = string.sub(text,last+1,last+1)
        if string.sub(text,pos,last) == phrase[1] and not string.find(after,"[%w_]") then
          out[#out+1] = string.sub(text,mark,pos-1)
          out[#out+1] = phrase[2]
          pos, mark, matched = last+1, last+1, true
          break
        end
      end
    end
    if not matched then pos = pos + 1 end
  end
  out[#out+1] = string.sub(text,mark)
  return table.concat(out)
end

-- 只翻译可见文本。超链接 ID、纹理路径、颜色控制符原样通过，不能拿它们做替换。
function zh.Text(text)
  if not zh.enabled or type(text) ~= "string" or text == "" then return text end
  buildDisplayIndex()
  if direct[text] then return direct[text] end
  -- 队友姓名必须原样显示，即使恰好与 NPC 同名；只翻译它后面的目标文字。
  local partyPrefix, objective=string.match(text,"^(|cffaaaaaa%- |r|c%x%x%x%x%x%x%x%x[^|]+|r: )(.*)$")
  if partyPrefix then return partyPrefix..zh.Text(objective) end
  local out, pos = {}, 1
  while pos <= #text do
    local pipe = string.find(text,"|",pos,true)
    if not pipe then out[#out+1] = plainText(string.sub(text,pos)); break end
    out[#out+1] = plainText(string.sub(text,pos,pipe-1))
    local code = string.sub(text,pipe,pipe+1)
    if code == "|H" then
      local open = string.find(text,"|h",pipe+2,true)
      local close = open and string.find(text,"|h",open+2,true)
      if not close then out[#out+1]=string.sub(text,pipe); break end
      local header=string.sub(text,pipe,open+1)
      local label=string.sub(text,open+2,close-1)
      local linkKind=string.match(header,"^|H([^:]+):")
      out[#out+1]=header
      out[#out+1]=(linkKind=="item" or linkKind=="quest") and plainText(label) or label
      out[#out+1]="|h"; pos=close+2
    elseif code == "|T" then
      local close=string.find(text,"|t",pipe+2,true)
      if not close then out[#out+1]=string.sub(text,pipe); break end
      out[#out+1]=string.sub(text,pipe,close+1); pos=close+2
    elseif code == "|c" and string.match(string.sub(text,pipe+2,pipe+9),"^%x%x%x%x%x%x%x%x$") then
      out[#out+1]=string.sub(text,pipe,pipe+9); pos=pipe+10
    else
      out[#out+1]=code; pos=pipe+2
    end
  end
  return table.concat(out)
end

function zh.Name(kind, id, fallback)
  local db = zh.enabled and pfDB and pfDB[kind]
  local value = db and db["zhCN-epoch"] and db["zhCN-epoch"][tonumber(id)]
  if kind == "quests" and type(value) == "table" then value = value.T end
  return type(value) == "string" and value ~= "" and value or fallback
end

function zh.Quest(id)
  local db = zh.enabled and pfDB and pfDB.quests
  return db and db["zhCN-epoch"] and db["zhCN-epoch"][tonumber(id)] or nil
end

local classes = {WARRIOR="战士",PALADIN="圣骑士",HUNTER="猎人",ROGUE="潜行者",
  PRIEST="牧师",DEATHKNIGHT="死亡骑士",SHAMAN="萨满祭司",MAGE="法师",WARLOCK="术士",DRUID="德鲁伊"}
local races = {Human="人类",Dwarf="矮人",NightElf="暗夜精灵",Gnome="侏儒",Draenei="德莱尼",
  Orc="兽人",Scourge="亡灵",Undead="亡灵",Tauren="牛头人",Troll="巨魔",BloodElf="血精灵",Goblin="地精",HighElf="高等精灵"}

function zh.Format(text)
  if type(text) ~= "string" then return text end
  local class, classID = UnitClass("player")
  local race, raceID = UnitRace("player")
  local values = {N=UnitName("player") or "",C=classes[classID] or class or "",R=races[raceID] or race or "",B="\n"}
  text=string.gsub(text,"%$([NnCcRrBb])",function(key) return values[string.upper(key)] end)
  return string.gsub(text,"%$[Gg]([^:]*):([^;]*);",function(male,female)
    return UnitSex("player")==3 and female or male
  end)
end

local function notify(text)
  if DEFAULT_CHAT_FRAME then DEFAULT_CHAT_FRAME:AddMessage("|cff33ffccpfQuest-epoch-zhCN:|r "..text) end
end

SLASH_PFQUESTEPOCHZH1 = "/pfqzh"
SlashCmdList.PFQUESTEPOCHZH = function(command)
  command=string.lower(tostring(command or "")):match("^%s*(.-)%s*$")
  if command=="on" or command=="off" then
    local enable = command=="on"
    pfQuest_epoch_zhCNEnabled=enable
    local saved=pfQuest_epoch_zhCNCharDB
    if pfQuest_config and type(saved)=="table" then
      if enable then
        if pfQuest_config.translate~="zhCN" then saved.previousTranslate=pfQuest_config.translate or false end
        pfQuest_config.translate="zhCN"
      elseif pfQuest_config.translate=="zhCN" then
        pfQuest_config.translate=saved.previousTranslate or nil
      end
    end
    notify("已保存为"..(enable and "启用" or "关闭").."，输入 /reload 后生效。")
  else
    local pending=pfQuest_epoch_zhCNEnabled~=false
    notify("当前："..(zh.enabled and "已启用" or "已关闭")..
      (pending~=zh.enabled and "；有待重载的设置" or "").."。/pfqzh on 开启，/pfqzh off 关闭。")
  end
end

local function initialize()
  if zh.ready then return end
  zh.ready=true
  if pfQuest_epoch_zhCNEnabled==nil then pfQuest_epoch_zhCNEnabled=true end
  zh.enabled=pfQuest_epoch_zhCNEnabled~=false
  if type(pfQuest_epoch_zhCNCharDB)~="table" then pfQuest_epoch_zhCNCharDB={} end
  local saved=pfQuest_epoch_zhCNCharDB
  if not zh.enabled then return end
  if not pfDB or not pfDatabase or not pfDB.locales then
    zh.enabled=false; notify("基础插件尚未就绪，已停止中文扩展，未改写原始任务数据。")
    return
  end
  pfDB.locales.zhCN="简体中文"
  for _,kind in ipairs(kinds) do
    local db=pfDB[kind]
    if db and db["zhCN-epoch"] then
      -- 复制，而非原地修改：中文客户端的 loc 可能正指向旧的 zhCN 表。
      local localized={}
      for id,value in pairs(db.zhCN or {}) do localized[id]=value end
      for id,value in pairs(db["zhCN-epoch"]) do localized[id]=value end
      setmetatable(localized,{__index=db.enUS})
      db.zhCN=localized
    end
  end
  if not saved.initialized then
    saved.initialized=true
    if not EpochCN and pfQuest_config and pfQuest_config.translate==nil then
      saved.previousTranslate=false
      pfQuest_config.translate="zhCN"
    end
  end
  buildDisplayIndex()
  local originalFind=pfDatabase.GetIDByName
  if type(originalFind)=="function" then
    function pfDatabase:GetIDByName(name,kind,partial,server)
      local result=originalFind(self,name,kind,partial,server)
      if type(result)=="table" and next(result) then return result end
      local db=pfDB[kind]
      if type(name)~="string" or not db then return result end
      result=result or {}
      local catalogues={}
      if db.loc~=db.enUS then catalogues[#catalogues+1]=db.enUS or {} end
      if chinese(name) then catalogues[#catalogues+1]=db["zhCN-epoch"] or {} end
      for _,entries in ipairs(catalogues) do
        for id,value in pairs(entries) do
          local label=kind=="quests" and type(value)=="table" and value.T or value
          local allowed=not server or (pfQuest_server and pfQuest_server[kind] and pfQuest_server[kind][id])
          if type(label)=="string" and allowed then
            local match=label==name
            if partial==true then match=string.find(string.lower(label),string.lower(name),1,true)~=nil
            elseif partial=="LOWER" then match=string.lower(label)==string.lower(name) end
            if match then result[id]=label end
          end
        end
      end
      return result
    end
  end
  local originalFormat=pfDatabase.FormatQuestText
  if type(originalFormat)=="function" then
    function pfDatabase:FormatQuestText(text)
      -- 只处理属于本地中文数据的模板；任务匹配所用的英文格式化完全走原函数。
      if ownedQuestText[text] then return zh.Format(text) end
      return originalFormat(self,text)
    end
  end
  if zh.InstallDisplayHooks then zh.InstallDisplayHooks() end
end

local loader=CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:RegisterEvent("PLAYER_LOGIN")
loader:SetScript("OnEvent",function(self,eventName,addon)
  eventName=eventName or event; addon=addon or arg1
  if eventName=="ADDON_LOADED" and addon=="pfQuest-epoch" then
    initialize(); self:UnregisterEvent("ADDON_LOADED")
  elseif eventName=="PLAYER_LOGIN" and zh.enabled and zh.RefreshOwnedUI then
    zh.RefreshOwnedUI(); self:UnregisterEvent("PLAYER_LOGIN")
  end
end)
