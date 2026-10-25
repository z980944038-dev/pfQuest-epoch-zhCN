/* Execute the localization layer against minimal pfQuest 3.3.5a API stubs.
 * This is an integration smoke test, not a replacement for in-game QA. */
'use strict';
const fs = require('fs');
const path = require('path');
const {lua, lauxlib, lualib, to_luastring, to_jsstring} = require('fengari');
const root = path.resolve(__dirname, '..');
const state = lauxlib.luaL_newstate();
lualib.luaL_openlibs(state);
function run(source, label) {
  const result = lauxlib.luaL_loadstring(state, to_luastring(source));
  if (result !== lua.LUA_OK) throw new Error(`${label}: ${to_jsstring(lua.lua_tostring(state,-1))}`);
  const done = lua.lua_pcall(state, 0, 0, 0);
  if (done !== lua.LUA_OK) throw new Error(`${label}: ${to_jsstring(lua.lua_tostring(state,-1))}`);
}
function load(relative) {
  run(fs.readFileSync(path.join(root, relative),'utf8'),relative);
}
run(String.raw`
pfDB = { locales = {enUS='English'} }
for _,kind in ipairs({'quests','items','units','objects','zones','professions'}) do
  pfDB[kind] = {enUS={},loc={}}
end
pfDB.quests.enUS[11] = {
  T='Riverpaw Gnoll Bounty',
  O='Bring 8 Painted Gnoll Armbands to Deputy Rainer at the Barracks.',
  D='Gnolls threaten Elwynn Forest.'
}
pfDB.quests.loc = pfDB.quests.enUS
pfDB.items.enUS[782] = 'Painted Gnoll Armband'
pfDB.items.loc = pfDB.items.enUS
pfQuest_Loc={}
pfQuest_config={}
SlashCmdList={}
function pfQuestDBEnglishFind(name,kind,partial)
  local matched={}
  for id,raw in pairs(pfDB[kind].loc) do
    local label=kind=='quests' and raw.T or raw
    if label and name and ((partial and string.find(label,name,1,true)) or label==name) then
      matched[id]=label
    end
  end
  return matched
end
pfDatabase={
  FormatQuestText=function(self,text) return text end,
  GetIDByName=function(self,name,kind,partial,server)
    return pfQuestDBEnglishFind(name,kind,partial)
  end,
  ShowExtendedTooltip=function(self,id,tip)
    local source=pfDB.quests.loc[id]
    tip.lines={source.T,source.O,source.D}
  end,
}
`, 'base stubs');
for (const category of ['items','units','objects','quests','zones','professions']) {
  load(`db/zhCN/${category}-epoch.lua`);
}
load('localization/zhCN-ui.lua');
load('localization/zhCN.lua');
run(String.raw`
assert(pfDB.quests.enUS[11].T == 'Riverpaw Gnoll Bounty','English source was changed')
assert(pfDB.quests.loc[11].T == 'Riverpaw Gnoll Bounty','Live English name index was changed')
assert(pfDB.quests.zhCN[11].T == '悬赏河爪豺狼人','Chinese quest title missing')
assert(pfDB.items.zhCN[782] and pfDB.items.zhCN[782] ~= pfDB.items.enUS[782],'Chinese item missing')
assert(pfDB.locales.zhCN == '简体中文','Missing locale selector')
assert(pfQuest_config.translate == 'zhCN','Chinese should be selected on first run')
assert(pfQuest_epoch_zhCNInitialized,'First-run state not saved')
assert(pfDatabase:GetIDByName('Riverpaw Gnoll Bounty','quests')[11],'English name lookup broken')
assert(pfDatabase:GetIDByName('悬赏河爪豺狼人','quests')[11],'Chinese name lookup broken')
assert(pfDatabase:GetIDByName('Riverpaw','quests',true)[11],'Partial English lookup broken')
local tip={lines={}}
function tip:GetName() return 'pfQuestTestTip' end
function tip:NumLines() return #self.lines end
function tip:Show() end
for n=1,3 do
  local idx=n
  _G['pfQuestTestTipTextLeft' .. n] = {
    GetText=function(self) return tip.lines[idx] end,
    SetText=function(self,txt) tip.lines[idx]=txt end,
  }
end
pfDatabase:ShowExtendedTooltip(11,tip)
assert(tip.lines[1] == pfDB.quests.zhCN[11].T,'Tooltip title not localized')
assert(tip.lines[2] == pfDB.quests.zhCN[11].O,'Tooltip objective not localized')
assert(tip.lines[3] == pfDB.quests.zhCN[11].D,'Tooltip description not localized')
assert(pfDB.quests.enUS[11].O == 'Bring 8 Painted Gnoll Armbands to Deputy Rainer at the Barracks.',
       'Tooltip translated the English source in place')
SlashCmdList.PFQUESTEPOCHZH('off')
assert(pfQuest_epoch_zhCNEnabled == false,'Off command failed')
assert(pfQuest_config.translate == nil,'Off command did not clear zhCN selection')
`, 'locale runtime smoke tests');
console.log('PASS: English ID resolution, Chinese quest/objective/description display, locale selector, item fallback and off switch');
