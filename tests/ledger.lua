-- Run only in a standalone Lua CLI, never inside Mudlet.
local M=dofile((arg[1] or 'combat_v2/')..'ledger.lua')
local checks=0
local function check(ok,msg) checks=checks+1;assert(ok,msg or ('check '..checks)) end
local function context()
 local t=100;local c={containers_data={quarantine='response timeout',barrier={fault='retained'}},mode='BASH',fightR={waiting=true},GLOBE={armed=true}}
 c.supplies_clock=function() return t end;c.advance=function(n)t=t+n end
 return c
end
local h={vial='Vial      Elixir       Sips    Decay',pipe='Pipe    Herb    Puffs    Decay    Lit',bandage='Bandage    Poultice    Presses    Decay'}
local function row(id,label,n,decay,lit)
 return id..'    '..label..'    '..n..'    '..(decay or 'A')..(lit and ('    '..lit) or '')
end
local rows={vial={row('vial1','an elixir of health',17,'4'),row('vial2','an elixir of health',50),row('vial3','an elixir of vigor',60,'5'),row('vial4','a purgative concoction',50),row('vial5','an elixir of the arcane',50)},pipe={row('pipe1','a reishi mushroom',10,'A','Yes')},bandage={row('bandage1','a mending poultice',20)}}
local function frame(c,k,r,closed,prompt)
 M.text(c,h[k]);M.text(c,'----------------------')
 for _,s in ipairs(r or rows[k]) do M.text(c,s) end
 if closed~=false then M.text(c,'----------------------') end
 if prompt~=false then M.prompt(c) end
end
local function native(c,line)
 local e=M.text(c,line)
 if e then check(e.cache~=nil,'only optional cache event');M.cache(c,e.cache.key,e.cache.count,e.cache.source) end
 return e
end
local sip='You take a drink of an elixir of health from a plain wooden vial.'
local infusion='You infuse a plain wooden vial with 50 doses of an elixir of health from your fluidcache.'
local pill='You swallow an anabiotic pill.'
local function has(c,needle)
 for _,v in ipairs(M.state(c).issues) do if v:find(needle,1,true) then return true end end;return false
end
local c=context();local fighter=c.fightR;local globe=c.GLOBE;local helper=c.containers_data
local s=M.state(c);check(not s.complete and s.carried.vial.health==nil,'unknown is not zero')
native(c,sip);native(c,pill)
s=M.state(c);check(s.used.health==1 and s.used['ic:anabiotic']==1,'uses without baseline')
check(s.carried.vial.health.count==nil and s.carried.pill.anabiotic.count==nil,'unknown carried counts remain unknown')
check(s.carried.pill.anabiotic.delta==-1 and s.carried.pill.anabiotic.used==1,'unknown delta and confirmed count')
for _,k in ipairs({'vial','pipe','bandage'}) do frame(c,k) end
s=M.state(c);check(s.complete and not s.completefresh,'observational completeness never helper freshness')
check(s.carried.vial.health.count==67 and s.carried.vial.health.baseline==67,'duplicate aggregate')
check(s.used.health==1 and s.carried.vial.health.used==1,'baseline never resets session counters')
check(s.sources.vial.rows.vial1.count==17 and s.sources.vial.rows.vial2.count==50,'per ID baseline metadata')
check(has(c,'vial1: expires') and not has(c,'vial2: expires') and not has(c,'vial3: expires'),'strict expiry and artifacts')
check(has(c,'mana: missing') and not has(c,'purgative: missing') and not has(c,'arcane: missing'),'coverage and special descriptions')
M.cache(c,'health',1050,'native full FC',100)
native(c,sip);s=M.state(c)
check(s.carried.vial.health.count==66 and s.cache.health.count==1050,'sip changes carried not cache')
check(s.sources.vial.rows.vial1.count==17 and s.sources.vial.rows.vial2.count==50,'no guessed consuming ID')
local baseline_at=s.carried.vial.health.observed_at
native(c,infusion);check(M.state(c).carried.vial.health.count==116,'refill adds once to aggregate')
check(M.state(c).cache.health.count==1050,'first refill line not reserve proof')
native(c,'You have 900 sips remaining in your fluidcache.')
s=M.state(c);check(s.cache.health.count==900 and s.carried.vial.health.count==116 and s.refills.health==50,'paired absolute independent of transfer')
check(s.carried.vial.health.observed_at==baseline_at and s.sources.vial.rows.vial1.count==17,'refill does not mutate per ID/baseline time')
check(not native(c,'You have 800 sips remaining in your fluidcache.'),'remaining cannot be replayed')
check(M.state(c).cache.health.count==900,'uncorrelated remaining ignored')
M.prompt(c);native(c,infusion);native(c,'You have 0 sips remaining in your fluidcache.')
check(M.state(c).cache.health.count==0,'FC final zero persisted')
native(c,sip);M.prompt(c);native(c,'You have 900 sips remaining in your fluidcache.')
check(M.state(c).cache.health.count==0,'uses/unpaired positives cannot revive zero')
M.cache(c,'health',950,'fresh authoritative FC');check(M.state(c).cache.health.count==950,'new absolute may increase')
for _,value in ipairs({-1,1.5,'+1','-1','1.2','nan','1; send("x")','99999999999999999999'}) do
 check(not M.cache(c,'health',value,'bad') and M.state(c).cache.health.count==950,'invalid count rejected')
