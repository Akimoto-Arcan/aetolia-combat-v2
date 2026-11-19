-- Synthetic fixtures only; never loads Mudlet, profiles or execution modules.
local root=arg and arg[1] or 'combat_v2/'
local clock=100
function getEpoch() return clock end
local effects=0
local function forbidden() effects=effects+1; error('game effect forbidden') end
send=forbidden; sendGMCP=forbidden; expandAlias=forbidden
local W=dofile(root..'walker.lua')
local count=0
local function check(ok, message) assert(ok,message); count=count+1 end
local function room(exits,area) return {area=area or 7,exits=exits or {}} end
local function fresh()
 clock=100
 return {mode='BASH',connected=true,room={id=1,area='Synthetic Woods'}}
end
local rooms={
 [1]=room({north=2,east=3,west=4,south=5,up=6,down=7,['in']=8,out=9,northeast=999}),
 ['2']=room({south=1}),[3]=room({west='1'}),[4]=room({east=1},8),
 [5]=room({north=1}),[6]=room({down=1}),[7]=room({up=1}),
 [8]=room({out=1}),[9]=room({['in']=1}),[10]=room({}),
}
rooms[5].blocked=true; rooms[6].doors={down=1}; rooms[7].doors={up='2'}
rooms[8].doors={out=0}; rooms[9].doors={['in']='0'}
local g=assert(W.build(1,7,rooms))
check(g.start=='1' and g.area==7 and g.room_count==5,'graph normalization/component count')
check(g.nodes['1'].n=='2' and g.nodes['2'].s=='1' and g.nodes['1'].e=='3','normal exit normalization')
check(not g.nodes['4'] and not g.nodes['5'] and not g.nodes['6'] and not g.nodes['7'],'unsafe nodes included')
check(g.nodes['1']['in']=='8' and g.nodes['1'].out=='9','in/out or zero door states lost')
check(not g.nodes['10'] and not g.nodes['999'],'unreachable or unmapped room included')
check(not W.build(999,7,rooms) and not W.build(5,7,rooms),'invalid/blocked start accepted')
check(not W.build(1,nil,rooms),'unknown map area accepted')
local isolated=assert(W.build(1,7,{[1]=room({n=2,portal=3,e=4}),[2]=room({e=1}),[3]=room({s=1}),[4]=room({})}))
check(isolated.room_count==1 and next(isolated.nodes['1'])==nil,'one-way/wrong-reverse/special exit allowed')
local all={}; local opposite={north='south',northeast='southwest',east='west',southeast='northwest',south='north',southwest='northeast',west='east',northwest='southeast',up='down',down='up',['in']='out',out='in'}
local long={'north','northeast','east','southeast','south','southwest','west','northwest','up','down','in','out'}
all[1]=room({})
for i,d in ipairs(long) do all[1].exits[d]=i+1; all[i+1]=room({[opposite[d]]=1}) end
local star=assert(W.build('1','7',all))
check(star.room_count==13,'all long direction normalization')
for _,d in ipairs({'n','ne','e','se','s','sw','w','nw','u','d','in','out'}) do check(star.nodes['1'][d]~=nil,'missing direction '..d) end
for _,state in ipairs({1,2,-1,'1','locked',false}) do
 local r={[1]=room({n=2}),[2]=room({s=1})}; r[1].doors={north=state}
 check(W.build(1,7,r).room_count==1,'nonzero/unknown door allowed')
 r[1].doors=nil; r[2].doors={south=state}
 check(W.build(1,7,r).room_count==1,'reverse door allowed')
end
local conflict=W.build(1,7,{[1]=room({n=2,north=3}),[2]=room({s=1}),[3]=room({s=1})})
check(conflict.room_count==1,'ambiguous alias resolved arbitrarily')
local s=fresh(); local w=W.state(s)
check(not w.active and w.offers==0 and W.state(s)==w,'state defaults/identity')
check(not W.next(s) and not W.mark_clear(s,1),'inactive state moved/cleared')
local token=assert(W.offer(s,g))
check(token==1 and not w.active and not w.pending and w.offer.area==s.room.area,'offer activated or wrong scope')
check(not W.next(s),'offer moved without acceptance')
check(not W.accept(s,token+1,true) and not w.active,'wrong token accepted')
check(W.accept(s,token,false) and not w.active and not w.offer,'decline activated or retained offer')
check(not W.accept(s,token,true),'declined offer reusable')
local stale=assert(W.offer(s,g)); token=assert(W.offer(s,g))
check(token>stale and not W.accept(s,stale,true),'old offer token accepted')
check(W.accept(s,token,true) and w.active and not w.clear and not w.pending and next(w.visited)==nil,'fresh consent failed')
check(not W.next(s),'uncleared room moved')
for _,mutate in ipairs({
 function(x) x.mode='SHADOW' end,
 function(x) x.room.id=2 end,
 function(x) x.room.area='Another Area' end,
 function(x) x.connected=false end,
 function(x) x.training_battle_ended=true end,
}) do
 local x=fresh(); local t=assert(W.offer(x,g)); mutate(x)
 check(not W.accept(x,t,true) and not x.walker.active,'stale session/scope consent accepted')
