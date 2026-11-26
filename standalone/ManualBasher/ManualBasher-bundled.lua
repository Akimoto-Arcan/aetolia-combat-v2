local Factory=(function()
-- ManualBasher: pure factory, no global installation or sends on load.
local M = {}
local function lower(v) return tostring(v or ''):lower() end
local function yes(v) return v == true or v == 1 or v == '1' end
local function bal(v) if v.balance~=nil then return v.balance end; return v.bal end
local function eq(v) if v.equilibrium~=nil then return v.equilibrium end; return v.eq end
local function no(v) return v == false or v == 0 or v == '0' end
local function id(v) local s=tostring(v or ''); if s:match('^%d+$') and tonumber(s)>0 then return s end end
local function protected(n)
 n=lower(n)
 if ({['clive, a sly-looking bandit']=true,['khabarak, the jeweler']=true,['belok, the mining chief']=true,['thelvoro stonefist']=true})[n] then return true end
 for w in n:gmatch('%a+') do
  if ({guard=true,guards=true,loyal=true,horse=true,horses=true,steed=true,steeds=true,roc=true,rocs=true,mount=true,mounts=true,mounted=true,corpse=true})[w] then return true end
 end
 return false
end
function M.new(api, db)
 local s={enabled=false, reason='default OFF', class='Earthcaller', command='quash {target}', room=nil, generation=0, items={}, target=nil, pending=nil, request=nil, readySeq=0, seq=0, prompt=0, lastSend=-100, area=nil, vitals=nil, status=nil, inventory={}, affs=nil, destroyed=false}
 s.irongrip=true; s.ironActive=nil; s.ironKnown=nil
 local self={state=s}
 local function say(t) api.notice('[ManualBasher] '..t) end
 local function off(reason) s.enabled=false; s.reason=reason or 'manual OFF'; say('OFF: '..s.reason) end
 self.off=off
 local function scope()
  if s.area then return db[s.area] end
  local found
  for _,a in pairs(db) do if a.areas and a.areas[s.nativeArea] then if found and found~=a then return nil end; found=a end end
  return found
 end
 local function classOK()
  if not s.status or lower(s.status.class)~=lower(s.class) then return false end
  local stats=(s.vitals or {}).charstats
  if stats~=nil and type(stats)~='table' then return false end
  for _,v in pairs(stats or {}) do
   local c=tostring(v):match('^[Cc]lass:%s*(.-)%s*$')
   if c and lower(c)~=lower(s.class) then return false end
  end
  return true
 end
 local function eligible(it)
  if type(it)~='table' or not id(it.id) or not it.name or protected(it.name) then return false end
  local a=lower(it.attrib or it.attributes)
  -- Aetolia positive mobile flag plus deliberately narrow known flags.
  if a~='m' then return false end
  if it.icon~=nil and not ({['']=true,m=true,mob=true,monster=true,['face-angry-horns']=true})[lower(it.icon)] then return false end
  if it.player or it.loyal or it.vendor or it.corpse or it.mount or it.dead or it.protected then return false end
  local area=scope(); return area and area.mobs and (area.mobs[it.name] == true or area.mobs[lower(it.name)] == true)
 end
 local function request()
  if s.request or not s.room then return end
  s.request={generation=s.generation, at=api.now()}; api.gmcp('Char.Items.Room')
 end
 function self.room(info)
  if not info or not info.num then return end
  local r=tostring(info.num)
  if r~=s.room then
   s.room=r; s.nativeArea=info.area; s.generation=s.generation+1; s.items={}; s.target=nil; s.snapshot=nil
   -- Keep an in-flight request as a drain barrier; never label its reply fresh after moving.
   request()
  else s.nativeArea=info.area end
 end
 function self.list(msg)
  if not msg or msg.location~='room' or not s.request then return end
  local req=s.request; s.request=nil
  if req.generation~=s.generation then request(); return end
  s.items={}
  for _,it in pairs(msg.items or {}) do local n=id(it.id); if n then s.items[n]=it end end
  s.snapshot=s.generation
  if s.target and not eligible(s.items[s.target]) then s.target=nil end
 end
 function self.item(kind,msg)
  if not msg or msg.location~='room' or s.snapshot~=s.generation then return end
  local it=msg.item or msg; local n=id(it.id or msg.id); if not n then return end
  if kind=='remove' then s.items[n]=nil
  elseif kind=='update' then
   if not s.items[n] then return end
   for k,v in pairs(it) do s.items[n][k]=v end
  else s.items[n]=it end
  if s.target==n and not eligible(s.items[n]) then s.target=nil end
 end
 function self.status(v)
  if s.status and v and s.status.name and v.name~=s.status.name then self.disconnect() end
  s.status=v
  if s.enabled and not classOK() then off('class unavailable or changed') end
 end
 function self.afflictions(v) s.affs=v end
 function self.inv(msg)
  if not msg or msg.location~='inv' then return end
  s.inventory={}; for _,it in pairs(msg.items or {}) do s.inventory[tostring(it.id)]=it end
  s.invAt=api.now()
 end
 function self.invItem(kind,msg)
  if not msg or msg.location~='inv' then return end
  local it=msg.item or msg; local n=id(it.id or msg.id); if not n then return end
  if kind=='remove' then s.inventory[n]=nil else
   local old=s.inventory[n] or {}; for k,v in pairs(it) do old[k]=v end; s.inventory[n]=old
  end
  s.invAt=api.now()
 end
 local function wielded()
  local v=s.vitals or {}
  for _,key in ipairs({'wield_left','wield_right'}) do
   if type(v[key])=='string' and (v[key]:match('^crozier%d+$') or v[key]:match('^flail%d+$')) then return true end
  end
  return false
 end
 function self.ironKnown(known) s.ironKnown=known; s.ironQuery=nil; if not known and s.enabled and s.irongrip then off('Irongrip not Known: Yes; select racial skill manually, or mb irongrip off') end end
 function self.iron(active)
  s.ironActive=active
  if active and s.pending and s.pending.kind=='irongrip' then s.pending.ack=true end
 end
 function self.defences(kind,msg)
  if kind=='list' then
   local active=false
   for _,v in pairs(msg or {}) do if lower(type(v)=='table' and v.name or v)=='irongrip' then active=true end end
   self.iron(active)
  elseif lower(type(msg)=='table' and msg.name or msg)=='irongrip' then self.iron(kind=='add') end
 end
 function self.vitals(v)
  s.seq=s.seq+1; s.vitals=v; s.vitalsAt=api.now()
  local hp,max=tonumber(v.hp),tonumber(v.maxhp)
  if s.enabled and hp and max and max>0 and hp/max<0.20 then off('!!! HEALTH BELOW 20% -- STOP; MANUAL ACTION REQUIRED !!!') end
  if s.enabled and not classOK() then off('class mismatch/unavailable') end
  local p=s.pending
  if p and s.seq>p.seq then
   if no(bal(v)) then p.lost=true end
   if p.lost and yes(bal(v)) and yes(eq(v)) and (p.kind~='irongrip' or p.ack) then s.pending=nil; s.readySeq=s.seq; s.recoveryPrompt=s.prompt end
  end
 end
 local function safe()
  local v=s.vitals or {}; local hp,m=tonumber(v.hp),tonumber(v.maxhp)
  if not classOK() then return false,'class mismatch/unavailable' end
  if not hp or not m or m<=0 or hp/m<0.20 then return false,'health missing/low' end
  if not s.vitalsAt or api.now()-s.vitalsAt>3 then return false,'stale vitals' end
  if not yes(bal(v)) or not yes(eq(v)) then return false,'balance/equilibrium' end
  -- Require explicit native posture and arm status, never assume absent=false.
  if not no(v.prone) then return false,'prone unknown/active' end
  if not yes(v.left_arm) or not yes(v.right_arm) then return false,'arm balance unknown/blocked' end
  if not s.affs then return false,'waiting for native affliction list' end
  for _,name in ipairs({'left_arm_broken','right_arm_broken','left_arm_crippled','right_arm_crippled','crippled_left_arm','crippled_right_arm','broken_left_arm','broken_right_arm','mangled_left_arm','mangled_right_arm','paralysis','paresis','prone','fallen','asleep','stun','stunned'}) do
   if s.affs[name] then return false,'native impairment: '..name end
  end
  if lower(s.class)=='earthcaller' and not wielded() then return false,'no native wield evidence' end
  return true
 end
 function self.prompt()
  s.prompt=s.prompt+1
  if not s.enabled or s.destroyed then return end
  if api.conflict() then off('competing offense present; use a separate profile'); return end
  if s.pending then return end
  if s.recoveryPrompt and s.prompt<=s.recoveryPrompt then return end
  local ok,reason=safe(); if not ok then if s.reason~=reason then say('HOLD: '..reason..'; manual action required') end; s.reason=reason; return end
  if s.seq<=s.lastIssueSeq or api.now()-s.lastSend<0.30 then return end
  if s.irongrip then
   if s.ironKnown~=true then s.reason='waiting for native Racial Irongrip Known: Yes'; return end
   if s.ironActive~=true then
    s.pending={seq=s.seq,at=api.now(),lost=false,kind='irongrip',ack=false}; s.lastIssueSeq=s.seq; s.lastSend=api.now(); s.reason='Irongrip: waiting for own defence acknowledgement and BAL cycle'; api.send('irongrip'); return
   end
  end
  if s.snapshot~=s.generation or not scope() then s.reason='waiting for fresh room list / known area'; return end
  if not eligible(s.items[s.target]) then
   s.target=nil; local keys={}; for n,it in pairs(s.items) do if eligible(it) then keys[#keys+1]=n end end
   table.sort(keys,function(a,b) return tonumber(a)<tonumber(b) end); s.target=keys[1]
  end
  if not s.target then s.reason='no eligible listed NPC'; return end
  s.pending={seq=s.seq, at=api.now(), lost=false}; s.lastIssueSeq=s.seq; s.lastSend=api.now()
  s.reason='waiting for raw BAL loss/recovery'; api.send((s.command:gsub('{target}',s.target)))
 end
 s.lastIssueSeq=-1
 function self.timeout()
  if s.ironQuery and api.now()-s.ironQuery>10 then off('Irongrip help query timed out; OFF/ON after checking native help') end
  if s.pending and api.now()-s.pending.at>10 then off('attack acknowledgement/BAL recovery timed out; reconnect or wait for actual recovery') end
  if s.request and api.now()-s.request.at>10 then off('room refresh timed out; use mb refresh after reconnect') end
 end
 function self.on()
  if s.destroyed then return false end
  if api.conflict() then off('CombatV2/known offense present: use separate profile'); return false end
  if not classOK() then off('class unavailable/mismatch'); return false end
  if not scope() then off('unknown/ambiguous area: mb area <preset> while OFF'); return false end
  s.enabled=true; s.reason='armed; waiting for fresh native prompt'; say('ON -- MANUAL WALK ONLY. Stay at keyboard.'); if s.snapshot~=s.generation then request() end
  if s.irongrip and s.ironKnown==nil and not s.ironQuery then s.ironQuery=api.now(); api.send('racial help irongrip') end
  return true
 end
 function self.configure(k,v)
  if s.enabled then say('Configure only while OFF'); return false end
  if type(v)~='string' or v:find('[%c;|]') then say('Rejected control/separator characters'); return false end
  if k=='irongrip' then if v=='on' then v=true elseif v=='off' then v=false else return false end
  elseif k=='command' then
   local _,n=v:gsub('{target}',''); if n~=1 or v:gsub('{target}',''):find('[{}]') or not v:match('^[%a][%w%s{}_-]+$') then say('Use exactly one {target}; simple single command only'); return false end
  elseif k=='class' then if not v:match('^[%a][%a -]*$') then return false end
  elseif k=='area' then if v=='auto' then v=nil elseif not db[v] then say('Unknown preset. See README/catalog'); return false end
  else return false end
  s[k]=v; if k=='area' then s.items={}; s.snapshot=nil; s.target=nil end; return true
 end
 function self.refresh()
  s.items={}; s.target=nil; s.snapshot=nil
  if s.request then s.request.generation=-1 end
  api.send('look'); request()
 end
 function self.disconnect() off('disconnect/reconnect'); s.vitals=nil; s.status=nil; s.affs=nil; s.items={}; s.inventory={}; s.invAt=nil; s.room=nil; s.snapshot=nil; s.request=nil; s.ironKnown=nil; s.ironActive=nil; s.ironQuery=nil; s.ironHeader=nil; s.generation=s.generation+1 end
 function self.cleanup() off('reload/uninstall'); s.destroyed=true; if api.cleanup then api.cleanup() end end
 function self.command(line)
  local cmd,arg=tostring(line):match('^(%S+)%s*(.-)%s*$')
  if cmd=='on' then self.on() elseif cmd=='off' then off('manual OFF')
  elseif cmd=='status' then say((s.enabled and 'ON' or 'OFF')..' | '..s.reason..' | class '..s.class..' | area '..tostring(s.area or s.nativeArea)..' | target '..tostring(s.target))
  elseif cmd=='class' or cmd=='command' or cmd=='area' or cmd=='irongrip' then if self.configure(cmd,arg) then say(cmd..' set; use mb refresh') end
  elseif cmd=='refresh' then self.refresh()
  else say('mb on | off | status | command <verb {target}> | class <class> | area <preset/auto> | irongrip on/off | refresh | help. OFF to configure. Irongrip wanted ON by default; never selects racial slots or relaxes it. No walking/cures/resources. Default Earthcaller quash. Stay present.') end
 end
 return self
end
return M

end)()
local DB=(function()
return {
["ac2-a-bandit-encampment-in-the-bonro-sands"]={label="a bandit encampment in the Bonro Sands",areas={["a bandit encampment in the bonro sands"]=true},mobs={["a burly caentoi raider"]=true,["a caentoi bushwhacker"]=true,["a caentoi marauder"]=true,["a grinning caentoi cutthroat"]=true,["a grizzled caentoi highwayman"]=true,["a lappet-faced vulture"]=true,["a scarlet kestrel"]=true,["a sly caentoi vagabond"]=true,["a sun-scorched aurulent haatun"]=true,["a sun-scorched crimson haatun"]=true,["a sun-scorched sandy haatun"]=true,["a thieving caentoi outlaw"]=true,["a wiry caentoi bandit"]=true}},
["ac2-a-basilisk-lair"]={label="a basilisk lair",areas={["a basilisk lair"]=true},mobs={["a cave basilisk"]=true}},
["ac2-a-deep-underground-cavern"]={label="a deep underground cavern",areas={["a deep underground cavern"]=true},mobs={["a chaos-warped egg-laying spider"]=true,["a chaos-warped gargantuan carrier centipede"]=true,["a demonic chaos-warped spider"]=true}},
["ac2-clawhook-range"]={label="Clawhook Range",areas={["clawhook range"]=true},mobs={["a caentoi rogue"]=true,["a fleet-footed caentoi scout"]=true,["a golba brute"]=true,["a prowling barbed abosvi"]=true,["a sabre-toothed abosvi"]=true,["a skulking golban scout"]=true,["a spine-necked arrex"]=true,["a tarpen bombardier"]=true,["an ursal swordsman"]=true,["an utari warrior"]=true}},
["ac2-dovan-hollow"]={label="Dovan Hollow",areas={["dovan hollow"]=true},mobs={["a gaunt aslinn slaver"]=true,["a grim aslinn slaver"]=true,["a haughty caentoi slaver"]=true,["a hulking ursal brute"]=true,["a scarred aslinn slaver"]=true,["a sinewy aslinn slaver"]=true}},
["ac2-dun-fortress"]={label="Dun Fortress",areas={["dun fortress"]=true},mobs={["a dangerous water snake"]=true,["a demonic screamer"]=true,["a large catfish"]=true,["a slime-encrusted spitter"]=true,["an ogre bowman"]=true,["an ogre captain"]=true,["an ogre knight"]=true,["an ogre sentry"]=true,["an orc archer"]=true,["an orc captain"]=true,["an orc sergeant"]=true,["an orc soldier"]=true}},
["ac2-halls-of-tornos"]={label="Halls of Tornos",areas={["halls of tornos"]=true},mobs={["a botched phase-hound"]=true,["a crazed blood-fiend"]=true,["a malformed beast"]=true,["a mutated blood-fiend"]=true,["a rabid blood-fiend"]=true,["a snowy armadilleon"]=true,["a speckled tinyok"]=true}},
["ac2-kkirrrr-shi-hive"]={label="Kkirrrr'shi Hive",areas={["kkirrrr'shi hive"]=true},mobs={["a feral hokkali soldier"]=true,["a freshly spawned hokkali ambusher"]=true,["a malformed horkval priest"]=true,["a rabid hokkali drone"]=true,["a twisted hokkali hunter"]=true}},
["ac2-mount-humgurd"]={label="Mount Humgurd",areas={["mount humgurd"]=true},mobs={["a black-spotted cow"]=true}},
["ac2-raim-vale"]={label="Raim Vale",areas={["raim vale"]=true},mobs={["a mutilated creature"]=true,["a rabid dog"]=true}},
["ac2-raugol-fissure"]={label="Raugol Fissure",areas={["raugol fissure"]=true},mobs={["a scything skitterer"]=true,["a splintering earthrager"]=true,["a stonescale mephit"]=true,["a stonescale ravager"]=true}},
["ac2-rebels-ridge"]={label="Rebels' Ridge",areas={["rebels' ridge"]=true},mobs={["a tenacious tough"]=true}},
["ac2-riparium"]={label="Riparium",areas={["riparium"]=true},mobs={["a fearsome tiger shark"]=true,["a gelatinous polyp"]=true,["a giant octopus"]=true,["a large blackfish"]=true,["a large red crab"]=true,["a large, deepwater salmon"]=true,["a mantaglow fish"]=true,["a moray eel"]=true,["a plated ixthean"]=true,["a powerful-looking swordfish"]=true,["an angler fish"]=true}},
["ac2-scidve"]={label="Scidve",areas={["scidve"]=true},mobs={["a blood cultist"]=true,["a large gray and black dugger"]=true,["a soul cultist"]=true}},
["ac2-siha-dylis"]={label="Siha Dylis",areas={["siha dylis"]=true},mobs={["a disoriented cave bat"]=true,["a goblin batrider"]=true,["a small red squirrel"]=true}},
["ac2-spiral-of-the-corrupt"]={label="Spiral of the Corrupt",areas={["spiral of the corrupt"]=true},mobs={["a five-tentacled octopus of jade"]=true,["a miasma-wreathed electric eel"]=true,["a rot-infested swordfish"]=true,["a taint-infested shark"]=true,["an ethereal, scarred jellyfish"]=true}},
["ac2-sunwash-ascent"]={label="Sunwash Ascent",areas={["sunwash ascent"]=true},mobs={["a bald fledgling vrukh"]=true,["a disgusting fledgling vrukh"]=true,["a gnarled, decrepit vrukh"]=true,["a grotesque, battle-torn vrukh"]=true,["a menacing vrukh lurker"]=true,["a vicious, maimed vrukh"]=true,["a vrukh clutch-matron"]=true}},
["ac2-tak-re"]={label="Tak-re",areas={["tak-re"]=true},mobs={["a horrifically deformed woodpecker"]=true,["a hundred-strings jellyfish"]=true,["a mutated deer"]=true,["a vicious, mutated shark"]=true,["a warped squirrel"]=true}},
["ac2-the-bakal-chasm"]={label="the Bakal Chasm",areas={["the bakal chasm"]=true},mobs={["a basilisk hatchling"]=true,["a blinded basilisk"]=true,["a grey and brown basilisk"]=true,["a juvenile basilisk"]=true,["a spiked basilisk"]=true,["an agitated basilisk"]=true,["an armored, brown basilisk"]=true,["an oversized, grey basilisk"]=true}},
["ac2-the-barony-of-dun-valley"]={label="the Barony of Dun Valley",areas={["the barony of dun valley"]=true},mobs={["a bighorn sheep"]=true,["a crab"]=true,["a dangerous water snake"]=true,["a greyish green crocodile"]=true,["a large red crab"]=true,["a muscular mountain lion"]=true,["a poisonous snake"]=true,["a raccoon"]=true,["a tree frog"]=true}},
["ac2-the-centipede-cave"]={label="the Centipede Cave",areas={["the centipede cave"]=true},mobs={["a chitinous centipede"]=true,["a juvenile centipede"]=true,["a large centipede"]=true,["a massive centipede queen"]=true,["a skittering centipede"]=true,["a venomous centipede"]=true}},
["ac2-the-crimson-coast"]={label="the Crimson Coast",areas={["the crimson coast"]=true},mobs={["a bare-chested nazetu pirate"]=true,["a bespectacled orc pirate"]=true,["a brawny, hook-handed kelki pirate"]=true,["a broad-nosed crocodile"]=true,["a brutish orc pirate"]=true,["a djeirani smuggler"]=true,["a dwarf smuggler"]=true,["a gleaming arqeshi pirate"]=true,["a grook smuggler"]=true,["a human smuggler"]=true,["a kelki smuggler"]=true,["a large sand crab"]=true,["a massive white gull"]=true,["a minotaur smuggler"]=true,["a nazetu smuggler"]=true,["a peg-legged imp pirate"]=true,["a predatory, prism-finned kelki pirate"]=true,["a rajamala smuggler"]=true,["a stout, sure-footed dwarf pirate"]=true,["a terribly-tattooed kobold pirate"]=true,["a tsol'aa smuggler"]=true,["a wide-horned minotaur pirate"]=true,["an arborean smuggler"]=true,["an arqeshi smuggler"]=true,["an atavian smuggler"]=true,["an imp smuggler"]=true,["an ogre smuggler"]=true}},
["ac2-the-eresh-mines"]={label="the Eresh Mines",areas={["the eresh mines"]=true},mobs={["a blind wolf spider"]=true,["a slimy brown salamander"]=true,["a swarm of black beetles"]=true,["an angry vampire bat"]=true}},
["ac2-the-forgotten-depths-of-mount-helba"]={label="the forgotten depths of Mount Helba",areas={["the forgotten depths of mount helba"]=true},mobs={["a towering fungal abomination"]=true,["a withered fungal abomination"]=true}},
["ac2-the-forgotten-dome"]={label="the Forgotten Dome",areas={["the forgotten dome"]=true},mobs={["a deformed kelki ravener"]=true,["a gibbering kelki reaver"]=true,["a mutated kelki ravager"]=true,["a vile kelki prowler"]=true}},
["ac2-the-forgotten-mausoleum"]={label="The Forgotten Mausoleum",areas={["the forgotten mausoleum"]=true},mobs={["a decomposing dwarf"]=true,["a reanimated dwarf woman"]=true,["a robed reanimated dwarf"]=true,["a rotting dwarf archer"]=true}},
["ac2-the-fractal-bloom"]={label="the Fractal Bloom",areas={["the fractal bloom"]=true},mobs={["a faceted crystalline entity"]=true,["a fractured crystalline entity"]=true,["a radiant crystalline entity"]=true,["a slender crystalline entity"]=true,["a squat crystalline entity"]=true,["a towering crystalline entity"]=true}},
["ac2-the-holy-impire-of-sehal"]={label="the Holy Impire of Sehal",areas={["the holy impire of sehal"]=true},mobs={["a fluffy white sheep"]=true,["a fuzzy grey rabbit"]=true,["a soulless pixie"]=true,["a stern imp warrior"]=true}},
["ac2-the-maghuir-fissure"]={label="the Maghuir Fissure",areas={["the maghuir fissure"]=true},mobs={["an amorphous black umbra"]=true}},
["ac2-the-mannaseh-swamp"]={label="the Mannaseh Swamp",areas={["the mannaseh swamp"]=true},mobs={["a hulking miscreation"]=true,["a malformed stalker"]=true,["a miscreated avian"]=true,["a savage mutant pumpkin"]=true,["a skittering miscreation"]=true,["an amphibious malformation"]=true,["an ichorous miscreation"]=true}},
["ac2-the-maul"]={label="the Maul",areas={["the maul"]=true},mobs={["a lithe aslinn houndmaster"]=true,["a menacing aslinn gladiator"]=true,["a ravenous vakmut warhound"]=true,["a scarred aslinn gladiator"]=true,["a snarling vakmut warhound"]=true,["a wary aslinn slaver"]=true,["a wretched aslinn slaver"]=true,["an aslinn slave catcher"]=true}},
["ac2-the-morgun-forest"]={label="the Morgun Forest",areas={["the morgun forest"]=true},mobs={["a poisonous hemlock bush"]=true,["a prickly raspberry bush"]=true,["a wild boar"]=true}},
["ac2-the-nal-jin-depths"]={label="the Nal'jin Depths",areas={["the nal'jin depths"]=true},mobs={["a lurking shadow"]=true,["a serpentine jawsnapper"]=true,["a shadow ray"]=true,["a sinewy nal'jin eel"]=true,["a voracious blind-fish"]=true,["an enormous spinelash fish"]=true}},
["ac2-the-offspring"]={label="the Offspring",areas={["the offspring"]=true},mobs={["a chromatic aquatic dragonfly"]=true,["a flat-snouted scaled sheep"]=true,["a long-tailed bullfrog"]=true,["a muscular freshwater hound"]=true,["a predatory river canine"]=true,["a pudgy water badger"]=true,["an amphibious, ebon-winged hawk"]=true}},
["ac2-the-ruins-of-salma"]={label="the ruins of Salma",areas={["the ruins of salma"]=true},mobs={["a salmati warrior"]=true}},
["ac2-the-severed-grasp"]={label="the Severed Grasp",areas={["the severed grasp"]=true},mobs={["a beguiler of the depths"]=true,["a blood-rusted gearwork behemoth"]=true,["a contorting shadowdancer"]=true,["a crystalline entity of fractal phenomena"]=true,["a demonic jann"]=true,["a dissident cloud of celestial rage"]=true,["a fossilized construct"]=true,["a grotesque soldier of spear and shield"]=true,["a kaleidoscopic lepidopteran of ever-becoming"]=true,["a sanity-straining eldritch monstrosity"]=true,["a scarred and barbed boar of dyadic hunger"]=true,["a shadow-garbed chaos lady"]=true,["a shadow-struck faceless chaos entity"]=true,["a shatter-bright host"]=true,["a smoke-snorting ashlander"]=true,["a thaumaturgical construct"]=true,["a tormented angel of myriad meridian"]=true,["a twin-headed solar abomination"]=true,["a violent riftbearer"]=true,["a wavering resolution of discordant harmonies"]=true,["an ethereal vulpine mystic"]=true,["an evanescent golden knight"]=true,["an oozing puddle of heliovoric crystal"]=true}},
["ac2-the-shastaan-warrens"]={label="the Shastaan Warrens",areas={["the shastaan warrens"]=true},mobs={["a ragged kelki cultist"]=true,["a wild-eyed kelki cultist"]=true,["an aberrant, obscenely deformed kelki"]=true}},
["ac2-the-shattered-vortex"]={label="the Shattered Vortex",areas={["the shattered vortex"]=true},mobs={["a battle-worn ascendril"]=true,["a bloodleech"]=true,["a bubonis"]=true,["a chaos hound"]=true,["a chaos orb"]=true,["a chaos storm"]=true,["a chaos worm"]=true,["a chimera"]=true,["a dervish"]=true,["a fetish-decorated shaman"]=true,["a green slime"]=true,["a humbug"]=true,["a minion of chaos"]=true,["a nimble sentinel"]=true,["a petrified treant"]=true,["a reinforcement warrior of the demonsbane"]=true,["a sharp-toothed gremlin"]=true,["a simpering sycophant"]=true,["a soulmaster"]=true,["a stalwart templar"]=true,["a warped turtle"]=true,["an agile sentaari monk"]=true,["an ascendril mage"]=true,["an ethereal firelord"]=true}},
["ac2-the-squal"]={label="the Squal",areas={["the squal"]=true},mobs={["a camouflaged keeper guerrilla"]=true,["a sly keeper tamer"]=true,["a thuggish keeper brute"]=true}},
["ac2-the-temple-of-sonn"]={label="the Temple of Sonn",areas={["the temple of sonn"]=true},mobs={["a choke creeper"]=true,["a giant fly"]=true,["a giant mosquito"]=true,["a giant moth"]=true,["a glossy black silk-spinner"]=true}},
["ac2-the-torturers-caverns"]={label="the Torturers' Caverns",areas={["the torturers' caverns"]=true},mobs={["a blood construct"]=true,["a flesh golem sentry"]=true,["a maggot-ridden skeleton"]=true,["a rank ghoul"]=true,["a voracious blind-fish"]=true}},
["ac2-the-village-of-torston"]={label="the village of Torston",areas={["the village of torston"]=true},mobs={["a fierce crocodile"]=true,["a mottled brown frog"]=true,["a venomous water snake"]=true,["an enormous blue-green crocodile"]=true}},
["ac2-the-welto-trench"]={label="the Welto Trench",areas={["the welto trench"]=true},mobs={["a black bull shark"]=true,["a black hunter shark"]=true,["a black tiger shark"]=true,["a black welto shark"]=true,["a blacktip shark"]=true,["a box jellyfish"]=true,["a bronze bull shark"]=true,["a bronze hunter shark"]=true,["a bronze tiger shark"]=true,["a bronze welto shark"]=true,["a brown bull shark"]=true,["a brown hunter shark"]=true,["a brown tiger shark"]=true,["a brown welto shark"]=true,["a giant manta ray"]=true,["a great white bull shark"]=true,["a great white hunter shark"]=true,["a great white tiger shark"]=true,["a great white welto shark"]=true,["a grey bull shark"]=true,["a grey hunter shark"]=true,["a grey tiger shark"]=true,["a grey welto shark"]=true,["a scarred bull shark"]=true,["a scarred hunter shark"]=true,["a scarred tiger shark"]=true,["a scarred welto shark"]=true,["a spotted bull shark"]=true,["a spotted hunter shark"]=true,["a spotted tiger shark"]=true,["a spotted welto shark"]=true,["a stone crab"]=true,["a storm-wing harpy"]=true,["a striped bull shark"]=true,["a striped hunter shark"]=true,["a striped tiger shark"]=true,["a striped welto shark"]=true}},
["ac2-yohanan-village"]={label="Yohanan Village",areas={["yohanan village"]=true},mobs={["a cave bat"]=true,["a mangy rat"]=true}},
["ac2-yuzurai-village"]={label="Yuzurai village",areas={["yuzurai village"]=true},mobs={["a massive rojalli matriarch"]=true,["a savage rojalli"]=true,["a sleek black rojalli"]=true}},
["alaqsii"]={label="Alaqsii Inlet",areas={["alaqsii inlet"]=true},mobs={["an arctic wolf"]=true}},
["augerweald"]={label="Augerweald",areas={["augerweald"]=true,["the augerweald"]=true},mobs={["a gargantuan augerweald rabbit"]=true,["a large, snowy fox"]=true,["a silvery pink salmon"]=true,["a tall, white elk"]=true,["an agitated direwolf"]=true}},
["ayhesa"]={label="Ayhesa Cliffs",areas={["ayhesa cliffs"]=true},mobs={["a spellshaper adept"]=true,["a spellshaper archon"]=true,["a spellshaper master"]=true}},
["azdun"]={label="Azdun Dungeon",areas={["the azdun dungeon"]=true},mobs={["a huge pulsating spider"]=true,["a large pulsating spider"]=true,["a medium pulsating spider"]=true}},
["bloodwood"]={label="Bloodwood",areas={["bloodwood"]=true},mobs={["a distressed spirit"]=true,["a lingering spirit"]=true,["a wailing spirit"]=true}},
["darkside-a-memory-of-relovec-mansion"]={label="a memory of Relovec Mansion",areas={["a memory of relovec mansion"]=true},mobs={["an enraged memory of a female servant"]=true,["an enraged memory of a female villager"]=true,["an enraged memory of a male servant"]=true,["an enraged memory of a male villager"]=true}},
["darkside-asper"]={label="Asper",areas={["asper"]=true},mobs={["a failed experiment"]=true,["a fearsome icewyrm"]=true,["a malevolent spectre"]=true,["a snowshoe hare"]=true,["a wild bobcat"]=true,["an animated golem of flesh"]=true}},
["darkside-catacombs-beneath-djeir"]={label="Catacombs beneath Djeir",areas={["catacombs beneath djeir"]=true},mobs={["a djeirani ghost"]=true}},
["darkside-chapel-garden"]={label="Chapel Garden",areas={["chapel garden"]=true},mobs={["a diminutive necromancer"]=true,["a foul-smelling zombie"]=true,["a zombie cleric"]=true}},
["darkside-court-of-the-consortium"]={label="Court of the Consortium",areas={["court of the consortium"]=true},mobs={["a crystal-encrusted golem"]=true,["a disembodied soul"]=true,["a massive striped worm"]=true,["a shambling skeleton"]=true,["a spatial anomaly"]=true}},
["darkside-forsaken-evlasu"]={label="Forsaken Evlasu",areas={["forsaken evlasu"]=true},mobs={["a corrupted cultist"]=true,["a grotesque, warped aberration"]=true,["a hideous winged aberration"]=true,["an unnaturally lithe, shadowy aberration"]=true}},
["darkside-mount-heylai"]={label="Mount Heylai",areas={["mount heylai"]=true},mobs={["a dwarf geared up for battle"]=true,["a dwarven warrior"]=true,["an armored dwarf"]=true}},
["darkside-the-aureliana-forest"]={label="the Aureliana Forest",areas={["the aureliana forest"]=true},mobs={["a dark-furred, rabid boar"]=true,["a wild boar"]=true}},
["darkside-the-beaches-of-liris"]={label="the beaches of Liris",areas={["the beaches of liris"]=true},mobs={["a blue-shelled snail"]=true,["a gargantuan crab"]=true,["a red hermit crab"]=true,["a slimy red-shelled snail"]=true,["a small, red crab"]=true,["a yellow-finned bream fish"]=true,["an orange-and-yellow stripped starfish"]=true}},
["darkside-the-caverns-of-telfinne"]={label="the Caverns of Telfinne",areas={["the caverns of telfinne"]=true},mobs={["a cave-dwelling avisme"]=true,["a draconic zogura"]=true,["a fanged lugore"]=true,["a slender synicant"]=true,["a slimy aryeim"]=true,["a tentacled morbol"]=true}},
["darkside-the-crags"]={label="the Crags",areas={["the crags"]=true},mobs={["a dark grey stone worm"]=true,["a hulking snatcher"]=true,["a light grey stone worm"]=true,["a steady cragling"]=true,["a vile snatcher"]=true}},
["darkside-the-den-of-shadows"]={label="the Den of Shadows",areas={["the den of shadows"]=true},mobs={["a black adder"]=true,["a black boa"]=true,["a black cobra"]=true,["a black krait"]=true,["a black python"]=true,["a black sidewinder"]=true,["a brown adder"]=true,["a brown boa"]=true,["a brown cobra"]=true,["a brown krait"]=true,["a brown python"]=true,["a brown sidewinder"]=true,["a grey adder"]=true,["a grey boa"]=true,["a grey cobra"]=true,["a grey krait"]=true,["a grey python"]=true,["a grey sidewinder"]=true,["a horribly-mutated experiment"]=true,["a tan adder"]=true,["a tan boa"]=true,["a tan cobra"]=true,["a tan krait"]=true,["a tan python"]=true,["a tan sidewinder"]=true,["a white adder"]=true,["a white boa"]=true,["a white krait"]=true,["a white python"]=true,["a white sidewinder"]=true}},
["darkside-the-dolbodi-campsite"]={label="the Dolbodi Campsite",areas={["the dolbodi campsite"]=true},mobs={["a great white stag"]=true,["a lithe buckawn"]=true}},
["darkside-the-feral-caves"]={label="the Feral Caves",areas={["the feral caves"]=true},mobs={["a gigantic green blob"]=true,["a massive green blob"]=true,["a slimy green blob"]=true,["a small green blob"]=true}},
["darkside-the-ilhavon-forest"]={label="the Ilhavon Forest",areas={["the ilhavon forest"]=true},mobs={["a bear cub"]=true,["a blackbird"]=true,["a burrowing owl"]=true,["a catfish"]=true,["a dull brown lamprey"]=true,["a frazzled-looking possum"]=true,["a gargantuan cicada"]=true,["a giant pugnax crab"]=true,["a golden scale rattlesnake"]=true,["a harpoon scorpion"]=true,["a lake trout"]=true,["a large buck"]=true,["a lumbering brown bear"]=true,["a magpie"]=true,["a moth"]=true,["a plump duck"]=true,["a school of fish"]=true,["a white tailed doe"]=true,["an eerily glowing jellyfish"]=true}},
["darkside-the-lost-city-of-iviofiyiedu"]={label="the lost city of Iviofiyiedu",areas={["the lost city of iviofiyiedu"]=true},mobs={["a ghost of a female mhun"]=true,["a ghost of a male mhun"]=true,["a ghost of a mhun soldier"]=true}},
["darkside-the-siroccian-mountains"]={label="the Siroccian Mountains",areas={["the siroccian mountains"]=true},mobs={["a powerful wolverine"]=true,["a vicious wolverine"]=true}},
["darkside-the-siroccian-tunnels"]={label="the Siroccian Tunnels",areas={["the siroccian tunnels"]=true},mobs={["a crystal-encrusted golem"]=true,["a disembodied soul"]=true,["a lurking shadow"]=true,["a massive striped worm"]=true,["a spatial anomaly"]=true,["a voracious blind-fish"]=true}},
["darkside-the-tarblack-marshes"]={label="the Tarblack Marshes",areas={["the tarblack marshes"]=true},mobs={["a grotesque bloater"]=true,["a lumbering stonefiend"]=true,["a rock scorpion"]=true,["a tarclaw caiman"]=true}},
["darkside-the-tarean-caverns"]={label="the Tarean Caverns",areas={["the tarean caverns"]=true},mobs={["a blood-spattered leopard"]=true,["a frothing, manic buffalo"]=true,["a gigantic cave bear"]=true,["a rotting rattlesnake"]=true,["a small, black bat"]=true,["an irritable, rabid zebra"]=true,["an unkempt trog"]=true}},
["darkside-the-undercity-of-djeir"]={label="the Undercity of Djeir",areas={["the undercity of djeir"]=true},mobs={["a carnivorous weed"]=true,["a fearsome suria serpent"]=true,["a gargantuan spider"]=true,["a giant squid"]=true,["a monstrous coelacanth"]=true,["a mutated crawler fish"]=true,["a striped sea krait"]=true,["a striped siriskal fish"]=true,["an electric eel"]=true,["an elusive black fish"]=true}},
["darkside-the-valley-of-kalebb"]={label="the Valley of Kalebb",areas={["the valley of kalebb"]=true},mobs={["a bald eagle"]=true,["a large, speckled turtle"]=true,["a long, thin grass snake"]=true,["a plump wild rabbit"]=true,["a small green water snake"]=true,["a speckled, brown turtle"]=true}},
["darkside-the-valley-of-lodi"]={label="the Valley of Lodi",areas={["the valley of lodi"]=true},mobs={["a cave bat"]=true,["a juvenile wildcat"]=true,["a sheep"]=true,["a white hen"]=true,["an adult wildcat"]=true}},
["darkside-the-village-of-bihrkaen"]={label="the village of Bihrkaen",areas={["the village of bihrkaen"]=true},mobs={["a bihrkaen ambusher"]=true,["a bihrkaen huntress"]=true,["a bog hound"]=true,["a grotesque snapping turtle"]=true,["a horrifying bihrkaen"]=true,["a mire hound"]=true,["a mire pup"]=true,["a mossy hound"]=true,["a sickly carrion crow"]=true,["a slender mud adder"]=true,["a speckled, brown turtle"]=true,["an alpha female hound"]=true,["an alpha male hound"]=true}},
["darkside-the-village-of-gorshire"]={label="the village of Gorshire",areas={["the village of gorshire"]=true},mobs={["a large gray goose"]=true,["a large grey goose"]=true,["a lithe weasel"]=true}},
["darkside-the-village-of-rahveir"]={label="the village of Rahveir",areas={["the village of rahveir"]=true},mobs={["a corrupted spirit"]=true,["a malevolent poltergeist"]=true}},
["direant"]={label="a direant hill",areas={["a direant hill"]=true},mobs={["a bulbous direant bomber"]=true,["a direant rattler"]=true,["a direant soldier"]=true,["a direant worker"]=true,["a sand rattler"]=true,["a sand rattler hatchling"]=true}},
["drakuum"]={label="Drakuum",areas={["drakuum"]=true},mobs={["a blackened darkwalker"]=true,["a gnarled spirit"]=true,["a hideous lich"]=true,["a misty apparition"]=true,["a savage shade"]=true}},
["dramedo"]={label="Dramedo Warrens",areas={["the dramedo warrens"]=true},mobs={["a cloud of fungal spores"]=true,["a gigantic fungal strider"]=true,["a shambling fungal abomination"]=true,["a vast ochre ooze"]=true,["a winged fungal horror"]=true}},
["farsai"]={label="Ruins of Farsai",areas={["the ruins of farsai"]=true},mobs={["a darkling"]=true,["a shadow"]=true,["a shadowdrop"]=true,["an unctuous creepling"]=true}},
["fengard"]={label="Fengard Keep",areas={["fengard keep"]=true},mobs={["a brawny glaive knight"]=true,["a fiery phenkyre"]=true,["a horrid basilwyrm"]=true,["a massive argobole"]=true,["a pious invoker"]=true,["a pungent lichosphere"]=true,["a radiant lumore"]=true,["a shrieking grimshrill"]=true,["a tall chempala"]=true,["a vicious horned garwhol"]=true,["an ethereal construct"]=true,["an ogre berserker"]=true,["cosmina, the confessor"]=true,["derban, the ice mage"]=true,["derryk, the guardian"]=true,["gladius, the red knight"]=true,["gloom, the construct"]=true,["grothgar, the ogre warlord"]=true,["hecuba, the grim witch"]=true,["sylvos, squire of gladius"]=true,["tara, the priestess"]=true,["taskmaster grollum"]=true,["the salacious sisters"]=true,["tiber, a young telepath"]=true,["tiber. a young telepath"]=true}},
["festering"]={label="Festering Wastes",areas={["festering wastes"]=true,["the festering wastes"]=true},mobs={["a darkly patterned sand viper"]=true,["a small yellow rattlesnake"]=true,["a tiny black scorpion"]=true}},
["gloaming"]={label="Cathedral of Gloaming",areas={["the cathedral of gloaming"]=true},mobs={["a vengeful spirit"]=true}},
["hlugnic"]={label="Hlugnic Labyrinth",areas={["hlugnic labyrinth"]=true,["the hlugnic labyrinth"]=true},mobs={["a boisterous hlugna man"]=true,["a rune-covered lodestone golem"]=true,["a warden of the hlugnic clans"]=true,["an ancient multi-headed woderhund"]=true,["an enormous spinelash fish"]=true}},
["iashal"]={label="Ia'shal Barrow",areas={["ia'shal barrow"]=true,["the ia'shal barrow"]=true},mobs={["a bulbous cave spider"]=true,["a foul spiderling"]=true,["a ravenous cave spider"]=true,["an egg-laden spider"]=true}},
["iernian"]={label="Iernian Fracture",areas={["iernian fracture"]=true,["the iernian fracture"]=true},mobs={["a cacophonous cluster of eld"]=true}},
["kalydian"]={label="Kalydian Forest",areas={["kalydian forest"]=true},mobs={["a gaunt elk"]=true,["a rabid rabbit"]=true,["a ravenous squirrel"]=true}},
["khauskin"]={label="Khauskin Mines",areas={["khauskin mines"]=true},mobs={["a burly dwarven miner"]=true,["a dwarven boy"]=true,["a dwarven girl"]=true,["a grotesque fangtooth"]=true,["a powerful dwarven warrior"]=true,["a soft-shelled klikkin"]=true,["a statuesque dwarven guard"]=true,["a stocky dwarven woman"]=true,["a stout dwarven man"]=true}},
["lich"]={label="Lich Gardens",areas={["lich gardens"]=true},mobs={["a commanding lich scientist"]=true}},
["mamashi"]={label="Mamashi Tunnels",areas={["mamashi tunnels"]=true},mobs={["a githani grappler"]=true,["a githani inscriber"]=true,["a githani master"]=true,["a greater nalas"]=true,["a mature nalas"]=true,["a mit'olk axeman"]=true,["a mit'olk bladesman"]=true,["a mit'olk illusionist"]=true,["a young nalas"]=true,["garthun, the maw"]=true,["timol, the head inscriber"]=true}},
["mor"]={label="Caverns of Mor",areas={["caverns of mor"]=true},mobs={["a ravenous, shadowy ghast"]=true,["a robed, skeletal lich"]=true,["a skeletal warrior"]=true,["a stench-ridden ghoul"]=true,["a vampiric warrior"]=true,["aclyr, the vampiric general"]=true}},
["morass"]={label="Itzatl Morass",areas={["itzatl morass"]=true,["the itzatl morass"]=true},mobs={["a capybara"]=true,["a green slime toad"]=true,["a long-toothed beaver"]=true,["a poisonous water moccasin"]=true,["a silent reed cat"]=true,["a vicious snapping turtle"]=true,["an oversized earthworm"]=true,["an oversized fly"]=true}},
["ollin"]={label="Isle of Ollin",areas={["isle of ollin"]=true},mobs={["a blackened, ravenous shark"]=true,["a dark-furred, rabid boar"]=true,["a ferocious alpha syll"]=true,["a fiendish, tainted syll"]=true,["a giant, rabid syll"]=true,["a massive black crab"]=true,["a massive, verdant-furred syll"]=true,["a nazetu comfort woman"]=true,["a rotting nazetu ghoul"]=true,["a young syll cub"]=true}},
["redhands"]={label="Red Hands hideout",areas={["an abandoned hideout of the red hands"]=true},mobs={["a bronze-hued scorpion"]=true,["a golden scorpion"]=true,["a small red scorpion"]=true}},
["salma"]={label="Salma Settlement",areas={["salma settlement"]=true},mobs={["a bemused artist"]=true,["a busy mage"]=true,["a common man"]=true,["a dark-furred bear"]=true,["a dark-haired woman"]=true,["a hooded scholar"]=true,["a robust blacksmith"]=true,["a salmati guard"]=true,["a salmati warrior"]=true,["a wealthy merchant"]=true,["a wild-eyed scientist"]=true,["an energetic child"]=true,["an engrossed scholar"]=true,["an ordinary woman"]=true,["an unclean miner"]=true,["dima, captain of the salmati guard"]=true,["kyros, the salmati leader"]=true,["linette, the salmati architect"]=true}},
["snakepit"]={label="a snake pit",areas={["a snake pit"]=true},mobs={["a grassel snake"]=true,["a large sertag snake"]=true,["a muselon snake"]=true,["a tiny hatchling"]=true,["a venenigol snake"]=true,["an andragil snake"]=true,["namaqua, queen of serpents"]=true,["nandqua, mate of namaqua"]=true}},
["sparklight"]={label="Sparklight Rift",areas={["sparklight rift"]=true,["the sparklight rift"]=true},mobs={["a churning fire elemental"]=true,["a colossal elemental"]=true,["a fire elemental minion"]=true,["a greater fire elemental"]=true,["an oversized efreeti"]=true}},
["spiral"]={label="Spiral of corruption",areas={["spiral of corruption"]=true},mobs={["a five-tentacled octopus of jade"]=true,["a miasma-wreathed electric eel"]=true,["a rot-infested swordfish"]=true,["a taint-infested shark"]=true,["an ethereal, scarred jellyfish"]=true}},
["tarean-ice"]={label="Tarean Ice Caverns",areas={["tarean ice caverns"]=true,["the tarean ice caverns"]=true},mobs={["a gigantic mother icewyrm"]=true,["a ravenous ice fly"]=true,["a reanimated ice wolf"]=true,["an ornery frost gremlin"]=true}},
["tcanna"]={label="Tcanna Island",areas={["tcanna island"]=true},mobs={["a bald eagle"]=true,["a black and white badger"]=true,["a black bear"]=true,["a blue crab"]=true,["a box jellyfish"]=true,["a brown and tan python"]=true,["a brown-furred bat"]=true,["a dark green alligator"]=true,["a diseased raccoon"]=true,["a gray wolf"]=true,["a great white stag"]=true,["a howler monkey"]=true,["a large capybara"]=true,["a lithe cougar"]=true,["a long-billed toucan"]=true,["a nazetu officer"]=true,["a ragged coyote"]=true,["a scarlet macaw"]=true,["a silverback gorilla"]=true,["a small ocelot"]=true,["a spotted jaguar"]=true,["a spotted leopard"]=true,["a striped tiger"]=true,["a thick boa constrictor"]=true,["a troll cook"]=true,["a troll guard"]=true,["a venomous bushmaster"]=true,["a vicious copperhead snake"]=true,["a water buffalo"]=true,["a white goose"]=true,["a white-tailed deer"]=true,["an ebon crow"]=true,["an enormous elephant"]=true,["an oversized tortoise"]=true}},
["teshen"]={label="Teshen Caldera",areas={["teshen caldera"]=true},mobs={["a gargantuan teshen drone"]=true,["a teshen raider"]=true,["a teshen reaver"]=true,["a teshen scout"]=true,["a teshen worker"]=true}},
["threerock"]={label="Threerock Outpost",areas={["threerock outpost"]=true},mobs={["a banded scrubland racer"]=true,["a beautiful wild horse"]=true,["a huge, scarred wildcat"]=true,["a long-haired buffalo"]=true,["a mountain wildcat"]=true,["a shifty bandit"]=true,["a warbling hobgobbler"]=true,["a wildcat kitten"]=true,["an enormous troll bandit"]=true,["ennioch, a scruffy bandit"]=true,["the cave bear, white ghost"]=true,["ugtar, a tall troll bandit"]=true,["webb, a shifty bandit"]=true}},
["tiyen"]={label="Tiyen Esityi",areas={["tiyen esityi"]=true},mobs={["a ball of chitinous legs"]=true,["a bound shade"]=true,["a cancerous stallion"]=true,["a crazed nazetu cutter"]=true,["a deformed nazetu priest"]=true,["a massive, sacred serpent"]=true,["a mutated nazetu intercessor"]=true,["a nazetu captain"]=true,["a nazetu cook"]=true,["a nazetu corrupter"]=true,["a nazetu crossbowman"]=true,["a nazetu halberdier"]=true,["a nazetu necromancer"]=true,["a nazetu provost"]=true,["a supply officer"]=true,["a tangible malevolence"]=true,["a victimised intruder"]=true,["commander marakhi"]=true,["insubstantial whispers"]=true,["lieutenant chiakhi"]=true,["lieutenant gharvoi"]=true,["quartermaster kuius"]=true,["the creature beneath tiyen esityi"]=true,["tirahl the necromancer"]=true}},
["top-xaanhal"]={label="Xaanhal",areas={["xaanhal"]=true},mobs={["a bejeweled xorani harem girl"]=true,["a cautious xorani guard"]=true,["a churning tidal spectre"]=true,["a firewrought behemoth"]=true,["a helpless xorani nestling"]=true,["a merciless xorani warrior"]=true,["a stoic bedrock colossus"]=true,["a suspicious xorani patrol"]=true,["a teshen raider"]=true,["a willowy nest guardian"]=true,["a wiry xorani guard"]=true,["an arcane anomaly"]=true,["an arrogant xorani master at arms"]=true,["an electrified sparkwraith"]=true,["caelakan, an arrogant prince"]=true,["kithan, a young xorani girl"]=true}},
["xaanhal"]={label="Xaanhal",areas={["xaanhal"]=true},mobs={["a bejeweled xorani harem girl"]=true,["a cautious xorani guard"]=true,["a churning tidal spectre"]=true,["a firewrought behemoth"]=true,["a helpless xorani nestling"]=true,["a merciless xorani warrior"]=true,["a stoic bedrock colossus"]=true,["a suspicious xorani patrol"]=true,["a teshen raider"]=true,["a willowy nest guardian"]=true,["a wiry xorani guard"]=true,["an arcane anomaly"]=true,["an arrogant xorani master at arms"]=true,["an electrified sparkwraith"]=true,["caelakan, an arrogant prince"]=true,["kithan, a young xorani girl"]=true}},
["ylem"]={label="Ylem Mines",areas={["ylem mines"]=true},mobs={}}
}

end)()
-- Appended to the factory and embedded catalog by build.py. No external dependencies.
local old=rawget(_G,'ManualBasher')
local carry=old and old.state and old.state.pending
if old and old.cleanup then old.cleanup() end
local handles={events={},triggers={},aliases={},timers={}}
local obj
local function cleanup()
 for _,h in ipairs(handles.events) do killAnonymousEventHandler(h) end
 for _,h in ipairs(handles.triggers) do killTrigger(h) end
 for _,h in ipairs(handles.aliases) do killAlias(h) end
 for h in pairs(handles.timers) do killTimer(h) end
end
local function later()
 local h
 h=tempTimer(10.2,function() handles.timers[h]=nil; if obj and not obj.state.destroyed then obj.timeout() end end)
 handles.timers[h]=true
end
local function conflict()
 for _,k in ipairs({'combat_v2','CombatV2','svo','svof','m-mf','ak','rime','iasha','Iasha'}) do if rawget(_G,k)~=nil then return true end end
 return false
end
obj=Factory.new({
 now=function() return getEpoch() end,
 notice=function(s) cecho('\n<orange>'..s..'<reset>\n') end,
 send=function(s) send(s,false); later() end,
 gmcp=function(s) sendGMCP(s); later() end,
 conflict=conflict, cleanup=cleanup
},DB)
ManualBasher=obj
if carry then obj.state.pending={seq=0,at=getEpoch(),lost=carry.lost,kind=carry.kind,ack=carry.ack}; later() end
local function event(name,fn)
 handles.events[#handles.events+1]=registerAnonymousEventHandler(name,fn)
end
local function packet(a,b) return gmcp and gmcp[a] and gmcp[a][b] end
local function items(kind)
 local msg=gmcp and gmcp.Char and gmcp.Char.Items and gmcp.Char.Items[kind]
 if kind=='List' then obj.list(msg); obj.inv(msg) else obj.item(kind:lower(),msg); obj.invItem(kind:lower(),msg) end
end
event('gmcp.Room.Info',function() obj.room(packet('Room','Info')) end)
event('gmcp.Char.Status',function() obj.status(packet('Char','Status')) end)
event('gmcp.Char.Vitals',function() obj.vitals(packet('Char','Vitals') or {}) end)
for _,kind in ipairs({'List','Add','Update','Remove'}) do local k=kind; event('gmcp.Char.Items.'..k,function() items(k) end) end
local affs
for _,kind in ipairs({'List','Add','Remove'}) do
 local k=kind
 event('gmcp.Char.Afflictions.'..k,function()
  local msg=gmcp and gmcp.Char and gmcp.Char.Afflictions and gmcp.Char.Afflictions[k]
  if k=='List' then affs={}; for _,v in pairs(msg or {}) do affs[type(v)=='table' and v.name or v]=true end
  elseif affs then local n=type(msg)=='table' and msg.name or msg; if n then affs[n]=k=='Add' or nil end end
  obj.afflictions(affs)
 end)
 event('gmcp.Char.Defences.'..k,function() obj.defences(k:lower(),gmcp and gmcp.Char and gmcp.Char.Defences and gmcp.Char.Defences[k]) end)
end
handles.triggers[#handles.triggers+1]=tempPromptTrigger(function() obj.prompt() end)
local function rx(pattern,fn) handles.triggers[#handles.triggers+1]=tempRegexTrigger(pattern,fn) end
rx('^You have gained the irongrip defence\\.$',function() obj.iron(true) end)
rx('^You have lost the irongrip defence\\.$',function() obj.iron(false) end)
rx('^Your irongrip defence has been stripped\\.$',function() obj.iron(false) end)
rx('^.*[Ii]rongrip.*$',function()
 if obj.state.ironQuery then
  local text=tostring(matches and matches[1] or '')
  local known=text:match('Known:%s*(Yes)') or text:match('Known:%s*(No)')
  if known then obj.state.ironHeader=nil; obj.ironKnown(known=='Yes')
  else obj.state.ironHeader=true end
 end
end)
rx('^\\s*Known\\s*:\\s*(Yes|No)\\s*$',function()
 if obj.state.ironQuery and obj.state.ironHeader then obj.state.ironHeader=nil; obj.ironKnown(matches[2]=='Yes') end
end)
handles.aliases[#handles.aliases+1]=tempAlias('^mb(?:\\s+(.*))?$',function() obj.command(matches[2] or 'help') end)
event('sysDisconnectionEvent',function() affs=nil; obj.disconnect() end)
event('sysConnectionEvent',function() affs=nil; obj.disconnect() end)
event('sysUninstallPackage',function(_,name) if name=='ManualBasher' or name=='ManualBasher.xml' then obj.cleanup() end end)
-- No initialization from cached GMCP: require new events on this connection.
cecho('\n<orange>[ManualBasher] Loaded OFF. Separate clean profile required. Enable GMCP, reconnect, then mb help.<reset>\n')