end
check(not M.cache(c,'evil',3,'bad'),'stock allowlist')
-- IC withdrawals/deposits are absolute cache facts, and separate carried deltas.
native(c,'You remove 1 anabiotic, bringing the total in the cache to 1862.')
check(M.state(c).cache['ic:anabiotic'].count==1862,'OUTC absolute')
M.cache(c,'ic:anabiotic','1862','gmcp.IRE.Rift.Change')
native(c,pill);s=M.state(c)
check(s.cache['ic:anabiotic'].count==1862,'GMCP plus use not double charged')
check(s.used['ic:anabiotic']==2 and s.carried.pill.anabiotic.count==nil and s.carried.pill.anabiotic.received==1 and s.carried.pill.anabiotic.delta==-1,'pill unknown baseline honest')
native(c,'You store 455 anabiotic, bringing the total to 503.')
check(M.state(c).cache['ic:anabiotic'].count==503,'deposit absolute')
M.cache(c,'ic:anabiotic',503,'rift');M.cache(c,'ic:anabiotic',503,'rift')
check(M.state(c).cache['ic:anabiotic'].count==503,'repeated absolute not delta')
-- Exact own patterns only: speech, proposals, unknown fluid, signed/fraction counts.
local before=M.state(c)
for _,line in ipairs({'Bob says, "'..sip..'"','Proposed: '..sip,'You take a drink of an elixir of mystery from a plain wooden vial.','You swallow an unknown pill.','You remove +1 anabiotic, bringing the total in the cache to 3.','You remove 1.5 anabiotic, bringing the total in the cache to 3.','You store 1 anabiotic, bringing the total to -1.','You have +900 sips remaining in your fluidcache.','You have 1.5 sips remaining in your fluidcache.','You take a drink of an elixir of health from a plain wooden vial.;evil'}) do native(c,line) end
s=M.state(c);check(s.used.health==before.used.health and s.used['ic:anabiotic']==before.used['ic:anabiotic'] and s.cache.health.count==950,'injection rejected')
-- TTL, line-budget, prompt fence, and multiple infusions cannot misattribute FC.
for _,how in ipairs({'time','lines','prompt','ambiguous','unknown','malformed'}) do
 local x=context();M.cache(x,'health',0,'baseline');native(x,infusion)
 if how=='time' then x.advance(4)
 elseif how=='lines' then for i=1,7 do native(x,'unrelated') end
 elseif how=='prompt' then M.prompt(x)
 elseif how=='ambiguous' then native(x,'You infuse an academy vial with 50 doses of an elixir of vigor from your fluidcache.')
 elseif how=='unknown' then native(x,'You infuse a plain wooden vial with 50 doses of an elixir of mystery from your fluidcache.')
 else native(x,'You infuse a plain wooden vial with +50 doses of an elixir of health from your fluidcache.') end
 check(not native(x,'You have 900 sips remaining in your fluidcache.'),'uncorrelated '..how)
 check(M.state(x).cache.health.count==0,'zero retained '..how)
 M.prompt(x);native(x,infusion);native(x,'You have 800 sips remaining in your fluidcache.')
 check(M.state(x).cache.health.count==800,'correlation recovers '..how)
end
-- Staged malformed/incomplete/late lists never replace good native observations.
local old=M.state(c).carried.vial.health.count
frame(c,'vial',{row('vial1','an elixir of health',999)},true,false)
check(M.state(c).carried.vial.health.count==old,'footer requires prompt')
native(c,sip);M.prompt(c)
check(M.state(c).carried.vial.health.count==old-1,'midframe use fences stale rows')
for _,r in ipairs({{'vial1 broken row'},{row('vial1','an elixir of health',999),row('vial1','an elixir of health',999)},{row('vial1','an elixir of health','-1')},{row('vial1','an elixir of health','1.2')},{row('vial1','empty',4)}}) do
 frame(c,'vial',r);check(M.state(c).carried.vial.health.count==old-1,'malformed baseline retained')
