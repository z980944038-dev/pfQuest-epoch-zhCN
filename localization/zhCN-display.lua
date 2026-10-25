-- 显示层：仅处理 pfQuest 自己的标签与它主动绘制的 Tooltip。
-- 不修改 quest title/spawn/item 等节点键，不 Hook GetQuestLogTitle/SendAddonMessage。
local zh=pfQuestEpochZhCN
local bound=setmetatable({}, {__mode="k"})
local busy=setmetatable({}, {__mode="k"})
local hoverBound=setmetatable({}, {__mode="k"})
local roots={"pfQuestConfig","pfQuestBrowser","pfQuestJournal","pfQuestMenu","pfQuestMapTracker","pfQuestEpochLootPanel"}

local function textForQuest(text,id)
  local record=zh.Quest(id)
  if record and pfDB.quests then
    -- 中文客户端可能已有 loc 语言表：按任务 ID 对照两个来源，不能只认英文。
    for _,catalogue in ipairs({pfDB.quests.enUS or {},pfDB.quests.loc or {}}) do
      local original=catalogue[tonumber(id)]
      if type(original)=="table" then
        for _,field in ipairs({"T","O","D"}) do
          if original[field] and original[field]~="" and record[field] then
            local formatted=pfDatabase:FormatQuestText(original[field])
            if text==formatted or text==original[field] then return zh.Format(record[field]) end
          end
        end
      end
    end
  end
  return zh.Text(text)
end

function zh.LocalizeTooltip(tooltip,id)
  if not zh.enabled or not tooltip or not tooltip.GetName or not tooltip.NumLines then return end
  local name=tooltip:GetName()
  if not name then return end
  local changed=false
  for i=1,tooltip:NumLines() do
    for _,side in ipairs({"Left","Right"}) do
      local line=_G[name.."Text"..side..i]
      if line and line.GetText and line.SetText then
        local raw=line:GetText()
        local localized=textForQuest(raw,id)
        if type(localized)=="string" and localized~=raw then line:SetText(localized); changed=true end
      end
    end
  end
  if changed and tooltip.Show then tooltip:Show() end
end

local function localizeFont(font)
  if not zh.enabled or busy[font] or not font.GetText or not font.SetText then return end
  local original=font:GetText()
  local translated=zh.Text(original)
  if translated~=original then
    busy[font]=true
    font:SetText(translated)
    busy[font]=nil
  end
end

local function bindFont(font)
  if not font or not font.IsObjectType or not font:IsObjectType("FontString") then return end
  if not bound[font] then
    bound[font]=true
    hooksecurefunc(font,"SetText",function(self) localizeFont(self) end)
    if font.SetFormattedText then hooksecurefunc(font,"SetFormattedText",function(self) localizeFont(self) end) end
  end
  localizeFont(font)
end

local function bindTree(frame,depth)
  if not frame or not frame.GetObjectType then return end
  depth=depth or 0
  if depth>12 then return end
  local objectType=frame:GetObjectType()
  if objectType=="EditBox" then return end -- 用户输入/搜索关键字不得替换。
  if objectType=="FontString" then bindFont(frame); return end
  if (objectType=="Button" or objectType=="CheckButton") and frame.HookScript and not hoverBound[frame] then
    hoverBound[frame]=true
    frame:HookScript("OnEnter",function(self) zh.LocalizeTooltip(GameTooltip,self.questid) end)
  end
  if frame.GetRegions then for _,region in ipairs({frame:GetRegions()}) do bindFont(region) end end
  if frame.GetChildren then for _,child in ipairs({frame:GetChildren()}) do bindTree(child,depth+1) end end
end

function zh.RefreshOwnedUI()
  if not zh.enabled then return end
  for _,name in ipairs(roots) do bindTree(_G[name]) end
  if pfQuest then
    for _,key in ipairs({"buttonShow","buttonHide","buttonClean","buttonOnline","buttonLanguage","mapButton"}) do
      bindTree(pfQuest[key])
    end
  end
end

local function hook(object,name,callback)
  if object and type(object[name])=="function" then hooksecurefunc(object,name,callback) end
end

function zh.InstallDisplayHooks()
  if zh.displayInstalled or not zh.enabled then return end
  zh.displayInstalled=true
  hook(pfDatabase,"ShowExtendedTooltip",function(self,id,tip) zh.LocalizeTooltip(tip or GameTooltip,id) end)
  hook(pfMap,"ShowTooltip",function(self,meta,tip) zh.LocalizeTooltip(tip or GameTooltip,meta and meta.questid) end)
  hook(pfMap,"NodeEnter",function()
    zh.LocalizeTooltip(GameTooltip); zh.LocalizeTooltip(WorldMapTooltip)
  end)
  local tracker=_G.pfQuestMapTracker
  hook(tracker,"ButtonEvent",function(button)
    button=button or this
    if button then
      bindTree(button)
      if button.node and button.node.questid and button.text then
        -- 保留 title 的内部键，只修正文本标签；同名任务优先使用 ID。
        local title=zh.Name("quests",button.node.questid,nil)
        if title and button.title and button.text.GetText then
          local raw=button.text:GetText()
          local a,b
          if type(raw)=="string" then a,b=string.find(raw,button.title,1,true) end
          if a then button.text:SetText(string.sub(raw,1,a-1)..title..string.sub(raw,b+1)) end
        end
      end
    end
  end)
  hook(tracker,"ButtonEnter",function() zh.LocalizeTooltip(GameTooltip,this and this.questid) end)
  hook(pfQuestConfig,"CreateConfigEntries",function(self) bindTree(self) end)
  hook(pfQuestEpochLoot,"ShowPinned",function() bindTree(_G.pfQuestEpochLootPanel) end)
  if pfBrowser and pfBrowser.input and pfBrowser.input.HookScript then
    pfBrowser.input:HookScript("OnTextChanged",function() bindTree(pfBrowser) end)
  end
  for _,name in ipairs(roots) do
    local frame=_G[name]
    if frame and frame.HookScript then frame:HookScript("OnShow",function(self) bindTree(self) end) end
  end
  if pfQuest and pfQuest.mapButton then hook(pfQuest.mapButton,"UpdateMenu",zh.RefreshOwnedUI) end
  zh.RefreshOwnedUI()
end
