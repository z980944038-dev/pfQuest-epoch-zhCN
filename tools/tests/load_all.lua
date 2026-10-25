-- Load the actual base and extension TOC/XML files, without replacing their Lua modules.
-- Explicit UI/API doubles exercise lifecycle wiring, not graphics, combat taint or a server.
assert(_VERSION=='Lua 5.1','native Lua 5.1 required')
local base,root,mode=assert(arg[1]),assert(arg[2]),arg[3] or 'fresh'
local frames,loaded,messages,transmissions={},{},{},{}
local now=0
local active=false
local coexist=mode=='coexist'
local disabled=mode=='disabled'
local upgrade=mode=='upgrade'
local checked=0
local function check(ok,msg) assert(ok,msg);checked=checked+1 end
local function noop() end
local function pack(...) return {n=select('#',...),...} end
local Frame={};Frame.__index=Frame
function Frame:GetObjectType() return self.kind end
function Frame:IsObjectType(kind) return self.kind==kind or (kind=='Frame' and self.kind~='FontString' and self.kind~='Texture') end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:SetParent(p) self.parent=p end
function Frame:GetChildren() return unpack(self.children) end
function Frame:GetNumChildren() return #self.children end
function Frame:GetRegions() return unpack(self.regions) end
function Frame:GetScript(k) return self.scripts[k] end
function Frame:SetScript(k,f) self.scripts[k]=f end
function Frame:HookScript(k,f)
 local old=self.scripts[k];self.scripts[k]=function(self,...)
  if old then old(self,...) end;return f(self,...)
 end
end
function Frame:Run(k,...)
 local oldThis,oldArg=this,arg1;this=self;arg1=select(1,...)
 if self.scripts[k] then self.scripts[k](self,...) end
 this,arg1=oldThis,oldArg
end
function Frame:RegisterEvent(e) self.events[e]=true end
function Frame:UnregisterEvent(e) self.events[e]=nil end
function Frame:UnregisterAllEvents() self.events={} end
function Frame:Show() local old=self.visible;self.visible=true;if not old then self:Run('OnShow') end end
function Frame:Hide() local old=self.visible;self.visible=false;if old then self:Run('OnHide') end end
function Frame:IsShown() return self.visible~=false end
function Frame:IsVisible() return self:IsShown() and (not self.parent or self.parent:IsVisible()) end
function Frame:SetWidth(x) self.width=x end
function Frame:SetHeight(x) self.height=x end
function Frame:GetWidth() return self.width or 320 end
function Frame:GetHeight() return self.height or 240 end
function Frame:GetLeft() return 0 end
function Frame:GetRight() return self:GetWidth() end
function Frame:GetBottom() return 0 end
function Frame:GetTop() return self:GetHeight() end
function Frame:GetCenter() return self:GetWidth()/2,self:GetHeight()/2 end
function Frame:SetScale(s) self.scale=s end
function Frame:GetScale() return self.scale or 1 end
function Frame:GetEffectiveScale() return self:GetScale() end
function Frame:SetFrameLevel(v) self.level=v end
function Frame:GetFrameLevel() return self.level or 1 end
function Frame:SetFrameStrata(v) self.strata=v end
function Frame:GetFrameStrata() return self.strata or 'MEDIUM' end
function Frame:SetAlpha(v) self.alpha=v end
function Frame:GetAlpha() return self.alpha or 1 end
function Frame:SetID(v) self.id=v end
function Frame:GetID() return self.id or 0 end
function Frame:SetText(t)
 self.textValue=t and tostring(t) or ''
 if self.kind=='Button' or self.kind=='CheckButton' then
  if not self.fontstring then self.fontstring=self:CreateFontString() end
  -- A native Button:SetText does not invoke a Lua hook on FontString:SetText.
  self.fontstring.textValue=self.textValue
 end
 if self.kind=='EditBox' then self:Run('OnTextChanged',false) end
end
function Frame:GetText()
 if self.fontstring then return self.fontstring:GetText() end
 return self.textValue