end
s=fresh(); s.mode='OFF'; check(not W.offer(s,g),'non-BASH offer allowed')
s=fresh(); s.room.id=2; check(not W.offer(s,g),'wrong start offer allowed')
local function armed(graph)
 local x=fresh(); check(W.accept(x,assert(W.offer(x,graph)),true),'arm fixture')
 return x
end
-- A north-first branch requires a visited-room backtrack to cover east.
local branch=assert(W.build(1,7,{[1]=room({n=2,e=3}),[2]=room({s=1,n=4}),[3]=room({w=1}),[4]=room({s=2})}))
s=armed(branch); w=s.walker
check(not W.mark_clear(s,nil),'unversioned clear accepted')
check(W.mark_clear(s,10) and w.clear.version==10 and w.visited['1'],'clear evidence lost')
check(not W.begin_step(s,{from='1',to='3',direction='east'}),'unvalidated command accepted')
check(not W.begin_step(s,{from='2',to='1',direction='s'}),'wrong step origin accepted')
check(not W.begin_step(s,{from='1',to='4',direction='n'}),'nonadjacent step accepted')
local path={}; local versions=10
for iteration=1,20 do
 local step,reason=W.next(s)
 if not step then check(reason=='complete','coverage stalled'); break end
 path[#path+1]=step.to
 check(W.begin_step(s,step) and w.pending.at==clock and not w.clear,'step not recorded/clear retained')
 check(not W.next(s) and not W.begin_step(s,step) and not W.mark_clear(s,versions),'pending movement repeated/cleared')
 s.room.id=tonumber(step.to)
 check(W.arrive(s,step.to) and not w.pending and not w.clear,'expected arrival rejected')
 check(not W.next(s),'arrival inherited stale clear')
 versions=versions+1; check(W.mark_clear(s,versions),'arrival could not clear')
end
check(table.concat(path,',')=='2,4,2,1,3','BFS order/backtracking not deterministic')
check(not w.active and w.status=='complete' and w.steps==5,'finite traversal not complete')
for k in pairs(branch.nodes) do check(w.visited[k],'coverage missed '..k) end
check(not W.next(s) and not w.pending,'completed traversal restarted')
s=armed(branch); W.mark_clear(s,1); local step=W.next(s); W.begin_step(s,step)
s.room.id=3
check(not W.arrive(s,3) and not s.walker.active and s.walker.pending,'unexpected arrival released unresolved barrier')
s=armed(branch); s.room.id=2
check(not W.arrive(s,2) and not s.walker.active,'manual change without pending not revoked')
s=armed(branch); W.mark_clear(s,1); W.begin_step(s,W.next(s)); s.room.id=2; s.room.area='Other'
check(not W.arrive(s,2) and not s.walker.active,'cross-area expected arrival accepted')
s=armed(branch); W.mark_clear(s,1); s.room.area='Other'
check(not W.mark_clear(s,2) and not s.walker.active,'clear outside scope accepted')
s=armed(branch); W.mark_clear(s,1); step=W.next(s); W.begin_step(s,step)
clock=105; check(not W.expire(s) and s.walker.pending,'timeout before older-than-five threshold')
clock=105.01
check(W.expire(s) and not s.walker.active and s.walker.pending,'timeout did not preserve unresolved barrier')
check(s.walker.fault=='movement acknowledgement timed out' and s.walker.status==s.walker.fault,'timeout fault not latched')
check(not W.next(s) and not W.begin_step(s,step) and not W.expire(s),'timeout silently retried')
check(not W.offer(s,branch) and not W.accept(s,token,true),'timeout allowed reconsent')
s.room.id=2
check(W.arrive(s,2) and not s.walker.pending and not s.walker.active,'late expected arrival did not resolve barrier without consent')
s=armed(branch); W.mark_clear(s,1); W.begin_step(s,W.next(s)); W.stop(s,'operator stop')
check(not s.walker.active and s.walker.pending and not s.walker.offer and not s.walker.clear and s.walker.status=='operator stop','stop cleared issued hop or retained consent')
check(not W.offer(s,branch),'stopped hop permitted new offer')
s.mode='OFF';s.room.id=2
check(W.arrive(s,2) and not s.walker.pending and not s.walker.active,'OFF arrival could not acknowledge issued hop')
check(effects==0,'game effects occurred')
print('PASS walker '..count..' assertions: graph safety, consent, finite BFS/backtracking, arrival, timeout, zero game effects')
