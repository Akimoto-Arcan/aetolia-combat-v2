local created=0
local function obj(p,parent)
 created=created+1
 local o={p=p,parent=parent}
 function o:setStyleSheet(s) self.css=s end
 function o:echo(s) self.html=s end
 function o:setClickCallback(f) self.click=f end
 function o:move(x,y) self.p.x=x;self.p.y=y end
 function o:resize(w,h) self.p.width=w;self.p.height=h end
 function o:hide()self.hidden=true end
 function o:delete()self.deleted=true end
 return o
end
Geyser={windowList={},Label={new=function(_,p,parent)return obj(p,parent)end},Container={new=function(_,p)return obj(p)end}}
local screenw,screenh=1920,945;local border
function getMainWindowSize()return screenw,screenh end
function setBorderRight(w)border=w end
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
local other=dofile(path..'gui.lua');combat_v2.gui=other;other.create();other.refresh(state,combat_v2.runner,combat_v2.cure)
assert(created==n and other.root==first,'reload leaked widgets')
assert(other.cards.target.html:find('&lt;test&gt;',1,true),'target HTML not escaped')
assert(other.cards.status.html:find('WAIT',1,true),'string zero rendered ready')
local function bounds()
 for k,o in pairs(other.cards) do if not o.hidden then
  assert(o.p.x>=0 and o.p.x+o.p.width<=first.p.width,k..' horizontal overflow')
  assert(o.p.y>=0 and o.p.y+o.p.height<=first.p.height,k..' vertical overflow')
 end end
 for k,o in pairs(other.buttons) do
  assert(o.p.x>=0 and o.p.x+o.p.width<=first.p.width,k..' button overflow')
  assert(o.p.y>=0 and o.p.y+o.p.height<=first.p.height,k..' button vertical overflow')
 end
end
bounds()
assert(other.cards.player_afflictions.p.height>=280 and other.cards.enemy_afflictions.p.height>=280,'affliction panels too small at 1080p')
assert(other.cards.player_afflictions.p.x+other.cards.player_afflictions.p.width<other.cards.enemy_afflictions.p.x,'panels overlap')
assert(border==650,'main console border not resized')
assert(other.cards.player_afflictions.html:find('none observed',1,true),'missing explicit empty state')
for i=1,40 do state.player.afflictions[string.format('aff_%02d',i)]=true;state.target.afflictions[string.format('enemy_%02d',i)]=true end
other.refresh(state,combat_v2.runner,combat_v2.cure)
assert(other.cards.player_afflictions.html:find('[40]',1,true),'player count wrong')
assert(other.cards.enemy_afflictions.html:find('[40]',1,true),'enemy count wrong')
local pages=math.ceil(40/combat_v2_ui.per_page)
for i=1,pages-1 do other.buttons.player_afflictions_next.click() end
assert(other.cards.player_afflictions.html:find('aff 40',1,true),'last player affliction unreachable')
assert(combat_v2_ui.pages.enemy_afflictions==1,'player paging moved enemy page')
for i=1,pages-1 do other.buttons.enemy_afflictions_next.click() end
assert(other.cards.enemy_afflictions.html:find('enemy 40',1,true),'last enemy affliction unreachable')
state.player.afflictions={};other.refresh(state,combat_v2.runner,combat_v2.cure)
assert(combat_v2_ui.pages.player_afflictions==1,'page not clamped after cure')
for _,size in ipairs({{1280,720},{1600,900},{1920,945}}) do screenw,screenh=size[1],size[2];other.layout();other.refresh(state,combat_v2.runner,combat_v2.cure);bounds() end
print('PASS GUI: reusable root, escaping, flags, separate large affliction panels, counts, independent paging, cure page clamp, responsive bounds at three resolutions; widgets='..created)
