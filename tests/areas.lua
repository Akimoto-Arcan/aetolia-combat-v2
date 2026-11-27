local root=assert(arg[1]);local A=dofile(root..'areas.lua');local S=dofile(root..'state.lua');local B=dofile(root..'bashing.lua');B.bind(S);B.bind_areas(A)
local n=0;local function check(v,msg)assert(v,msg);n=n+1 end
local s=S.new();s.connected=true;s.room.id=1;s.room.area='Tcanna Island';s.mode='BASH'
check(A.select(s,'tcanna'),'select');check(not s.walker or not s.walker.active,'select must not walk')
local function list(items)
 B.ih_begin(s);B.ih_request(s);B.items(s,{location='room',items=items});return B.ih_select(s)
end
local wolf={id=1,name='a gray wolf',attrib='m'};local python={id=8,name='a brown and tan python',attrib='m'}
check(list({wolf,python})and s.target.name=='8','python explicit override')
check(list({python,wolf})and s.target.name=='8','list ordering changed priority')
check(list({wolf})and s.target.name=='1','absent python stale ID')
check(list({wolf,python})and s.target.name=='1','higher priority arrival must not interrupt current kill')
s.target.dead=true
check(list({wolf,python})and s.target.name=='8','highest priority selected after current target dies')
local wolf2={id=2,name='a gray wolf',attrib='m'}
S.set_target(s,'2');check(list({wolf,wolf2})and s.target.name=='2','equal priority target stability')
S.set_target(s,'999');check(list({wolf2,wolf})and s.target.name=='1','deterministic new target')
for _,flags in ipairs({'md','mx','mp','p'})do
 check(list({wolf,{id=8,name=python.name,attrib=flags,icon='monster'}})and s.target.name=='1','excluded '..flags)
end
check(list({wolf,{id=8,name='unknown monster',icon='monster'}})and s.target.name=='1','icon is not aggression')
check(A.blocked(s),'unknown living NPC must hold movement')
check(not A.catalog.drakuum.mobs['a savage shade'].aggressive,'some aggressive is not all aggressive')
check(not A.complete({location='room',items={{id=1,name='one'},{id=1,name='duplicate'}}}),'duplicate ID')
check(not A.complete({location='room',items={[2]=wolf}}),'sparse list')
check(not A.complete({location='room',items={{id=1}}}),'partial item')
B.item_changed(s,{location='room',item=wolf},true);check(not A.pick(s,s.room.items),'partial mutation invalidates certification')
list({wolf});s.room.id=2;check(not A.pick(s,s.room.items),'room snapshot stale');A.invalidate(s)
s.room.area='Other';check(not A.select(s,'tcanna'),'area selector mismatch')
check(not A.pick(s,s.room.items),'preset cannot cross area')
s.room.area='Tiyen Esityi';check(A.select(s,'tiyen'),'tiyen')
local cutters={};for i=1,4 do cutters[i]={id=i+10,name='a crazed Nazetu cutter',attrib='m'}end
check(not list(cutters),'four cutters pressure hold')
table.remove(cutters);check(list(cutters),'three cutters allowed')
check(A.configure(s,'tiyen','Tiyen Esityi',nil,{shard='fixture protective shard',nest='fixture slime nest'}),'encounter explicit configuration')
local shard={id=20,name='fixture protective shard',attrib='m'};local knight={id=21,name='a gargantuan, nightmarish knight',attrib='m'}
local cue='A gargantuan, nightmarish knight lets out a deafening howl, protectivecrimson shards forming upon his armor.'
local done='A gargantuan, nightmarish knight lets loose a guttural howl as the shards protecting him are destroyed.'
check(not A.text(s,'Someone says: '..cue),'other actor substring cannot arm')
check(A.text(s,cue),'exact encounter cue');check(list({cutters[1],knight,shard})and s.target.name=='20','shard priority')
check(A.text(s,done),'own selected shard destruction');check(list({cutters[1],knight})and s.target.name=='21','knight transition')
A.killed(s);check(not s.hunting.encounter,'own knight kill settles encounter')
A.text(s,cue);check(list({cutters[1],shard}),'select shard');S.set_target(s,'11');s.target.display_name='a crazed Nazetu cutter';check(not A.text(s,done),'unrelated target destruction cannot release')
A.invalidate(s);check(not s.hunting.encounter,'room invalidates encounter')
check(A.text(s,'A slime nest grows in the northern section of the cavern!'),'nest cue')
check(list({cutters[1],{id=30,name='fixture slime nest',attrib='m'}})and s.target.name=='30','spawned nest priority')
A.killed(s);check(not s.hunting.encounter,'own nest death')
s.connected=false;check(not A.text(s,cue)and not A.pick(s,s.room.items),'disconnect fails closed')
check(not A.select(s,'top-xaanhal'),'top Xaanhal needs private rooms')
local entries=0;for id,row in pairs(A.catalog)do for name,r in pairs(row.mobs)do check(r.provenance and r.priority and type(r.aggressive)=='boolean','missing catalog provenance '..id..' '..name);entries=entries+1 end end
print('PASS area selector '..n..' assertions; '..entries..' scoped catalog NPC rows')
