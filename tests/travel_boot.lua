local root=assert(arg[1]);local M=dofile(root..'travel_boot.lua');local n=0
local function check(x)n=n+1;assert(x,'check '..n)end
function getMudletHomeDir()return '__offline_no_profile__'end
function getRooms()return {[10]='Unique target',[11]='Duplicate',[12]='Duplicate'}end
local sends,mode_calls=0,0
local c={current={room={id=1,item_version=1,items={}},buffs={}},runner_module={},mental={},defense={hold=function()return false end},buffs={},elementals={},containers={},tattoo_module={attach=function()return true end}}
c.runner_module.bind_defense=function(fn)c.hold=fn end;c.mental.bind_defense=function(v)c.mental_guard=v end
c.buffs.service=function(_,_,_,_,policy)if policy then return {busy=true}end;sends=sends+1;return {busy=false}end
c.elementals.service=function(_,_,policy)if not policy then sends=sends+1 end end;c.containers.service=c.elementals.service
function combat_v2_set_mode(mode)mode_calls=mode_calls+1;c.mode=mode;return true end
c.travel_module={attach=function(_,settings)c.settings=settings;c.travel_owner={};return {state=c.travel_owner}end}
check(M.attach(c));check(sends==0 and mode_calls==0);check(c.settings.resolve_target_room('Unique target')==10);check(c.settings.resolve_target_room('Duplicate')==nil)
check(c.settings.room_for_items({location='room'})==nil);c.current.room.item_version=2;check(c.settings.room_for_items({location='room'})==1);check(c.settings.room_for_items({location='room'})==nil)
c.travel_owner.pending={kind='go'};check(not combat_v2_set_mode('BASH'));check(mode_calls==0);check(M.busy(c));check(not M.hold(c));c.travel_owner.pending=nil
c.travel_owner.follow_pending={};check(not M.hold(c));check(not c.hold(c.current));c.travel_owner.follow_pending=nil
for _,key in ipairs({'fault','follow_fault','dispatching','recall_due'})do c.travel_owner[key]=true;check(c.hold(c.current));check(c.buffs.service().busy);c.elementals.service();c.containers.service();check(sends==0);c.travel_owner[key]=nil end
c.travel_owner.recall_due=true;check(M.busy(c));check(not combat_v2_set_mode('BASH'));check(mode_calls==0);check(not c.defense.hold(c.current));c.travel_owner.recall_due=nil
c.tattoo_owner={txn={}};check(c.hold(c.current));check(c.mental_guard.hold(c.current));check(not combat_v2_set_mode('BASH'));check(c.buffs.service().busy);c.tattoo_owner.txn=nil
check(combat_v2_set_mode('BASH'));check(mode_calls==1);check(not c.hold(c.current));c.buffs.service();check(sends==1)
c.lunch_boot=dofile(root..'lunch_boot.lua');c.lunch_duty={active=true,busy=true,phase='buy'};c.travel_owner.recall_due=true;check(M.hold(c));check(M.busy(c));check(M.service_policy(c)=='settle');c.lunch_duty.dispatching=true;check(M.service_policy(c)=='settle');c.travel_owner.recall_due=nil;check(M.busy(c));c.lunch_duty.phase='resume';check(not M.busy(c));c.lunch_duty.dispatching=false;c.lunch_duty.phase='resume';check(not M.hold(c));c.lunch_duty.phase='buy';check(M.hold(c));c.lunch_duty.busy=false;check(not M.hold(c))
print('travel boot: '..n..' checks passed; no native commands')
