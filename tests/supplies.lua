-- Offline only: fake widgets, fake clock, fake transport and native fixture rows.
local path=(arg[1] or 'combat_v2/')..'supplies.lua'
local S=dofile(path)
local checks=0
local function eq(a,b,msg)
  checks=checks+1
  assert(a==b,(msg or 'equality')..': expected '..tostring(b)..', got '..tostring(a))
end
local clock, online, active = 0,true,true
local sends, ids, handlers, triggers, timers = {},0,{},{},{}
local function id(t,v) ids=ids+1; t[ids]=v; return ids end
function registerAnonymousEventHandler(event,fn) return id(handlers,{event=event,fn=fn}) end
function killAnonymousEventHandler(i) handlers[i]=nil end
function tempRegexTrigger(pattern,fn) return id(triggers,{pattern=pattern,fn=fn}) end
function tempPromptTrigger(fn) return id(triggers,{prompt=true,fn=fn}) end
function killTrigger(i) triggers[i]=nil end
function tempTimer(seconds,fn) return id(timers,{at=clock+seconds,fn=fn}) end
function killTimer(i) timers[i]=nil end
local width,height=1920,978
function getMainWindowSize() return width,height end
local created,deleted=0,0
Geyser={Label={}}
function Geyser.Label:new(opts)
  created=created+1
  local x={opts=opts}
  function x:move(a,b) self.x=a; self.y=b end
  function x:resize(a,b) self.w=a; self.h=b end
  function x:setStyleSheet(style) self.style=style end
  function x:echo(html) self.html=html end
  function x:delete() self.deleted=true; deleted=deleted+1 end
  return x
end
local function count(t) local n=0; for _ in pairs(t) do n=n+1 end; return n end
local function advance(to)
  while true do
    local nextid,nextat
    for i,t in pairs(timers) do if t.at<=to and (not nextat or t.at<nextat) then nextid,nextat=i,t.at end end
    if not nextid then break end
    clock=nextat; local fn=timers[nextid].fn; timers[nextid]=nil; fn()
  end
  clock=to
