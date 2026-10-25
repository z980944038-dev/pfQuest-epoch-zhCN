-- Native Lua 5.1 integration: actual pfQuest database.lua + data, with bounded UI/API fakes.
-- This does not emulate rendering or the WoW client; see QA documentation.
assert(_VERSION == "Lua 5.1", "Tests require the real Lua 5.1 VM, not a 5.3 emulator")
local base, root, scenario=assert(arg[1]),assert(arg[2]),arg[3] or "fresh"
local passed,frames,hookCount=0,{},0
local function check(value,message)
  assert(value,scenario..": "..message);passed=passed+1
end
local function packed(...) return {n=select('#',...),...} end
function hooksecurefunc(object,key,after)
  assert(type(object)=='table' and type(object[key])=='function','invalid hook target '..tostring(key))
  local original=object[key]
  object[key]=function(...)
    local result=packed(original(...));after(...);return unpack(result,1,result.n)
  end
  hookCount=hookCount+1
end
local Font={}
Font.__index=Font
function Font:GetObjectType() return 'FontString' end
function Font:IsObjectType(kind) return kind=='FontString' end
function Font:GetText() return self.text end
function Font:SetText(value) self.text=value end
function Font:SetFormattedText(fmt,...) self:SetText(string.format(fmt,...)) end
function Font:SetFont(...) self.font={...} end
function Font:GetFont() return 'Fonts\\FRIZQT__.TTF',12,'' end
function Font:SetJustifyH() end
function Font:SetPoint() end
function Font:SetTextColor(...) self.color={...} end
function Font:Show() self.visible=true end
function Font:Hide() self.visible=false end
local Frame={}
Frame.__index=Frame
function Frame:GetObjectType() return self.kind end
function Frame:IsObjectType(kind) return self.kind==kind end
function Frame:GetName() return self.name end
function Frame:GetParent() return self.parent end
function Frame:GetRegions() return unpack(self.regions) end
function Frame:GetChildren() return unpack(self.children) end
function Frame:SetWidth(w) self.width=w end
function Frame:SetHeight(h) self.height=h end
function Frame:SetPoint(...) self.point={...} end
function Frame:Hide() self.visible=false end
function Frame:Show() self.visible=true;self:Run('OnShow') end
function Frame:GetScript(name) return self.scripts[name] end
function Frame:SetScript(name,fn) self.scripts[name]=fn end
function Frame:HookScript(name,fn)
  local old=self.scripts[name]
  self.scripts[name]=function(self,...)
    if old then old(self,...) end
    fn(self,...)
  end
end
function Frame:RegisterEvent(event) self.events[event]=true end
function Frame:UnregisterEvent(event) self.events[event]=nil end
function Frame:UnregisterAllEvents() self.events={} end
function Frame:Run(script,...)
  local old=this;this=self
  if self.scripts[script] then self.scripts[script](self,...) end
  this=old
