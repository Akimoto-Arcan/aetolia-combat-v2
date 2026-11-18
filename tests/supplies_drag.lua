local S=dofile(assert(arg[1])..'supplies.lua')
local checks=0;local function check(ok,why)checks=checks+1;assert(ok,why)end
local width,height=1920,978
function getMainWindowSize()return width,height end
local function label()
 local q={};function q:move(x,y)self.x=x;self.y=y end;function q:resize(w,h)self.w=w;self.h=h end
 function q:echo(v)self.text=v end;function q:setStyleSheet(v)self.css=v end
 function q:setClickCallback(f)self.press=f end;function q:setMoveCallback(f)self.movefn=f end;function q:setReleaseCallback(f)self.release=f end
 function q:delete()self.deleted=true end;return q
end
Geyser={Label={new=function()return label()end}}
local c={supplies_connected=function()return true end,supplies_clock=function()return 100 end,current={mode='BASH'},runner={},elemental_recovery={armed=true}}
local runner,globe=c.runner,c.elemental_recovery
S.render(c);local q=c.supplies_ui.label
check(type(q.press)=='function'and type(q.movefn)=='function'and type(q.release)=='function','drag not bound')
q.press({button='RightButton',globalX=400,globalY=30});q.movefn({globalX=500,globalY=80,buttons={'RightButton'}});check(q.x==350 and q.y==10,'right drag moved')
q.press({button='LeftButton',globalX=400,globalY=30});q.movefn({globalX=520,globalY=110,buttons={'LeftButton'}});q.release({})
check(q.x==470 and q.y==90,'drag delta wrong');S.render(c);check(q.x==470 and q.y==90,'refresh snapped')
q.movefn({globalX=800,globalY=800,buttons={'LeftButton'}});check(q.x==470 and q.y==90,'release did not stop')
q.press({button='LeftButton',globalX=520,globalY=110});q.movefn({globalX=530,globalY=120,buttons={}});check(not c.supplies_ui.drag,'missed-release held drag')
S.detach(c);c.supplies_ui=nil;S.render(c);q=c.supplies_ui.label;check(q.x==470 and q.y==90,'reload lost position')
q.press({button='LeftButton',globalX=500,globalY=100});q.movefn({globalX=-1000,globalY=-1000,buttons={'LeftButton'}});q.release({});check(q.x==0 and q.y==0,'negative bounds')
q.press({button='LeftButton',globalX=0,globalY=0});q.movefn({globalX=9000,globalY=9000,buttons={'LeftButton'}});q.release({});check(q.x+q.w<=width and q.y+q.h<=height,'positive bounds')
width,height=400,200;S.render(c);check(q.x>=0 and q.x+q.w<=width and q.y>=0 and q.y+q.h<=height,'resize bounds')
check(c.runner==runner and c.elemental_recovery==globe and c.current.mode=='BASH','combat modified')
print('PASS supply drag '..checks..' assertions: actual fake callbacks, refresh/reload retention, release, bounds and no combat mutation')
