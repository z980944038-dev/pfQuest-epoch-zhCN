-- EpochCN 的全局任务接口负责显示中文；pfQuest 的数据匹配和组队协议需要服务端原文。
-- 只为已知的 pfQuest 函数设置私有读取环境，不恢复、不覆盖 EpochCN 的全局接口。
pfQuestEpochServerAPI = {}
local api=pfQuestEpochServerAPI
for _,name in ipairs({"GetQuestLogTitle","GetQuestLogLeaderBoard","GetQuestLogQuestText"}) do
  local key=name
  api[key]=function(...)
    local raw=EpochCN and EpochCN.raw and EpochCN.raw[key]
    local fn=type(raw)=="function" and raw or _G[key]
    if type(fn)=="function" then return fn(...) end
  end
end

-- 在纪元模块包装方法之前保存引用；仅改变这些函数的读取环境，不影响其他插件。
local targets={}
local function retain(object,key)
  if object and type(object[key])=="function" then targets[#targets+1]=object[key] end
end
retain(pfDatabase,"GetQuestIDs")
retain(pfDatabase,"SearchQuestID")
retain(pfQuest,"UpdateQuestlog")
retain(pfMap,"ShowTooltip")
retain(_G.pfQuestMapTracker,"ButtonEvent")
local loader=CreateFrame("Frame")
loader:RegisterEvent("ADDON_LOADED")
loader:SetScript("OnEvent",function(self,eventName,addon)
  eventName=eventName or event;addon=addon or arg1
  if eventName~="ADDON_LOADED" or addon~="pfQuest-epoch" then return end
  self:UnregisterAllEvents()
  if not EpochCN or not EpochCN.raw or type(EpochCN.raw.GetQuestLogTitle)~="function" then return end
  if pfQuestCompat and pfQuestCompat.client==30300 then
    pfQuestCompat.GetQuestLogTitle=function(index)
      local title,level,tag,group,header,collapsed,complete=api.GetQuestLogTitle(index)
      return title,level,tag,header,collapsed,complete
    end
  end
  for _,fn in ipairs(targets) do
    local originalEnvironment=getfenv(fn)
    local privateEnvironment=setmetatable({}, {
      __index=function(_,key)
        if api[key] then return api[key] end
        return originalEnvironment[key]
      end,
      __newindex=originalEnvironment,
    })
    setfenv(fn,privateEnvironment)
  end
end)
