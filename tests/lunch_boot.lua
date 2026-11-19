local root=assert(arg[1]);if not root:match('/$')then root=root..'/'end
local M=dofile(root..'lunch_boot.lua');local n=0
local function check(v) n=n+1;assert(v,'lunch boot check '..n)end
local stops,modes,requests,recalls,follows=0,0,0,0,0
local c={lunch_duty={active=true,busy=false,phase='monitor'},lunch_api={},convenience={hold=function()return false end}}
c.lunch_module={user_stop=function(c)stops=stops+1;c.lunch_duty.active=false end}
c.lunch_api.combat_v2_set_mode=function(mode)modes=modes+1;c.mode=mode;return true end
local function travel()
 return {request=function()requests=requests+1;return true end,io={recall_ready=function()return true end,send_recall=function()recalls=recalls+1;return true end,send_follow=function()follows=follows+1;return true end}}
end
c.travel=travel();check(M.bind(c));check(modes==0 and stops==0 and requests==0);local guard=c.lunch_api.combat_v2_set_mode
check(M.bind(c));check(c.lunch_api.combat_v2_set_mode==guard)
check(c.travel.request('pt','17'));check(requests==1)
c.lunch_duty.busy=true;c.lunch_duty.phase='buy';check(M.busy(c));check(M.hold(c));check(c.convenience.hold(c))
check(not c.travel.request('rh'));check(requests==1);check(not c.travel.io.recall_ready());check(not c.travel.io.send_recall('recall 17'));check(recalls==0)
check(c.travel.io.send_follow('order 17 follow me'));check(follows==1)
check(not c.lunch_api.combat_v2_set_mode('BASH'));check(modes==0)
c.lunch_duty.dispatching=true;check(M.busy(c));check(not c.lunch_api.combat_v2_set_mode('BASH'));check(not c.travel.request('pt','17'));check(not c.travel.io.recall_ready());c.lunch_duty.phase='route';c.lunch_duty.destination='17';c.lunch_duty.pending={kind='route'};check(c.travel.request('pt','17'));check(not c.travel.request('pt','18'));check(not c.travel.request('rh'));check(c.lunch_api.combat_v2_set_mode('OFF'));check(stops==0 and modes==1);check(not c.travel.io.recall_ready());c.lunch_duty.pending=nil;c.lunch_duty.phase='buy'
c.lunch_duty.dispatching=false;check(c.lunch_api.combat_v2_set_mode('OFF'));check(stops==1 and modes==2);check(c.lunch_api.combat_v2_set_mode('OFF'));check(stops==2 and modes==3)
check(M.hold(c));check(M.busy(c));c.lunch_duty.active=true;c.lunch_duty.phase='resume';check(not M.hold(c));check(M.busy(c));check(not c.travel.request('qm'))
c.lunch_duty.purchase={};check(M.hold(c));c.lunch_duty.purchase=nil;check(c.travel.io.recall_ready());check(c.travel.io.send_recall('recall 17'));check(recalls==1)
c.lunch_duty.phase='initial_wait';check(not M.hold(c));c.lunch_duty.fault='unknown transport';check(M.hold(c));c.lunch_duty.fault=nil;c.lunch_duty.active=false;check(M.hold(c))
c.travel=travel();c.convenience={hold=function()return false end};check(M.bind(c));check(not c.travel.request('pt','18'));check(c.convenience.hold(c));check(c.lunch_api.combat_v2_set_mode==guard)
c.lunch_duty={active=false,busy=false,phase='idle'};check(not M.hold(c));check(not M.busy(c));check(c.travel.request('rh'));check(c.lunch_api.combat_v2_set_mode('BASH'))
c.lunch_duty.pending={kind='buy'};check(M.busy(c));check(M.hold(c));check(not c.travel.request('qd'));check(not c.lunch_api.combat_v2_set_mode('BASH'));check(c.lunch_duty.pending.kind=='buy')
print('lunch boot: '..n..' assertions passed; no native calls')
