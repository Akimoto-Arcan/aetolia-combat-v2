local created=0
local function obj(p,parent)
 created=created+1
 local o={p=p,parent=parent}
 function o:setStyleSheet(s) self.css=s end
 function o:echo(s) self.html=s end
 function o:setClickCallback(f) self.click=f end
 function o:move(x,y) self.p.x=x;self.p.y=y end
 function o:resize(w,h) self.p.width=w;self.p.height=h end
 function o:hide()end
 function o:delete()end
 return o
end
Geyser={windowList={},Label={new=function(_,p,parent)return obj(p,parent)end},Container={new=function(_,p)return obj(p)end}}
function getMainWindowSize()return 1920,945 end
function setBorderRight(w)assert(w==440)end
function deleteLabel()end
function registerAnonymousEventHandler()return 1 end
function killAnonymousEventHandler()end
local path=assert(arg[1], 'installed module path required')
local state=dofile(path..'state.lua').new()
state.player.balance='0';state.target.name='<test>'
combat_v2={current=state,runner={mode='OFF'},cure={enabled=false}}
local gui=dofile(path..'gui.lua');combat_v2.gui=gui
gui.create();gui.refresh(state,combat_v2.runner,combat_v2.cure)
local n=created;local first=gui.root
local other=dofile(path..'gui.lua');other.create();other.refresh(state,combat_v2.runner,combat_v2.cure)
assert(created==n and other.root==first,'reload leaked widgets')
assert(other.cards.target.html:find('&lt;test&gt;',1,true),'target HTML not escaped')
assert(other.cards.status.html:find('WAIT',1,true),'string zero rendered ready')
assert(first.p.y+866<=945,'content exceeds screen')
print('PASS GUI: idempotent reload, escaped target, string-zero flags, 1920x945 bounds; widgets='..created)