end
local function sender(cmd) sends[#sends+1]=cmd; eq(cmd=='fluidcache' or cmd=='ic' or cmd=='fc missing' or cmd=='ic missing',true,'allowlisted command'); return true end
local function context()
  return {supplies_clock=function() return clock end,
    supplies_connected=function() return online end, supplies_is_bash=function() return active end,
    supplies_sender=sender, runner={waiting=true},state={mode='BASH',balance=false}}
end
local E='==============================[     Elixirs     ]=============================='
local P='==============================[    Poultices    ]=============================='
local function frame(c,h,m)
  S.text(c,'Glancing into the cache, you see:')
  S.text(c,'-------------------------------- Pills ---------------------------------')
  for name in ('acuity amaurosis anabiotic antipsychotic coagulation decongestant depressant eucrasia euphoriant kawhepill opiate ototoxin panacea paste pluck somnium steroid stimulant thanatonin waterbreathing'):gmatch('%S+') do S.text(c,' [ 1500] '..name) end
  S.text(c,'------------------------------ Herbalism -------------------------------')
  S.text(c,' [ 1500] reishi [ 1500] willow [ 1500] yarrow')
  S.text(c,E)
  S.text(c,string.format('   [ %4d] an elixir of health         [ %4d] an elixir of mana',h or 1500,m or 1484))
  S.text(c,'   [ 1500] an elixir of speed          [ 1450] an elixir of vigor')
  S.text(c,'   [ 1400] an elixir of levitation     [ 1500] an elixir of harmony')
  S.text(c,'   [ 1500] an elixir of the arcane     [ 1500] an elixir of immunity')
  S.text(c,' [ 1500] an elixir of infusion [ 1500] an elixir of prudence [ 1500] an elixir of purgative')
  S.text(c,'')
  S.text(c,P)
  S.text(c,'   [ 1500] a mass poultice             [ 1500] a caloric poultice')
  S.text(c,'   [ 1500] an epidermal poultice       [ 1500] a mending poultice')
  S.text(c,'   [ 1500] a restoration poultice [ 1500] a soothing poultice')
  S.text(c,'')
end
local c=context(); local runner=c.runner; local state=c.state
S.attach(c)
eq(#sends,0,'attach is passive'); eq(S.state(c).level,'warning','no green on unknown')
eq(#S.state(c).unknown,40,'FC and IC curatives unknown initially')
eq(c.supplies_ui.level,'warning'); eq(c.supplies_ui.x,350); eq(c.supplies_ui.width,600)
local label=c.supplies_ui.label
for _=1,15 do S.render(c) end
eq(#sends,0,'refresh sends nothing'); eq(created,1,'no duplicate widget')
-- Genuine captured multi-column row format, including all thirteen cache fluids.
frame(c); S.text(c,'[FirstAid]: sip health'); S.text(c,'You may drink another healing elixir.'); S.prompt(c)
eq(S.state(c).level,'ok','concurrent native curing remains independent')
eq(S.state(c).stocks.health.count,1500); eq(S.state(c).stocks.mana.count,1484)
eq(S.state(c).stocks.arcane.count,1500); eq(S.state(c).stocks.restoration.count,1500)
eq(#S.state(c).unknown,0); eq(S.state(c).level,'ok')
eq(c.runner,runner,'runner identity preserved'); eq(c.state,state); eq(c.state.balance,false)
eq(S.render(c).note:find('pipes unverified',1,true)~=nil,true)
-- No injected speech/substrings or rows outside an exact native frame.
S.text(c,'Someone says, "'..E..'"'); S.text(c,'   [    0] an elixir of health'); S.prompt(c)
eq(S.state(c).stocks.health.count,1500,'chat header rejected')
S.text(c,'   [    0] an elixir of health'); S.prompt(c)
eq(S.state(c).stocks.health.count,1500,'unframed row rejected')
S.text(c,E); S.text(c,'Someone says, "[ 0] an elixir of health"'); S.prompt(c)
eq(S.state(c).stocks.health.count,1500,'chat row ignored'); eq(S.state(c).level,'warning','partial not green')
-- Critical/low warnings and sticky zero through timeout, mode stop and disconnect.
frame(c,0,100); S.prompt(c)
eq(S.state(c).level,'critical'); eq(c.supplies_ui.height>=106,true)
eq(label.style:find('#a40000',1,true)~=nil,true,'red banner')
eq(label.html:find('health',1,true)~=nil,true)
eq(label.html:find('Reserve empty; carried vials/bandages may remain.',1,true)~=nil,true)
eq(label.html:find('FC mana: 100',1,true)~=nil,true)
active=false; online=false; advance(120)
eq(S.state(c).level,'critical','disconnect preserves zero'); eq(S.state(c).stale,true)
eq(#sends,0,'no audit before explicit request')
online=true; active=true
-- Bad/duplicate/partial frames cannot clear a known critical with invented missing zeroes.
S.text(c,E); S.text(c,' [ ???] an elixir of health'); S.prompt(c)
eq(S.state(c).stocks.health.count,0)
S.text(c,E); S.text(c,' [ 1500] an elixir of health [ 1] an elixir of health'); S.prompt(c)
eq(S.state(c).stocks.health.count,0,'duplicate invalidates frame')
S.text(c,E); S.text(c,' [ 8] an elixir of mana'); S.prompt(c)
eq(S.state(c).stocks.health.count,0,'partial cannot erase omitted stock')
eq(S.state(c).stocks.mana.count,8); eq(S.state(c).stale,true)
S.text(c,E); S.text(c,' [ 1500] an elixir of health'); advance(clock+11); S.prompt(c)
eq(S.state(c).stocks.health.count,0,'expired reply not positive evidence')
S.text(c,' [ 1500] an elixir of health'); S.prompt(c)
eq(S.state(c).stocks.health.count,0,'late unframed rows rejected')
-- New header replaces staged older rows, and newer event API wins over old transactions.
S.text(c,E); S.text(c,' [ 1500] an elixir of health')
S.text(c,E); S.text(c,' [ 0] an elixir of health'); S.prompt(c)
eq(S.state(c).stocks.health.count,0,'fresh header resets frame')
frame(c); S.stock(c,'health',0,'verified-own-adapter'); S.prompt(c)
eq(S.state(c).stocks.health.count,0,'newer source beats old frame')
frame(c,50,101); S.prompt(c)
eq(S.state(c).level,'warning'); eq(label.style:find('#5e4100',1,true)~=nil,true,'amber low')
frame(c,200,201); S.prompt(c); eq(S.state(c).level,'ok','fresh positives clear zero')
for _,k in ipairs({'mass','caloric','epidermal','mending','restoration'}) do
  S.stock(c,k,0,'verified-event'); eq(S.state(c).level,'critical',k..' empty red')
  S.stock(c,k,1500,'verified-event')
end
eq(S.stock(c,'ic:reishi',0,'verified-event'),true); eq(S.state(c).level,'critical')
eq(S.stock(c,'ic:reishi',11,'verified-event'),true); eq(S.state(c).level,'warning')
eq(S.stock(c,'bad key',1,'source'),false); eq(S.stock(c,'health',-1,'source'),false)
eq(S.stock(c,'health',0/0,'source'),false); eq(S.stock(c,'health',1,''),false)
S.stock(c,'ic:reishi',500,'verified-event')
-- Audit overlap, sender reentrancy/failure and bounded cadence.
eq(S.audit(c),true); eq(#sends,2); eq(S.audit(c),false,'no concurrent requests')
frame(c); S.prompt(c); eq(S.state(c).pending,false)
local base=clock; advance(base+59); eq(#sends,2,'not per-line/per-prompt')
advance(base+65); eq(#sends,4,'two full reads per sixty-second audit; missing only on omissions')
advance(base+80); eq(S.state(c).pending,false,'unanswered request times out')
S.text(c,' [ 0] an elixir of health'); S.prompt(c)
eq(S.state(c).stocks.health.count,1500,'timeout late row ignored')
active=false; advance(base+190); eq(#sends,4,'BASH gating')
active=true; online=false; advance(base+260); eq(#sends,4,'connection gating')
online=true
local failed_before=#sends
eq(S.audit(c,function() return false end),false); eq(S.state(c).sources.fluidcache.status,'audit send failed')
eq(S.audit(c,function() error('fake transport') end),false)
eq(S.state(c).level,'warning','failure not green'); eq(#sends,failed_before)
local nested
local function reentrant(cmd)
  eq(cmd=='fluidcache' or cmd=='ic' or cmd=='fc missing' or cmd=='ic missing',true); nested=S.audit(c,sender); frame(c); S.prompt(c); return true
end
eq(S.audit(c,reentrant),true); eq(nested,false,'reentrant audit blocked'); eq(S.state(c).pending,false)
-- Small-screen sizing; no combat or native UI object is moved.
width,height=480,240; S.render(c)
eq(label.x>=0,true); eq(label.w<=width,true); eq(label.y+label.h<=height,true)
width,height=1920,978
-- Actual registered observer/prompt paths, no fake lines enter real chat.
for _,t in pairs(triggers) do if not t.prompt then line=E; t.fn(); line=' [ 0] an elixir of health'; t.fn() end end
for _,t in pairs(triggers) do if t.prompt then t.fn() end end
eq(S.state(c).stocks.health.count,0,'observer callback ingestion')
eq(count(handlers),3); eq(count(triggers),2); eq(count(timers),1)
local oldowner=c.supplies_owner; local oldtimer=timers[oldowner.timer].fn
S=dofile(path); S.attach(c)
eq(oldowner.alive,false); eq(label.deleted,true); eq(deleted,1)
eq(count(handlers),3,'reload owns only three handlers'); eq(count(triggers),2); eq(count(timers),1)
eq(S.state(c).stocks.health.count,0,'reload preserves critical'); eq(S.state(c).requested,false,'reload disarms periodic audit')
local n=#sends; oldtimer(); advance(clock+180); eq(#sends,n,'stale timer does not send')
eq(count(timers),1)
S.detach(c); eq(count(handlers),0); eq(count(triggers),0); eq(count(timers),0)
eq(c.supplies_ui,nil); eq(c.runner,runner); eq(c.state,state)
-- Real bootstrap shape: c.state is a module, c.current owns mode; TCP is third return.
function getConnectionInfo() return 'fake.invalid',23,online end
local c2={current={mode='BASH'},mode='OFF',state={},supplies_clock=function() return clock end}
S.attach(c2); local start=#sends; local t=clock
eq(S.audit(c2,sender),true); advance(t+65); eq(#sends,start+4,'native current.mode gate')
c2.current.mode='OFF'; advance(t+130); eq(#sends,start+4,'current OFF beats alias mode')
S.detach(c2)
eq(count(handlers),0); eq(count(triggers),0); eq(count(timers),0)
print('supplies: '..checks..' assertions passed (offline fake transport/UI; no live sends)')