end
frame(c,'vial',{},false);check(M.state(c).carried.vial.health.count==old-1,'incomplete retains')
frame(c,'vial',{row('vial1','an elixir of health',999)},true,false);c.advance(16);M.prompt(c)
check(M.state(c).carried.vial.health.count==old-1 and not M.state(c).pending,'late frame bounded')
frame(c,'pipe',{row('pipe1','some willow bark',8,'A','Yes')})
check(M.state(c).carried.pipe.willow.count==8,'bad vial cannot block pipe')
native(c,'You smoke some willow bark.');check(M.state(c).carried.pipe.willow.count==7 and M.state(c).carried.pipe.willow.unverified_pattern,'legacy smoke pattern explicitly unverified')
native(c,'You press a mending poultice against your torso.');check(M.state(c).carried.bandage.mending.count==19 and M.state(c).carried.bandage.mending.unverified_pattern,'legacy press pattern explicitly unverified')
frame(c,'vial',{row('vial1','an elixir of health',1)})
local totalUsed=M.state(c).used.health
for i=1,4 do native(c,sip) end
s=M.state(c);check(s.carried.vial.health.count==0 and s.carried.vial.health.uncertain and s.used.health==totalUsed+4,'overdraw clamps but never freezes counters')
frame(c,'vial');s=M.state(c);check(s.carried.vial.health.count==67 and not s.carried.vial.health.uncertain and s.used.health==totalUsed+4,'new frame restores observation not session counters')
local observed=s.carried.vial.health.observed_at;c.advance(86400)
s=M.state(c);check(s.carried.vial.health.observed_at==observed and s.carried.vial.health.count==67 and s.complete,'time alone does not expire stock')
check(has(c,'vial3: expires') and not has(c,'vial2: expires'),'expiry ages independently')
-- Disconnect keeps all observations/counters, removes confidence and pending only.
frame(c,'vial',nil,true,false);native(c,infusion);local prev=M.state(c)
M.invalidate(c);s=M.state(c)
check(not s.pending and s.cache.health.count==prev.cache.health.count and s.used.health==prev.used.health and s.carried.vial.health.count==prev.carried.vial.health.count,'disconnect preserves facts')
check(s.carried.vial.health.confidence=='disconnected' and s.cache.health.confidence=='disconnected','disconnect removes confidence')
native(c,sip);check(M.state(c).used.health==prev.used.health+1,'passive usage continues after invalidation')
check(c.containers_data==helper and helper.quarantine=='response timeout' and helper.barrier.fault=='retained','helper quarantine/barrier unchanged')
check(c.fightR==fighter and c.GLOBE==globe and c.mode=='BASH' and fighter.waiting and globe.armed,'combat identity untouched')
-- Returned state is a deep copy; consumers cannot edit observations.
s=M.state(c);s.sources.vial.rows.vial1.count=999;s.cache.health.count=999
check(M.state(c).sources.vial.rows.vial1.count==17 and M.state(c).cache.health.count~=999,'read only snapshot')
for _,name in ipairs({'send','sendGMCP','expandAlias','tempTimer','getConnectionInfo'}) do check(rawget(_G,name)==nil,'no Mudlet runtime required') end
-- Additional native and boundary fixtures, isolated from the main session.
local x=context();frame(x,'vial')
native(x,'You take a drink of an elixir of vigor from an academy vial.')
check(M.state(x).carried.vial.vigor.count==59 and M.state(x).used.vigor==1,'observed academy vigor receipt')
native(x,'You take a drink of a purgative concoction from a plain wooden vial.')
native(x,'You take a drink of an elixir of the arcane from an academy vial.')
check(M.state(x).carried.vial.purgative.count==49 and M.state(x).carried.vial.arcane.count==49,'special fluid allowlist')
frame(x,'vial',nil,true,false)
native(x,'You take a drink of an unknown elixir from a plain wooden vial.');M.prompt(x)
check(M.state(x).carried.vial.vigor.count==59 and has(x,'malformed'),'unknown receipt fences frame without invented type')
native(x,sip);check(M.state(x).used.health==1,'unknown receipt never latches usage')
frame(x,'vial');check(M.state(x).sources.vial.confidence=='observed','complete frame recovers confidence')
M.text(x,h.vial);M.text(x,'---------------------')
for i=1,514 do M.text(x,'unrelated bounded input') end
M.text(x,row('vial1','an elixir of health',999));M.text(x,'---------------------');M.prompt(x)
check(M.state(x).carried.vial.health.count==67 and not M.state(x).pending,'line budget discards late rows')
native(x,'You remove 1 anabiotic, bringing the total in the cache to 0.')
native(x,'You store 1 anabiotic, bringing the total to 1.')
check(M.state(x).carried.pill.anabiotic.received==1 and M.state(x).carried.pill.anabiotic.deposited==1 and M.state(x).carried.pill.anabiotic.delta==0,'received and deposited counters separate')
local unknownFirst=context();M.cache(unknownFirst,'health',0,'baseline')
native(unknownFirst,'You infuse a plain wooden vial with 50 doses of an elixir of mystery from your fluidcache.')
native(unknownFirst,infusion)
check(not native(unknownFirst,'You have 900 sips remaining in your fluidcache.') and M.state(unknownFirst).cache.health.count==0,'unknown infusion before known remains ambiguous until prompt')
local y=context();native(y,infusion)
check(M.state(y).carried.vial.health.count==nil and M.state(y).refills.health==50,'refill without baseline remains unknown')
native(y,'You have 900 sips remaining in your fluidcache.')
check(M.state(y).cache.health.count==900,'refill pair independent of carried baseline')
-- Same prompt may contain complete lists of multiple kinds.
local z=context()
for _,kind in ipairs({'vial','pipe','bandage'}) do frame(z,kind,nil,true,false) end
check(not M.state(z).complete and M.state(z).pending,'multi-kind stages all before prompt')
M.prompt(z);check(M.state(z).complete,'single native prompt commits each valid kind')
print('ledger: '..checks..' checks passed (offline Lua; zero commands)')