end
function Frame:SetFormattedText(fmt,...) self:SetText(string.format(fmt,...)) end
function Frame:GetStringWidth() return #(self.textValue or '')*6 end
function Frame:SetTextColor(r,g,b,a) self.textColor={r,g,b,a} end
function Frame:GetTextColor() return unpack(self.textColor or {1,1,1,1}) end
function Frame:SetFont(f,s,flags) self.font={f,s,flags};return true end
function Frame:GetFont() return unpack(self.font or {'Fonts\\FRIZQT__.TTF',12,''}) end
function Frame:GetFontString() return self.fontstring end
function Frame:SetFontString(v) self.fontstring=v end
function Frame:GetTexture() return self.texture end
function Frame:GetNormalTexture() return nil end
function Frame:SetTexture(v) self.texture=v end
function Frame:SetThumbTexture(v) self.thumb=self:CreateTexture();self.thumb:SetTexture(v) end
function Frame:GetThumbTexture() return self.thumb end
function Frame:SetChecked(v) self.checked=v==nil or v end
function Frame:GetChecked() return self.checked end
function Frame:Enable() self.enabled=true end
function Frame:Disable() self.enabled=false end
function Frame:IsEnabled() return self.enabled~=false end
function Frame:SetValue(v) local old=self.value;self.value=v;if v~=old then self:Run('OnValueChanged',v) end end
function Frame:GetValue() return self.value or 0 end
function Frame:SetVerticalScroll(v) self.scroll=v end
function Frame:GetVerticalScroll() return self.scroll or 0 end
function Frame:GetVerticalScrollRange() return 0 end
function Frame:GetZoom() return self.zoom or 0 end
function Frame:SetZoom(v) self.zoom=v end
function Frame:GetModel() return '' end
function Frame:GetFacing() return 0 end
function Frame:GetUnit() return nil,nil end
function Frame:IsMouseOver() return false end
function Frame:CreateTexture(name) return CreateFrame('Texture',name,self) end
function Frame:CreateFontString(name) return CreateFrame('FontString',name,self) end
function Frame:ClearLines() self.lines={} end
function Frame:AddLine(t)
 self.lines=self.lines or {};self.lines[#self.lines+1]=t
 local key=(self.name or 'AnonymousTooltip')..'TextLeft'..#self.lines
 local f=_G[key] or self:CreateFontString(key);f:SetText(t)
end
function Frame:AddDoubleLine(l,r)
 self:AddLine(l);local key=(self.name or 'AnonymousTooltip')..'TextRight'..#self.lines
 local f=_G[key] or self:CreateFontString(key);f:SetText(r)
end
function Frame:NumLines() return #(self.lines or {}) end
function Frame:SetHyperlink(link)
 self:ClearLines();self:AddLine('Hearthstone');self:Show()
end
function Frame:SetOwner(owner) self.owner=owner end
function Frame:GetOwner() return self.owner end
function Frame:Insert(text) self.textValue=(self.textValue or '')..text end
for _,name in ipairs({'SetPoint','ClearAllPoints','SetAllPoints','SetMovable','EnableMouse','EnableMouseWheel',
 'SetClampedToScreen','SetNormalTexture','SetPushedTexture','SetHighlightTexture','SetDisabledTexture',
 'SetNormalFontObject','SetHighlightFontObject','SetDisabledFontObject','SetFontObject','SetJustifyH','SetJustifyV',
 'SetTextInsets','SetAutoFocus','ClearFocus','SetFocus','HighlightText','SetBackdrop','SetBackdropColor',
 'SetBackdropBorderColor','SetVertexColor','SetTexCoord','SetBlendMode','SetDesaturated','SetDrawLayer',
 'SetOrientation','SetMinMaxValues','SetValueStep','SetObeyStepOnDrag','SetScrollChild','RegisterForClicks',
 'RegisterForDrag','StartMoving','StopMovingOrSizing','SetToplevel','SetResizable','SetUserPlaced',
 'SetHitRectInsets','SetFading','UpdateScrollChildRect','SetSpacing','SetShadowColor','SetShadowOffset',
 'SetNonSpaceWrap','SetWordWrap','SetMaxLetters','SetMultiLine','SetNumeric','SetButtonState','SetClipsChildren',
 'SetMask','SetClampRectInsets','SetModelScale','SetFacing','SetPosition','SetLight','ClearModel','SetModel',
 'SetGradientAlpha','SetGradient','SetPortraitZoom','SetHyperlinkCompareItem'}) do Frame[name]=noop end
function CreateFrame(kind,name,parent,template)
 if name and name:find('$parent',1,true) then name=name:gsub('%$parent',parent and parent.name or '') end
 local f=setmetatable({kind=kind,name=name,parent=parent,children={},regions={},scripts={},events={},visible=true},Frame)
 if parent then
  local list=(kind=='FontString' or kind=='Texture') and parent.regions or parent.children
  list[#list+1]=f
 end
 if name then _G[name]=f end
 frames[#frames+1]=f
 return f
end
function hooksecurefunc(obj,key,fn)
 if type(obj)=='string' then obj,key,fn=_G,obj,key end
 local old=assert(obj[key],'unknown hook '..tostring(key))
 obj[key]=function(...) local out=pack(old(...));fn(...);return unpack(out,1,out.n) end
end
for _,name in ipairs({'UIParent','WorldFrame','WorldMapFrame','WorldMapButton','WorldMapDetailFrame',
 'WorldMapPositioningGuide','WorldMapPOIFrame','WorldMapBlobFrame','WorldMapQuestFrame','Minimap','MiniMapCompassRing',
 'MinimapCluster','MinimapZoneTextButton','WatchFrame','QuestLogFrame','QuestLogDetailScrollFrame',
 'QuestLogDetailScrollChildFrame','QuestInfoTitleHeader','QuestInfoObjectivesText','QuestInfoDescriptionText',
 'QuestInfoDescriptionHeader','GameTooltip','WorldMapTooltip','ItemRefTooltip','ChatFrame1EditBox','ChatFrameEditBox',
 'TargetFrame','PlayerFrame','QuestFrame','GameFontNormal','GameFontWhite','GameFontDisable'}) do
 CreateFrame(name:find('Tooltip') and 'GameTooltip' or 'Frame',name)
end
for _,name in ipairs({'WorldMapFrame','QuestLogFrame','GameTooltip','WorldMapTooltip','ItemRefTooltip'}) do _G[name]:Hide() end
CreateFrame('Model',nil,Minimap)
DEFAULT_CHAT_FRAME={AddMessage=function(_,s) messages[#messages+1]=s end}
SlashCmdList={};UISpecialFrames={};UIMenus={};StaticPopupDialogs={};UIPanelWindows={};ITEM_QUALITY_COLORS={}
for i=0,7 do ITEM_QUALITY_COLORS[i]={r=1,g=1,b=1,hex='ffffffff'} end
RAID_CLASS_COLORS={MAGE={r=.25,g=.75,b=1}}
YES='Yes';NO='No';OKAY='Okay';CANCEL='Cancel';UNKNOWN='Unknown';QUIT_NOW='Quit';STANDARD_TEXT_FONT='Fonts\\FRIZQT__.TTF'
QUEST_MONSTERS_KILLED='%s slain: %d/%d';QUEST_OBJECTS_FOUND='%s: %d/%d';QUEST_ITEMS_NEEDED='%s: %d/%d';QUEST_FACTION_NEEDED='%s: %s / %s'
QUEST_COMPLETE='Complete';QUESTS_LABEL='Quests';ITEM_BIND_ON_PICKUP='Binds when picked up'
floor,ceil,abs,min,max,sqrt,mod=math.floor,math.ceil,math.abs,math.min,math.max,math.sqrt,math.fmod
sin,cos,atan2=math.sin,math.cos,math.atan2
bit={}
function bit.band(a,b)
 local result,place=0,1
 a,b=a%4294967296,b%4294967296
 while a>0 and b>0 do
  if a%2==1 and b%2==1 then result=result+place end
  a,b,place=math.floor(a/2),math.floor(b/2),place*2
 end
 return result
end
function bit.bor(a,...)
 for i=1,select("#",...) do local b=select(i,...);a=a+b-bit.band(a,b) end
 return a
end
strfind,strsub,strlower,strupper,strlen,gsub,format=string.find,string.sub,string.lower,string.upper,string.len,string.gsub,string.format
tinsert,tremove,sort=table.insert,table.remove,table.sort
getglobal=function(k) return _G[k] end
function GetBuildInfo() return '3.3.5','12340','',30300 end
function GetLocale() return mode=='zhCN' and 'zhCN' or 'enUS' end
function GetTime() return now end
function GetFramerate() return 60 end
function GetCVar(k) return '0' end
SetCVar=noop
function GetCVarBool() return false end
function UnitName(unit) return unit=='party1' and 'Gortak' or 'Tester' end
function UnitClass() return 'Mage','MAGE' end
function UnitRace() return 'Human','Human' end
function UnitFactionGroup() return 'Alliance','Alliance' end
function UnitLevel() return 60 end
function UnitXP() return 1 end
function UnitSex() return 2 end
function UnitGUID() return '0x0000000000000001' end
function UnitIsPlayer() return true end
function UnitExists(unit) return unit=='player' end
function UnitIsDead() return false end
UnitIsGhost=UnitIsDead;UnitIsDeadOrGhost=UnitIsDead
function UnitCanAttack() return false end
function GetNumPartyMembers() return mode=='party' and 1 or 0 end
function GetNumRaidMembers() return 0 end
function GetNumQuestLogEntries() if active then return 1,1 end return 0,0 end
function GetQuestLogTitle(i) if active and i==1 then return 'Riverpaw Gnoll Bounty',10,nil,0,false,false,nil,false,11 end end
function GetQuestLogQuestText() return 'Bring the armbands.','Bring 8 Painted Gnoll Armbands.' end
function GetQuestLogLeaderBoard(i,q) if active and i==1 then return 'Painted Gnoll Armband: 0/8','item',false end end
function GetNumQuestLeaderBoards(i) return active and i==1 and 1 or 0 end
function GetQuestLogSelection() return active and 1 or 0 end
function GetNumQuestWatches() return 0 end
function IsQuestWatched() return false end
function GetQuestLink(i) if active and i==1 then return '|cffffff00|Hquest:11:10|h[Riverpaw Gnoll Bounty]|h|r' end end
function GetMoney() return 0 end
function SecondsToTime(seconds) return tostring(math.floor(seconds or 0))..' sec' end
function GetNumFactions() return 0 end
function GetNumSkillLines() return 0 end
function GetSkillLineInfo() return nil end
function GetFactionInfo() return nil end
function GetNumQuestChoices() return 0 end
function GetContainerNumSlots() return 0 end
function GetItemInfo() return nil end
function GetAddOnInfo(id)
 if id=='pfQuest-wotlk' or id==1 then return 'pfQuest-wotlk','pfQuest',nil,true end
 if id=='pfQuest-epoch' or id==2 then return 'pfQuest-epoch','pfQuest Epoch',nil,true end
 return nil
end
function GetNumAddOns() return 2 end
function GetAddOnMetadata(addon,k) return addon=='pfQuest-epoch' and '3.3.0' or '7.0.1' end
function IsAddOnLoaded(name) return loaded[name] or false end
function GetQuestDifficultyColor() return {r=1,g=1,b=0} end
function GetMapContinents() return 'Kalimdor','Eastern Kingdoms','Outland','Northrend' end
function GetMapZones() return 'Elwynn Forest' end
function GetCurrentMapContinent() return 2 end
function GetCurrentMapZone() return 1 end
function GetMapInfo() return 'Elwynn' end
function GetRealZoneText() return 'Elwynn Forest' end
GetZoneText=GetRealZoneText
function GetSubZoneText() return 'Goldshire' end
function GetMinimapZoneText() return 'Goldshire' end
function GetPlayerMapPosition() return .5,.5 end
function GetCorpseMapPosition() return 0,0 end
function GetPlayerFacing() return 0 end
function GetInstanceInfo() return '', 'none',0,0,0 end
function IsInInstance() return false,'none' end
function MouseIsOver() return false end
function GetCursorPosition() return 100,100 end
function InCombatLockdown() return false end
function IsControlKeyDown() return false end
IsShiftKeyDown=IsControlKeyDown;IsAltKeyDown=IsControlKeyDown
function SendAddonMessage(...) transmissions[#transmissions+1]=pack(...) end
function SendChatMessage(...) error('Unexpected public chat during load') end
function GetQuestGreenRange() return 10 end
function date(fmt,t) return os.date(fmt,t) end
time=os.time
function debugprofilestop() return os.clock()*1000 end
for _,name in ipairs({'WorldMapQuestFrame_OnMouseUp','WorldMapFrame_ClearQuestPOIs','QuestLog_UpdateQuestDetails',
 'QuestLog_Update','SetMapToCurrentZone','SetMapZoom','GameTooltip_SetDefaultAnchor','SelectQuestLogEntry',
 'CollapseQuestHeader','ExpandQuestHeader','ToggleDropDownMenu','UIDropDownMenu_Initialize','UIDropDownMenu_AddButton',
 'StaticPopup_Show','ReloadUI','PlaySound','GetInventoryItemLink','GetContainerItemLink','GetNumGossipAvailableQuests',
 'GetGossipAvailableQuests','GetGossipActiveQuests','GetNumGossipActiveQuests','GetQuestLogCompletionText'}) do _G[name]=noop end
local loadedFiles={}
local function filetext(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local function resolve(path)
 local parts={};for p in path:gmatch('[^/]+') do if p=='..' then table.remove(parts) elseif p~='.' then parts[#parts+1]=p end end
 return (path:sub(1,1)=='/' and '/' or '')..table.concat(parts,'/')
end
local function loadFile(path,addon)
 path=resolve(path:gsub('\\','/'))
 if path:match('%.xml$') then
  local folder=path:match('^(.*)/');for target in filetext(path):gmatch('file="([^"]+)"') do loadFile(folder..'/'..target,addon) end
 else
  local chunk,why=loadfile(path);assert(chunk,why)
  local ok,err=xpcall(function() chunk(addon) end,debug.traceback)
  assert(ok,'LOAD '..path..'\n'..tostring(err))
  loadedFiles[#loadedFiles+1]=path
 end
end
local function fire(name,...)
 local args=pack(...);local total=#frames
 for i=1,total do local f=frames[i]
  if f.events[name] then
   -- 3.3.5 插件同时使用旧全局 arg1..arg9 与现代 varargs，两条通道保持一致。
   local oldThis,oldEvent,oldArgs=this,event,{}
   for n=1,9 do oldArgs[n]=_G['arg'..n];_G['arg'..n]=args[n] end
   this,event=f,name
   local ok,err=xpcall(function() if f.scripts.OnEvent then f.scripts.OnEvent(f,name,unpack(args,1,args.n)) end end,debug.traceback)
   this,event=oldThis,oldEvent
   for n=1,9 do _G['arg'..n]=oldArgs[n] end
   assert(ok,'EVENT '..name..' frame '..(f.name or tostring(i))..'\n'..tostring(err))
  end
 end
end
local function loadAddon(folder,addon)
 for line in filetext(folder..'/'..addon..'.toc'):gmatch('[^\r\n]+') do
  if not line:match('^%s*#') and line:match('%S') then loadFile(folder..'/'..line,addon) end
 end
 -- SavedVariables are restored after top-level Lua, before ADDON_LOADED.
 if addon=='pfQuest-wotlk' and upgrade then pfQuest_config={translate='deDE',showtracker='0'} end
 if addon=='pfQuest-epoch' then
  if disabled then pfQuest_epoch_zhCNEnabled=false end
  if upgrade then pfQuest_epoch_zhCNCharDB={initialized=true,previousTranslate='deDE'} end
 end
 loaded[addon]=true
 fire('ADDON_LOADED',addon)
 print('LOADED',addon,#loadedFiles,'files',#frames,'UI doubles')
end
local originalTitle,originalObjective=GetQuestLogTitle,GetQuestLogLeaderBoard
if coexist then
 EpochCN={raw={GetQuestLogTitle=GetQuestLogTitle,GetQuestLogLeaderBoard=GetQuestLogLeaderBoard,GetQuestLogQuestText=GetQuestLogQuestText}}
 EpochCNDB={questLog=true,worldMap=false}
 GetQuestLogTitle=function(i)
  local title,level,tag,group,header,collapsed,done,daily,id=originalTitle(i)
  if title then title='悬赏河爪豺狼人' end
  return title,level,tag,group,header,collapsed,done,daily,id
 end
 GetQuestLogLeaderBoard=function(i,q)
  local t,kind,done=originalObjective(i,q)
  if t then t='彩色豺狼人臂章：0/8' end
  return t,kind,done
 end
end
local globalTitle,globalObjective=GetQuestLogTitle,GetQuestLogLeaderBoard
loadAddon(base,'pfQuest-wotlk')
if mode=='disabled' then pfQuest_epoch_zhCNEnabled=false end
loadAddon(root,'pfQuest-epoch')
fire('VARIABLES_LOADED');fire('PLAYER_LOGIN');fire('PLAYER_ENTERING_WORLD')
for tick=1,80 do
 now=tick*.25
 local total=#frames
 for i=1,total do local f=frames[i]
  if f.scripts.OnUpdate and f:IsVisible() then
   local ok,err=xpcall(function() f:Run('OnUpdate',.1) end,debug.traceback)
   assert(ok,'UPDATE frame '..(f.name or tostring(i))..'\n'..tostring(err))
  end
 end
end
check(pfQuestEpochZhCN.ready,'locale initialization did not run')
check(pfQuestEpochZhCN.enabled==not disabled,'saved language preference ignored')
check(pfDB.quests.enUS[11].T=='Riverpaw Gnoll Bounty','English identity drift')
check(GetQuestLogTitle==globalTitle and GetQuestLogLeaderBoard==globalObjective,'global quest API overwritten')
if upgrade then check(pfQuest_config.translate=='deDE','upgrade lost chosen language') end
if disabled then
 check(pfQuestInit[1].caption:GetText()=='Simple Markers','disabled welcome UI unexpectedly translated')
else
 check(pfDB.quests.zhCN[11].T=='悬赏河爪豺狼人','missing Chinese quest')
 check(pfQuestInit[1].caption:GetText()=='简易标记','first-run welcome screen not Chinese')
 check(pfQuestInit[2].caption:GetText()~= 'Combined','second first-run option not Chinese')
 -- Native button repaint bypasses FontString:SetText in the game engine.
 local button=pfQuest.buttonShow
 button:SetText('Show')
 check(button:GetFontString():GetText()=='显示','native button repaint reverted to English')
end
-- Exercise the actual browser search, including real dynamically-created rows.
pfBrowser:Show();pfBrowser.input:SetText('Riverpaw')
check(pfBrowser.input:GetText()=='Riverpaw','search input was translated')
local browserMatches=0
for _,button in ipairs(pfBrowser.tabs.quests.buttons or {}) do
 if button.id==11 then
  browserMatches=browserMatches+1
  if not disabled then check(button.text:GetText():find('悬赏河爪豺狼人',1,true),'actual browser row not Chinese') end
 end
end
check(browserMatches>0,'actual English browser search lost quest ID 11')
-- An active quest must retain server identities throughout the actual engine.
active=true;now=25
fire('QUEST_LOG_UPDATE')
pfQuest:UpdateQuestlog()
check(pfQuest.questlog[11]~=nil,'active quest did not resolve to ID 11')
local q=pfQuest.questlog[11]
check(q.qlogid==1,'active quest log index changed')
check(pfQuestCompat.GetQuestLogTitle(1)=='Riverpaw Gnoll Bounty','matching API is not original server text')
if coexist then check(GetQuestLogTitle(1)=='悬赏河爪豺狼人','EpochCN display API was replaced') end
local meta={quest='Riverpaw Gnoll Bounty',questid=11,spawn='Riverpaw Gnoll',spawnid=117,item={'Painted Gnoll Armband'},itemid=782,droprate=50}
GameTooltip:ClearLines();GameTooltip:AddLine('Riverpaw Gnoll')
pfMap:ShowTooltip(meta,GameTooltip)
check(meta.quest=='Riverpaw Gnoll Bounty' and meta.item[1]=='Painted Gnoll Armband','tooltip changed node identity')
local hasChinese,hasProgress=false,false
for i=1,GameTooltip:NumLines() do
 local text=_G['GameTooltipTextLeft'..i]:GetText() or ''
 if text:find('悬赏河爪豺狼人',1,true) then hasChinese=true end
 if text:find('0/8',1,true) then hasProgress=true end
end
if not disabled then check(hasChinese,'deferred actual tooltip hook lost localization') end
check(hasProgress,'actual map tooltip lost objective progress')
for _,message in ipairs(transmissions) do
 for i=1,2 do check(not tostring(message[i]):find('[\128-\255]'),'Chinese leaked into addon protocol') end
end
-- Exercise real delayed config reconstruction, and retain editable values.
pfQuestConfig:Show();pfQuestConfig:UpdateConfigEntries()
check(pfQuest_config.epochConfigScale~=nil,'delayed config extension not applied')
-- Only the upstream version advertisement is simulated; no network or game action.
local oldPrint=print
print=function(...) local t={};for i=1,select('#',...) do t[#t+1]=tostring(select(i,...)) end;messages[#messages+1]=table.concat(t,' ') end
fire('CHAT_MSG_ADDON','pfqe','VERSION:30400','PARTY','OtherPlayer')
print=oldPrint
local ownRelease,originalRelease,warning=false,false,false
for _,message in ipairs(messages) do
 ownRelease=ownRelease or message:find('z980944038-dev/pfQuest-epoch-zhCN/releases',1,true)
 originalRelease=originalRelease or message:find('Bennylavaa/pfQuest-epoch/releases',1,true)
 warning=warning or message:find('请勿直接覆盖',1,true)
end
check(originalRelease,'upstream attribution or release notice lost')
if not disabled then check(ownRelease and warning,'upstream update notice could overwrite localized version') end
print('PASS_FULL_LOAD',mode,'files',#loadedFiles,'checks',checked,'frames',#frames,'messages',#messages,'protocol_packets',#transmissions)
