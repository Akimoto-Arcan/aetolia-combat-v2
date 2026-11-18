-- Offline synthetic counts in genuine anchored native FC/IC layouts. No network.
local S=dofile((arg[1] or 'combat_v2/')..'supplies.lua')
local n=0
local function eq(a,b,msg) n=n+1;assert(a==b,(msg or '')..' expected '..tostring(b)..' got '..tostring(a)) end
local clock,online=0,true
local w,h=1920,978
function getMainWindowSize() return w,h end
Geyser={Label={}}
function Geyser.Label:new()
 local x={}
 function x:move(a,b) self.x=a;self.y=b end
 function x:resize(a,b) self.w=a;self.h=b end
 function x:echo(s) self.html=s end
 function x:setStyleSheet(s) self.style=s end
 return x
end
local function ctx()
 return {supplies_clock=function()return clock end,supplies_connected=function()return online end}
end
local pills={'acuity','amaurosis','anabiotic','antipsychotic','coagulation','decongestant','depressant','eucrasia','euphoriant','kawhepill','opiate','ototoxin','panacea','paste','pluck','somnium','steroid','stimulant','thanatonin','waterbreathing'}
local herbs={'reishi','willow','yarrow'}
local E='==============================[     Elixirs     ]=============================='
local P='==============================[    Poultices    ]=============================='
local function start(c) S.text(c,'Glancing into the cache, you see:');S.text(c,'-------------------------------- Pills ---------------------------------') end
local function rows(c,names,counts)
 for i=1,#names,3 do
  local line=''
  for j=i,math.min(i+2,#names) do line=line..string.format(' [ %3d] %-18s',counts[names[j]] or 300,names[j]) end
  S.text(c,line)
 end
end
local function ic(c,counts)
 counts=counts or {}; start(c);rows(c,pills,counts)
 S.text(c,'------------------------------ Herbalism -------------------------------');rows(c,herbs,counts)
 S.text(c,'-------------------------- Inks & Commodities --------------------------')
 S.text(c,' [ 0] blueink [ 0] goldink [ 0] iron')
end
local function fc(c,count)
 S.text(c,E)
 for _,k in ipairs({'health','mana','speed','vigor','levitation','harmony','arcane','immunity','infusion','prudence','purgative'}) do
  S.text(c,' [ '..(count or 300)..'] an elixir of '..(k=='arcane' and 'the arcane' or k))
 end
 S.text(c,P)
 for _,k in ipairs({'mass','caloric','epidermal','mending','restoration','soothing'}) do
  S.text(c,' [ '..(count or 300)..'] '..(k=='epidermal' and 'an' or 'a')..' '..k..' poultice')
 end
end
local function missing(c,cmd)
 if cmd=='fc missing' then
  S.text(c,'Missing elixirs: unsupported');S.text(c,'Missing poultices: unsupported')
 else
  S.text(c,'Glancing into the cache, you see the following items missing:')
  S.text(c,'------------------------------ Herbalism -------------------------------')
  S.text(c,' [ 0] berberis [ 0] bergenia')
 end
end
local c=ctx()
eq(#S.state(c).unknown,40)
ic(c,{acuity=0,amaurosis=199,anabiotic=200,stimulant=201});S.prompt(c)
eq(S.state(c).stocks['ic:acuity'].count,0)
eq(#S.state(c).empty,1);eq(#S.state(c).low,1)
eq(S.state(c).low[1],'ic:amaurosis')
eq(S.state(c).stocks.blueink,nil,'commodity not ingested')
eq(S.state(c).sources.ic.complete,true);eq(S.state(c).sources.fluidcache.stale,true)
fc(c);S.prompt(c)
eq(S.state(c).level,'critical','FC cannot clear IC zero')
eq(S.state(c).sources.ic.complete,true)
S.stock(c,'commodity:iron',0,'trusted');S.stock(c,'waterbreathing',0,'unsupported-fc')
eq(#S.state(c).empty,1,'unsupported adapter keys do not become cures')
S.stock(c,'ic:waterbreathing',199,'trusted')
eq(S.state(c).stocks.waterbreathing.count,0)
eq(S.state(c).stocks['ic:waterbreathing'].count,199,'namespaces distinct')
ic(c);S.prompt(c);eq(S.state(c).level,'ok','fresh complete refill clears')
-- Full IC Herbalism can mix curatives with noncurative crafting materials.
local crafting=ctx();fc(crafting)
start(crafting);rows(crafting,pills,{})
S.text(crafting,'------------------------------ Herbalism -------------------------------')
S.text(crafting,' [ 0] berberis [ 300] reishi [ 199] bergenia')
S.text(crafting,' [ 300] willow [ 1] berberis [ 300] yarrow')
S.prompt(crafting)
eq(S.state(crafting).sources.ic.complete,true,'crafting herbs do not invalidate full IC')
eq(S.state(crafting).sources.ic.status,'complete')
local icCount=0
for key in pairs(S.state(crafting).stocks) do if key:match('^ic:') then icCount=icCount+1 end end
eq(icCount,23,'only the 23 curatives committed')
for _,name in ipairs({'berberis','bergenia'}) do
 eq(S.state(crafting).stocks['ic:'..name],nil,'no namespaced crafting stock')
 eq(S.state(crafting).stocks[name],nil,'no bare crafting stock')
end
eq(#S.state(crafting).empty,0,'zero crafting material never alarms')
eq(#S.state(crafting).low,0,'below-200 crafting material never alarms')
eq(S.state(crafting).level,'ok')
-- Filtering must not weaken recognized curative count/duplicate validation.
for _,isMissing in ipairs({false,true}) do
 for _,badRow in ipairs({' [ ???] willow',' [ -1] willow',' [ 1.5] willow',' [ 0] willow [ 0] willow'}) do
  local invalid=ctx();S.stock(invalid,'ic:willow',0,'trusted')
  if isMissing then
   S.text(invalid,'Glancing into the cache, you see the following items missing:')
  else
   start(invalid);rows(invalid,pills,{})
  end
  S.text(invalid,'------------------------------ Herbalism -------------------------------')
  S.text(invalid,' [ 0] berberis [ 199] bergenia')
  S.text(invalid,badRow);S.prompt(invalid)
  local source=isMissing and 'ic missing' or 'ic'
  eq(S.state(invalid).sources[source].status,'malformed response',source..badRow)
  eq(S.state(invalid).sources.ic.complete,false)
  eq(S.state(invalid).stocks['ic:willow'].count,0,'invalid frame preserves known zero')
  eq(S.state(invalid).stocks['ic:acuity'],nil,'invalid frame commits no staged pills')
 end
end
-- Newer curative events still fence full replies containing crafting herbs.
S.text(crafting,'Glancing into the cache, you see:')
S.text(crafting,'-------------------------------- Pills ---------------------------------');rows(crafting,pills,{})
S.text(crafting,'------------------------------ Herbalism -------------------------------');rows(crafting,herbs,{})
S.text(crafting,' [ 0] berberis [ 199] bergenia')
S.stock(crafting,'ic:willow',501,'trusted');S.prompt(crafting)
eq(S.state(crafting).stocks['ic:willow'].count,501,'crafting filter preserves version fence')
eq(S.state(crafting).sources.ic.complete,true)
-- Missing curative rows are unknown, not invented zero, even with a complete FC.
local partial=ctx();fc(partial);S.prompt(partial)
start(partial);S.text(partial,' [ 200] acuity');S.prompt(partial)
eq(#S.state(partial).unknown,22);eq(#S.state(partial).empty,0)
eq(S.state(partial).level,'warning');eq(S.state(partial).sources.ic.complete,false)
-- Earlier positives cannot make a partial newer source healthy.
start(c);S.text(c,' [ 300] acuity');S.prompt(c)
eq(S.state(c).sources.ic.stale,true);eq(S.state(c).level,'warning')
S.stock(c,'ic:acuity',0,'trusted')
start(c);S.text(c,' [ 500] acuity');S.prompt(c)
eq(S.state(c).stocks['ic:acuity'].count,0,'incomplete cannot erase critical')
start(c);S.text(c,' [ ???] acuity');S.prompt(c)
eq(S.state(c).stocks['ic:acuity'].count,0)
start(c);S.text(c,' [ 300] acuity [ 300] acuity');S.prompt(c)
eq(S.state(c).stocks['ic:acuity'].count,0,'duplicate rejects frame')
-- A newer stock event fences old IC replies in both directions.
ic(c);S.stock(c,'ic:acuity',0,'trusted');S.prompt(c)
eq(S.state(c).stocks['ic:acuity'].count,0)
ic(c,{acuity=0});S.stock(c,'ic:acuity',500,'trusted');S.prompt(c)
eq(S.state(c).stocks['ic:acuity'].count,500)
-- Two interleaved source frames, one prompt: independent section cursors.
S.text(c,E);S.text(c,' [ 0] an elixir of health')
ic(c,{acuity=199})
S.text(c,' [ 300] an elixir of mana')
S.prompt(c)
eq(S.state(c).stocks.health.count,0);eq(S.state(c).stocks.mana.count,300)
eq(S.state(c).stocks['ic:acuity'].count,199)
eq(S.state(c).sources.ic.complete,true);eq(S.state(c).sources.fluidcache.complete,false)
-- Independent prompts: FC completion leaves pending IC and its freshness alone.
local a=ctx();local sent={}
eq(S.audit(a,function(cmd)sent[#sent+1]=cmd;return true end),true)
eq(sent[1],'fluidcache');eq(sent[2],'ic');eq(#sent,2)
fc(a);S.prompt(a)
eq(S.state(a).sources.fluidcache.stale,false);eq(S.state(a).sources.ic.pending,true)
eq(S.state(a).pending,true)
ic(a);S.prompt(a);eq(#sent,2,'no huge missing dump for complete stocks');eq(S.state(a).pending,false);eq(S.state(a).level,'ok')
clock=91;fc(a);S.prompt(a)
eq(S.state(a).sources.fluidcache.stale,false);eq(S.state(a).sources.ic.stale,true)
eq(S.state(a).level,'warning')
-- Synchronous sender false/throw must not commit staged fake successes.
local failed=ctx()
S.stock(failed,'ic:acuity',0,'trusted')
eq(S.audit(failed,function(cmd)
 if cmd=='ic' then ic(failed);S.prompt(failed);return false end
 fc(failed);S.prompt(failed);return true
end),false)
eq(S.state(failed).stocks['ic:acuity'].count,0)
eq(S.state(failed).sources.ic.status,'audit send failed')
local reentrant=ctx();local nested
local ok=S.audit(reentrant,function(cmd)
 nested=S.audit(reentrant)
 if cmd=='ic' then ic(reentrant) elseif cmd=='fluidcache' then fc(reentrant) else missing(reentrant,cmd) end
 S.prompt(reentrant);return true
end)
eq(ok,true);eq(nested,false);eq(S.state(reentrant).pending,false);eq(S.state(reentrant).level,'ok')
local threw=ctx()
eq(S.audit(threw,function(cmd)
 if cmd=='ic' then ic(threw);S.prompt(threw);error('offline transport') end
 return true
end),false)
eq(S.state(threw).stocks['ic:acuity'],nil)
-- Full low list includes all 23 named IC entries/counts, with no ellipsis.
local low={};for _,names in ipairs({pills,herbs}) do for _,name in ipairs(names) do low[name]=199 end end
local ui=ctx();fc(ui);ic(ui,low);S.prompt(ui)
local r=S.render(ui);eq(#r.low,23);eq(#r.entries,23)
for _,names in ipairs({pills,herbs}) do for _,name in ipairs(names) do
 eq(ui.supplies_ui.label.html:find('IC '..name..': 199',1,true)~=nil,true,name..' visible')
end end
eq(ui.supplies_ui.height<=300,true,'compact multi-column list')
eq(ui.supplies_ui.label.html:find('blueink',1,true),nil)
w,h=360,978;S.render(ui)
eq(ui.supplies_ui.height>300,true,'narrow layout reserves wrapping height')
eq(ui.supplies_ui.y+ui.supplies_ui.height<=h,true);eq(ui.supplies_ui.width<=w,true)
w,h=1920,978
-- Expiry and reload retain observed zeros, without attach issuing an audit.
S.stock(ui,'ic:stimulant',0,'trusted');clock=200;online=false
S.render(ui);eq(S.state(ui).level,'critical')
S=dofile((arg[1] or 'combat_v2/')..'supplies.lua');S.attach(ui)
eq(S.state(ui).stocks['ic:stimulant'].count,0);eq(S.state(ui).sources.ic.stale,true)
eq(S.state(ui).requested,false);eq(S.state(ui).level,'critical')
-- Genuine FC MISSING word-list layout, merged with a native partial full FC.
online=true;clock=300
local m=ctx();local cmds={}
S.audit(m,function(cmd)cmds[#cmds+1]=cmd;return true end)
eq(#cmds,2,'only full queries before evidence of omissions')
local function fc13(c)
 S.text(c,E)
 for _,k in ipairs({'health','mana','speed','vigor','levitation','harmony','arcane','immunity'}) do
  S.text(c,' [ 300] an elixir of '..(k=='arcane' and 'the arcane' or k))
 end
 S.text(c,P)
 S.text(c,' [ 300] a mass poultice [ 300] a caloric poultice [ 300] an epidermal poultice')
 S.text(c,' [ 300] a mending poultice [ 300] a restoration poultice')
end
local function fcMissing(c)
 S.text(c,'Missing elixirs: infusion, prudence, and purgative')
 S.text(c,'')
 S.text(c,'Missing poultices: soothing')
end
fc13(m);S.prompt(m)
eq(cmds[3],'fc missing');eq(S.state(m).sources.fluidcache.complete,false)
eq(S.state(m).stocks.infusion,nil,'omission not fabricated zero')
ic(m);S.prompt(m)
eq(#cmds,3,'complete IC omits huge missing read')
fcMissing(m)
eq(S.state(m).stocks.infusion,nil,'missing staged until native prompt')
S.prompt(m)
for _,k in ipairs({'infusion','prudence','purgative','soothing'}) do
 eq(S.state(m).stocks[k].count,0,k..' explicit missing zero')
 eq(S.state(m).stocks[k].source,'fc missing')
end
eq(S.state(m).sources.fluidcache.complete,true,'full plus explicit missing complete')
eq(S.state(m).level,'critical')
S.render(m)
eq(m.supplies_ui.label.html:find('FC infusion: 0',1,true)~=nil,true)
-- Missing snapshots are version fenced against newer trusted refill events.
fcMissing(m);S.stock(m,'infusion',500,'verified-refill');S.prompt(m)
eq(S.state(m).stocks.infusion.count,500,'old missing cannot overwrite refill')
fc(m);S.stock(m,'prudence',0,'verified-empty');S.prompt(m)
eq(S.state(m).stocks.prudence.count,0,'old full cannot overwrite newer zero')
fc(m);S.prompt(m)
eq(S.state(m).stocks.prudence.count,300,'fresh full clears zero')
-- Native single-category missing commits zero; late rows after timeout cannot commit.
local incomplete=ctx()
S.text(incomplete,'Missing elixirs: infusion, prudence, and purgative');S.prompt(incomplete)
eq(S.state(incomplete).stocks.infusion.count,0)
S.text(incomplete,'Missing elixirs: infusion, prudence, and purgative');clock=311
S.text(incomplete,'Missing poultices: soothing');S.prompt(incomplete)
eq(S.state(incomplete).stocks.soothing,nil)
-- IC full omitting one known pill requests IC MISSING, not invented zero.
local mi=ctx();local miSent={}
S.audit(mi,function(cmd)miSent[#miSent+1]=cmd;return true end)
fc(mi);S.prompt(mi)
start(mi)
for _,name in ipairs(pills) do if name~='acuity' then S.text(mi,' [ 300] '..name) end end
S.text(mi,'------------------------------ Herbalism -------------------------------');rows(mi,herbs,{})
S.prompt(mi)
eq(miSent[3],'ic missing');eq(#miSent,3)
eq(S.state(mi).stocks['ic:acuity'],nil)
S.text(mi,'Glancing into the cache, you see the following items missing:')
S.text(mi,'-------------------------------- Pills ---------------------------------')
S.text(mi,' [ 0] acuity')
S.text(mi,'------------------------------ Herbalism -------------------------------')
S.text(mi,' [ 0] berberis [ 0] bergenia [ 0] willow')
S.text(mi,'------------------------------ Gemstones -------------------------------')
for _=1,1200 do S.text(mi,' [ 0] agate [ 0] agate [ 0] ruby') end
S.text(mi,'-------------------------------- Plants --------------------------------')
S.text(mi,' [ 0] bloodroot [ 0] ginseng')
S.prompt(mi)
eq(S.state(mi).stocks['ic:acuity'].count,0)
eq(S.state(mi).stocks['ic:willow'].count,0)
eq(S.state(mi).stocks['ic:berberis'],nil)
eq(S.state(mi).stocks['ic:ginseng'],nil)
eq(S.state(mi).stocks['ic:agate'],nil)
eq(S.state(mi).sources.ic.complete,true,'large ignored sections do not malform curatives')
eq(S.state(mi).level,'critical')
-- A captured/truncated missing frame is not evidence until a real prompt.
local trunc=ctx()
S.text(trunc,'Glancing into the cache, you see the following items missing:')
S.text(trunc,'-------------------------------- Pills ---------------------------------')
S.text(trunc,' [ 0] acuity')
clock=322;S.prompt(trunc)
eq(S.state(trunc).stocks['ic:acuity'],nil,'expired missing frame cannot add zero')
-- Missing confirmation cannot refresh stale positive counts for other curatives.
clock=500
S.text(mi,'Glancing into the cache, you see the following items missing:')
S.text(mi,'------------------------------ Herbalism -------------------------------')
S.text(mi,' [ 0] berberis')
S.prompt(mi)
eq(S.state(mi).sources.ic.stale,true,'absence from missing is not positive stock proof')
-- IC missing version fences, malformed count rejection and honest partial scope.
local fenced=ctx();ic(fenced);S.prompt(fenced)
S.text(fenced,'Glancing into the cache, you see the following items missing:')
S.text(fenced,'-------------------------------- Pills ---------------------------------')
S.text(fenced,' [ 0] acuity');S.stock(fenced,'ic:acuity',501,'verified-refill');S.prompt(fenced)
eq(S.state(fenced).stocks['ic:acuity'].count,501)
S.text(fenced,'Glancing into the cache, you see the following items missing:')
S.text(fenced,'-------------------------------- Pills ---------------------------------')
S.text(fenced,' [ 1] acuity');S.prompt(fenced)
eq(S.state(fenced).stocks['ic:acuity'].count,501,'nonzero missing row rejected')
-- Older partial positive refill is applied only after complete merged evidence.
local merged=ctx();S.stock(merged,'health',0,'verified-empty')
fc13(merged);S.prompt(merged)
eq(S.state(merged).stocks.health.count,0,'partial positive cannot erase critical')
fcMissing(merged);S.prompt(merged)
eq(S.state(merged).stocks.health.count,300,'complete full+missing releases verified refill')
-- Failed synchronous missing send cannot commit the reply its callback staged.
local sync=ctx()
local synchronousResult=S.audit(sync,function(cmd)
 if cmd=='fluidcache' then fc13(sync)
 elseif cmd=='ic' then ic(sync)
 elseif cmd=='fc missing' then fcMissing(sync);S.prompt(sync);return false end
 S.prompt(sync);return true
end)
eq(synchronousResult,false)
eq(S.state(sync).stocks.infusion,nil,'false sender discards missing response')
eq(S.state(sync).sources['fc missing'].status,'audit send failed')
-- Arrival ordering is separate from commit ordering for overlapping replies.
local overlap=ctx();ic(overlap)
S.text(overlap,'Glancing into the cache, you see the following items missing:')
S.text(overlap,'-------------------------------- Pills ---------------------------------')
S.text(overlap,' [ 0] acuity');S.prompt(overlap)
eq(S.state(overlap).stocks['ic:acuity'].count,0,'newer missing beats older full in same prompt')
S.text(overlap,'Glancing into the cache, you see the following items missing:')
S.text(overlap,'-------------------------------- Pills ---------------------------------')
S.text(overlap,' [ 0] acuity');ic(overlap);S.prompt(overlap)
eq(S.state(overlap).stocks['ic:acuity'].count,300,'newer full beats old missing in same prompt')
local inflight=ctx();S.audit(inflight,function()return true end)
S.stock(inflight,'health',0,'fresh-event-before-header')
fc(inflight);S.prompt(inflight)
eq(S.state(inflight).stocks.health.count,0,'query send version fences pre-header events')
-- Native FC MISSING prints ONLY categories containing missing fluids.
local function omitFC(c,omitted)
 S.text(c,E)
 for _,k in ipairs({'health','mana','speed','vigor','levitation','harmony','arcane','immunity','infusion','prudence','purgative'})do
  if k~=omitted then S.text(c,' [ 300] an elixir of '..(k=='arcane'and'the arcane'or k))end
 end
 S.text(c,P)
 for _,k in ipairs({'mass','caloric','epidermal','mending','restoration','soothing'})do
  if k~=omitted then S.text(c,' [ 300] '..(k=='epidermal'and'an'or'a')..' '..k..' poultice')end
 end
 S.prompt(c)
end
for _,case in ipairs({{'purgative','Missing elixirs: purgative'},{'soothing','Missing poultices: soothing'}})do
 local one=ctx();omitFC(one,case[1]);eq(S.state(one).sources.fluidcache.complete,false)
 S.text(one,case[2]);S.prompt(one)
 eq(S.state(one).stocks[case[1]]and S.state(one).stocks[case[1]].count,0,'single missing category commits actual zero')
 eq(S.state(one).sources.fluidcache.complete,true,'full+one missing category completes coverage')
 eq(#S.state(one).empty,1,'absent category must not create extra zeroes')
end
-- Actual native replies retain empty category headers when no items are missing.
for _,case in ipairs({{'purgative','Missing elixirs: purgative','Missing poultices: '},{'soothing','Missing elixirs: ','Missing poultices: soothing'}})do
 local native=ctx();omitFC(native,case[1]);S.text(native,case[2]);S.text(native,case[3]);S.prompt(native)
 eq(S.state(native).sources.fluidcache.complete,true,'empty native category is not malformed')
 eq(S.state(native).stocks[case[1]].count,0,'listed zero committed')
 eq(#S.state(native).empty,1,'empty native category invents no zeroes')
end
local allEmpty=ctx();S.text(allEmpty,'Missing elixirs: ');S.text(allEmpty,'Missing poultices: ');S.prompt(allEmpty)
eq(#S.state(allEmpty).empty,0,'empty lists contain no evidence of zero')
eq(S.state(allEmpty).sources.fluidcache.complete,false,'empty lists cannot prove unobserved positives')
print('PASS supplies IC '..n..' assertions: curated scope, boundaries, independent frames/freshness, version fences, sticky zeros, bounded sends and full low-list UI')