end
function Frame:CreateFontString(name)
  local font=setmetatable({name=name},Font)
  self.regions[#self.regions+1]=font
  if name then _G[name]=font end
  return font
end
function CreateFrame(kind,name,parent)
  local frame=setmetatable({kind=kind,name=name,parent=parent,scripts={},events={},regions={},children={}},Frame)
  if parent and parent.children then parent.children[#parent.children+1]=frame end
  if name then _G[name]=frame end
  frames[#frames+1]=frame
  return frame
end
local function fire(eventName,addon)
  for _,f in ipairs(frames) do
    if f.events[eventName] then
      event,arg1,this=eventName,addon,f
      f:Run('OnEvent',eventName,addon)
    end
  end
  event,arg1,this=nil,nil,nil
end
local function tooltip(name)
  local tip=CreateFrame('GameTooltip',name)
  tip.lines={}
  function tip:SetOwner(owner) self.owner=owner end
  function tip:ClearLines() self.lines={} end
  function tip:AddLine(text)
    local n=#self.lines+1; self.lines[n]=text
    local font=self:CreateFontString(name..'TextLeft'..n);font:SetText(text)
  end
  function tip:SetText(text) self:ClearLines();self:AddLine(text) end
  function tip:AddDoubleLine(left,right)
    self:AddLine(left)
    local font=self:CreateFontString(name..'TextRight'..#self.lines);font:SetText(right)
  end
  function tip:NumLines() return #self.lines end
  function tip:Show() self.visible=true end
  return tip
end
UIParent=CreateFrame('Frame','UIParent')
GameTooltip=tooltip('GameTooltip');WorldMapTooltip=tooltip('WorldMapTooltip')
WorldMapButton=CreateFrame('Button','WorldMapButton');WorldMapPOIFrame={}
ItemRefTooltip=tooltip('ItemRefTooltip')
SlashCmdList={};messages={}
DEFAULT_CHAT_FRAME={AddMessage=function(self,s) messages[#messages+1]=s end}
UNKNOWN='Unknown';STANDARD_TEXT_FONT='Fonts\\FRIZQT__.TTF'
floor,ceil,min,max=math.floor,math.ceil,math.min,math.max
strfind,strlower,gsub=string.find,string.lower,string.gsub
function GetLocale() return scenario=='native-zhCN' and 'zhCN' or 'enUS' end
function GetTime() return 20 end
function UnitName() return '测试者' end
function UnitClass() return 'Mage','MAGE' end
function UnitRace() return 'Human','Human' end
function UnitSex() return scenario=='female' and 3 or 2 end
function UnitLevel() return 60 end
function GetNumQuestLogEntries() return 0,0 end
function GetNumQuestLeaderBoards() return 0 end
function GetQuestLogTitle() return 'Riverpaw Gnoll Bounty',10,nil,0,false,false,nil,false,11 end
function GetQuestLogQuestText() return 'English description','English objective' end
function GetQuestLogLeaderBoard() return 'Kobold Miner slain: 0/8','monster',false end
function GetItemInfo() return nil end
function GetMapInfo() return 'Elwynn' end
function SendAddonMessage() error('Localization must not transmit addon protocol') end
function SendChatMessage() error('Localization must not send public chat') end
QUEST_MONSTERS_KILLED='%s slain: %d/%d'
pfUI={api={SanitizePattern=function(pattern) return pattern==QUEST_MONSTERS_KILLED and '(.*) slain: (%d+)/(%d+)' or '(.*): (%d+)/(%d+)' end}}
pfQuestCompat={client=30300,GetQuestLogTitle=GetQuestLogTitle,
  GetDifficultyColor=function() return {r=1,g=1,b=0} end}
pfQuest={questlog={},route={}};pfQuest_history={};pfQuest_server={}
pfQuest.route.arrow=CreateFrame('Frame','pfQuestTestArrow',UIParent)
pfQuest.route.arrow.title=pfQuest.route.arrow:CreateFontString();pfQuest.route.arrow.title:SetText('Corpse')
pfQuest.route.arrow.description=pfQuest.route.arrow:CreateFontString();pfQuest.route.arrow.description:SetText('Welcome to the Spirit World')
pfQuest_config={showids='0',tooltiphelp='0'};pfQuest_questcache={}
pfQuest_Loc=setmetatable({}, {__index=function(t,k) rawset(t,k,k);return k end})
local protected={GetLocale=GetLocale,GetQuestLogTitle=GetQuestLogTitle,GetQuestLogLeaderBoard=GetQuestLogLeaderBoard,
  GetItemInfo=GetItemInfo,GetMapInfo=GetMapInfo,SendAddonMessage=SendAddonMessage,SendChatMessage=SendChatMessage}
-- Load actual 7.0.1 database data and its executable code, not hand-written replacements.
dofile(base..'/db/init.lua')
local categories={'items','units','objects','refloot','quests-itemreq','quests','zones','minimap','areatrigger','meta'}
for _,suffix in ipairs({'','-tbc'}) do
 for _,kind in ipairs(categories) do dofile(base..'/db/'..kind..suffix..'.lua') end
 for _,kind in ipairs({'items','units','objects','quests','zones','professions'}) do
  dofile(base..'/db/enUS/'..kind..suffix..'.lua')
 end
end
if scenario=='native-zhCN' then pfDB.quests.zhCN={[11]={T='已有客户端语言'}} end
dofile(base..'/database.lua')
for _,kind in ipairs({'items','units','objects','quests','zones','professions'}) do
 dofile(root..'/db/enUS/'..kind..'-epoch.lua')
end
for _,kind in ipairs({'items','units','objects','quests','zones','refloot','quests-itemreq','areatrigger','minimap','meta'}) do
 dofile(root..'/db/'..kind..'-epoch.lua')
end
dofile(root..'/overwrites.lua')
local function filetext(path) local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local patch=filetext(root..'/patchtable.lua'):match('^(.-)\n%-%- Update bitmasks')
assert(patch,'Cannot locate upstream database merge boundary')
assert(loadstring(patch,'upstream-patchtable-data-merge'))()
local frozen,oldLoc={},{}
for _,kind in ipairs({'quests','items','units','objects','zones'}) do
 oldLoc[kind]=pfDB[kind].loc;frozen[kind]={}
 for id,v in pairs(pfDB[kind].enUS) do
  frozen[kind][id]=type(v)=='table' and {T=v.T,O=v.O,D=v.D} or v
 end
end
local function loadMethod(path,signature,prefix)
 local source=filetext(path);local a=assert(source:find(signature,1,true))
 local b=assert(source:find('\nend',a,true))+3
 assert(loadstring((prefix or '')..source:sub(a,b),'actual-'..signature))()
end
pfMap={tooltip=tooltip('pfMapTooltip')}
loadMethod(base..'/map.lua','function pfMap.tooltip:GetColor(')
loadMethod(base..'/map.lua','function pfMap:HexDifficultyColor(')
loadMethod(base..'/map.lua','function pfMap:ShowTooltip(','local compat=pfQuestCompat\n')
loadMethod(base..'/map.lua','function pfMap:NodeEnter(','local compat=pfQuestCompat\n')
-- Real UI ownership boundaries represented by small test objects.
pfQuestConfig=CreateFrame('Frame','pfQuestConfig',UIParent)
pfQuestConfig.caption=pfQuestConfig:CreateFontString();pfQuestConfig.caption:SetText('Settings')
function pfQuestConfig:CreateConfigEntries()
 self.lateCaption=self:CreateFontString();self.lateCaption:SetText('Config Window Scale')
end
pfBrowser=CreateFrame('Frame','pfQuestBrowser',UIParent)
pfBrowser.input=CreateFrame('EditBox','pfQuestBrowserSearch',pfBrowser)
pfBrowser.input.text=pfBrowser.input:CreateFontString();pfBrowser.input.text:SetText('Search')
pfBrowser.input:SetScript('OnTextChanged',function() end)
pfQuestMapTracker=CreateFrame('Frame','pfQuestMapTracker',UIParent)
pfQuestMapTracker.buttons={}
function pfQuestMapTracker.ButtonEvent(button) button.text:SetText('[10] '..button.title..' (50%)') end
function pfQuestMapTracker.ButtonEnter() GameTooltip:SetText('Riverpaw Gnoll Bounty') end
pfQuestEpochLoot={ShowPinned=function() end}
if scenario=='coexist' then
  EpochCN={raw={GetQuestLogTitle=GetQuestLogTitle,GetQuestLogLeaderBoard=GetQuestLogLeaderBoard,GetQuestLogQuestText=GetQuestLogQuestText}}
  EpochCNDB={worldMap=true,questLog=true}
  GetQuestLogTitle=function() return '悬赏河爪豺狼人',10,nil,0,false,false,nil,false,11 end
  GetQuestLogLeaderBoard=function() return '狗头人矿工：0/8','monster',false end
  GetQuestLogQuestText=function() return '已汉化描述','已汉化目标' end
  local cachedTitle=GetQuestLogTitle
  pfQuestCompat.GetQuestLogTitle=function(index)
    local title,level,tag,group,header,collapsed,complete=cachedTitle(index)
    return title,level,tag,header,collapsed,complete
  end
  protected.GetQuestLogTitle=GetQuestLogTitle
  protected.GetQuestLogLeaderBoard=GetQuestLogLeaderBoard
  protected.GetQuestLogQuestText=GetQuestLogQuestText
end
dofile(root..'/localization/compat-epochcn.lua')
if scenario=='custom-locale' then pfQuest_config.translate='deDE' end
if scenario=='reset-language' then pfQuest_config.translate=nil end
for _,kind in ipairs({'items','units','objects','quests','zones','professions'}) do
 dofile(root..'/db/zhCN/'..kind..'-epoch.lua')
end
-- Additional ambiguous names exercise deterministic handling; never written to shipped data.
pfDB.quests.enUS[900001]={T='Ambiguous Test',O='',D=''}
pfDB.quests.enUS[900002]={T='Ambiguous Test',O='',D=''}
pfDB.quests['zhCN-epoch'][900001]={T='测试甲',O='',D=''}
pfDB.quests['zhCN-epoch'][900002]={T='测试乙',O='',D=''}
dofile(root..'/localization/zhCN-ui.lua')
dofile(root..'/localization/zhCN-extra-ui.lua')
dofile(root..'/localization/zhCN.lua')
dofile(root..'/localization/zhCN-display.lua')
check(not pfQuestEpochZhCN.ready,'initialized before SavedVariables were restored')
check(hookCount==0,'hooks installed before saved setting was restored')
if scenario=='disabled' then pfQuest_epoch_zhCNEnabled=false elseif scenario~='fresh' then pfQuest_epoch_zhCNEnabled=true end
if scenario=='reset-language' then pfQuest_epoch_zhCNCharDB={initialized=true} end
if scenario=='corrupt-state' then pfQuest_epoch_zhCNCharDB='corrupt legacy value' end
fire('ADDON_LOADED','UnrelatedAddon')
check(not pfQuestEpochZhCN.ready,'unrelated ADDON_LOADED initialized extension')
fire('ADDON_LOADED','pfQuest-epoch')
fire('PLAYER_LOGIN')
local zh=pfQuestEpochZhCN
check(zh.ready,'own ADDON_LOADED did not initialize extension')
local hooksAfter=hookCount;fire('ADDON_LOADED','pfQuest-epoch');fire('PLAYER_LOGIN')
check(hookCount==hooksAfter,'duplicate load events installed duplicate hooks')
for name,original in pairs(protected) do check(_G[name]==original,'overrode server API '..name) end
for _,kind in ipairs({'quests','items','units','objects','zones'}) do
 check(pfDB[kind].loc==oldLoc[kind],'changed live locale table alias: '..kind)
 for id,old in pairs(frozen[kind]) do
  local value=pfDB[kind].enUS[id]
  if type(old)=='table' then
   assert(value and value.T==old.T and value.O==old.O and value.D==old.D,'English quest changed at '..id)
  else assert(value==old,'English name changed: '..kind..':'..id) end
 end
 passed=passed+1
end
check(pfQuest_Loc['Unit']=='Unit','mutated shared English UI enum Unit')
check(pfBrowser.input.text:GetText()=='Search','modified a user-editable search control')
if scenario=='disabled' then
 check(zh.enabled==false,'disabled setting ignored on reload')
 check(hookCount==0,'installed hooks while disabled')
 check(pfQuestConfig.caption:GetText()=='Settings','localized UI while disabled')
 check(pfQuest_config.translate==nil,'forced language selection while disabled')
 print('PASS',scenario,passed);return
end
check(zh.enabled,'should be enabled')
if scenario=='coexist' then
  check(GetQuestLogTitle()=='悬赏河爪豺狼人','overrode EpochCN UI-facing quest API')
  check(pfQuestCompat.GetQuestLogTitle(1)=='Riverpaw Gnoll Bounty','failed to give pfQuest the raw server title')
  check(pfQuestEpochServerAPI.GetQuestLogLeaderBoard(1,1)=='Kobold Miner slain: 0/8','raw objective adapter failed')
  local oldCount,oldObjectives=GetNumQuestLogEntries,GetNumQuestLeaderBoards
  GetNumQuestLogEntries=function() return 1,1 end
  GetNumQuestLeaderBoards=function() return 1 end
  GameTooltip:SetText('Kobold Miner')
  pfMap:ShowTooltip({quest='Riverpaw Gnoll Bounty',questid=11,spawn='Kobold Miner',item={}},GameTooltip)
  check(GameTooltip:NumLines()==3,'actual pfQuest map tooltip failed to match raw objectives under EpochCN API replacements')
  check(GameTooltipTextLeft3:GetText():find('0/8',1,true),'lost progress counters under EpochCN')
  GetNumQuestLogEntries,GetNumQuestLeaderBoards=oldCount,oldObjectives
end

if scenario=='custom-locale' then check(pfQuest_config.translate=='deDE','overwrote manual locale')
elseif scenario=='reset-language' then check(pfQuest_config.translate==nil,'overwrote a previous reset language choice')
elseif scenario=='coexist' then
 check(pfQuest_config.translate==nil,'automatically took over EpochCN quest detail rendering')
 check(EpochCNDB.worldMap==true,'silently modified EpochCN settings')
else check(pfQuest_config.translate=='zhCN','fresh character did not default to Chinese') end
check(type(pfQuest_epoch_zhCNCharDB)=='table','did not normalize saved character state')
check(pfDatabase:GetIDByName('Riverpaw Gnoll Bounty','quests')[11],'English exact lookup failed')
check(pfDatabase:GetIDByName('Riverpaw','quests',true)[11],'English partial lookup failed')
check(pfDatabase:GetIDByName('悬赏河爪豺狼人','quests')[11],'Chinese exact lookup failed')
check(pfDatabase:GetIDByName('河爪','quests',true)[11],'Chinese partial lookup failed')
check(pfDatabase:GetIDByName('riverpaw gnoll bounty','quests','LOWER')[11],'case-insensitive English lookup failed')
check(pfDatabase:GetIDByName('anything','missing-db')==nil,'unknown category contract changed')
check(next(pfDatabase:GetIDByName('悬赏河爪豺狼人','quests',false,true))==nil,'bypassed server-only filter')
pfQuest_server.quests={[11]=true}
check(pfDatabase:GetIDByName('悬赏河爪豺狼人','quests',false,true)[11],'ignored server-only matching entry')
check(zh.Text('Ambiguous Test')=='Ambiguous Test','arbitrarily picked an ambiguous translated name')
check(zh.Name('quests',900001,nil)=='测试甲','ID-based ambiguous title resolution failed')
check(zh.Text('SomeUnrelatedUnknownName')=='SomeUnrelatedUnknownName','invented a translation')
local link='|cffffffff|Hitem:782:0:0:0|h[Painted Gnoll Armband]|h|r'
local localized=zh.Text(link)
check(localized:find('|Hitem:782:0:0:0|h',1,true),'changed hyperlink payload')
check(localized:find(pfDB.items['zhCN-epoch'][782],1,true),'did not translate visible hyperlink text')
check(zh.Text('|TInterface\\Icons\\Horde:16|t')=='|TInterface\\Icons\\Horde:16|t','translated a texture path')
check(zh.Text('|cff00ff00Kobold Miner: 0/8|r'):find('0/8',1,true),'changed progress counters')
check(zh.Text('Kobold MinersXYZ')=='Kobold MinersXYZ','replaced a substring inside a longer word')
check(zh.Format('$N，$C，$R')=='测试者，法师，人类','player/class/race formatting failed')
check(zh.Format('$G先生:女士;')==(scenario=='female' and '女士' or '先生'),'gender template failed')
check(zh.Format('甲$B乙')=='甲\n乙','newline token failed')
check(pfDatabase:FormatQuestText('$N the $C')=='测试者 the mage','changed English matching formatter')
check(pfQuestConfig.caption:GetText()=='设置','failed to localize UI created before extension loaded')
check(pfQuest.route.arrow.title:GetText()=='尸体','navigation arrow heading not localized')
check(pfQuest.route.arrow.description:GetText()=='欢迎来到灵魂世界','navigation status not localized')
pfQuest.route.arrow.description:SetText('Error 404: HP Not Found')
check(pfQuest.route.arrow.description:GetText()=='错误404：未找到生命值','reused navigation status reverted to English')
check(zh.Text('No items linked to this NPC')=='该角色没有关联的物品记录','loot panel fallback not localized')
check(zh.Text('Drop chance: 25%')=='掉落几率：25%','drop rate text changed value or remains English')
check(zh.Text('Loot |cff33ffcc[Painted Gnoll Armband]|r from |cff33ffccKobold Miner|r')=='拾取|cff33ffcc[彩色豺狼人臂章]|r，来源：|cff33ffcc狗头人矿工|r','display format left English or swapped item/NPC parameters')
check(zh.Text('Use |cff33ffccPainted Gnoll Armband|r on |cff33ffccKobold Miner|r')=='使用|cff33ffcc彩色豺狼人臂章|r，目标：|cff33ffcc狗头人矿工|r','use-on format swapped tool and target')
check(zh.Text('Current: |cff66ccff3.3.0|r -> Available: |cff66ccff3.4.0|r'):find('3.4.0',1,true),'version notice changed numeric version')

check(zh.Name('items',60141,nil)=='烟林牧场运输箱','cross-project keystone item contamination returned')
check(zh.Text('Smokywood Pastures Shipping Crate')=='烟林牧场运输箱','item tooltip still uses contaminated translation')
check(zh.Name('zones',4273,nil)=='奥杜尔','new zone translation not loaded')
check(zh.Text('/bow')=='/bow','translated an executable emote command')
local demon=pfDB.quests['zhCN-epoch'][31033].D
check(zh.Text(demon)==demon,'retranslated an explicitly preserved inscription')

pfQuestConfig:CreateConfigEntries()
check(pfQuestConfig.lateCaption:GetText()=='设置窗口缩放','failed to localize deferred config rebuild')
pfQuestConfig.lateCaption:SetText('Settings')
check(pfQuestConfig.lateCaption:GetText()=='设置','reused UI label reverted to English')
local btn=CreateFrame('Button',nil,pfQuestMapTracker);btn.title='Riverpaw Gnoll Bounty';btn.node={questid=11};btn.text=btn:CreateFontString()
pfQuestMapTracker.ButtonEvent(btn)
check(btn.text:GetText():find('悬赏河爪豺狼人',1,true),'tracker title not localized')
check(btn.title=='Riverpaw Gnoll Bounty','changed tracker internal lookup key')
check(btn.text:GetText():find('(50%)',1,true),'changed tracker progress percentage')
local meta={quest='Riverpaw Gnoll Bounty',questid=11,spawn='Kobold Miner',spawnid=40,item={},texture='test',qlvl=10,qmin=5}
GameTooltip:SetText('Kobold Miner')
pfMap:ShowTooltip(meta,GameTooltip)
check(GameTooltipTextLeft1:GetText()=='狗头人矿工','map tooltip NPC heading not localized')
check(GameTooltipTextLeft2:GetText():find('悬赏河爪豺狼人',1,true),'map tooltip quest title not localized')
check(meta.quest=='Riverpaw Gnoll Bounty' and meta.spawn=='Kobold Miner','changed map node identity')
pfDatabase:ShowExtendedTooltip(11,GameTooltip,UIParent)
check(GameTooltipTextLeft1:GetText()=='悬赏河爪豺狼人','actual pfQuest extended tooltip not localized')
SlashCmdList.PFQUESTEPOCHZH('off')
check(pfQuest_epoch_zhCNEnabled==false,'off preference was not saved')
check(zh.enabled,'setting was partially applied before required reload')
SlashCmdList.PFQUESTEPOCHZH('status')
check(messages[#messages]:find('待重载',1,true),'status hides pending reload')
check(zh.Text('|Hplayer:Gortak:123|h[Gortak]|h')=='|Hplayer:Gortak:123|h[Gortak]|h','translated a player hyperlink name')
local partyText='|cffaaaaaa- |r|cFF00FF00Gortak|r: Kobold Miner (2/8)'
local partyCN=zh.Text(partyText)
check(partyCN:find('|cFF00FF00Gortak|r:',1,true),'translated a party member name that matches an NPC')
check(partyCN:find('狗头人矿工',1,true),'failed to translate party objective after protecting player name')
local sample='|cffffffff|Hitem:782:0:0:0|h[Painted Gnoll Armband]|h|r: 5/8 - Kobold Miner'
local started=os.clock()
for i=1,5000 do
 local display=zh.Text(sample)
 assert(display:find('5/8',1,true),'performance loop changed count')
end
local elapsed=os.clock()-started
print('BENCHMARK',scenario,'5000_display_calls_seconds',string.format('%.4f',elapsed))
assert(elapsed<4,'Display translation regression: 5000 calls exceeded 4 CPU seconds')
print('PASS',scenario,passed,'hooks',hookCount,'lua_kib',math.floor(collectgarbage('count')))
