local created=0
local function obj(p,parent)
 created=created+1
 local o={p=p,parent=parent}
 function o:setStyleSheet(s) self.css=s end
 function o:echo(s) self.html=s end
 function o:setBackgroundImage(path)self.image=path end
 function o:setClickCallback(f) self.click=f end
 function o:move(x,y) self.p.x=x;self.p.y=y end
 function o:resize(w,h) self.p.width=w;self.p.height=h end
 function o:hide()self.hidden=true end
 function o:show()self.hidden=false end
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
state.player.balance='0';state.target.name='<test>';state.connected=true;state.player.stance='scorpion';state.player.kai=12
combat_v2={current=state,runner={mode='OFF'},cure={enabled=false}}
local gui=dofile(path..'gui.lua');combat_v2.gui=gui
gui.create();gui.refresh(state,combat_v2.runner,combat_v2.cure)
local n=created;local first=gui.root
local other=dofile(path..'gui.lua');combat_v2.gui=other;other.create();other.refresh(state,combat_v2.runner,combat_v2.cure)
assert(created==n and other.root==first,'reload leaked widgets')
assert(other.cards.target.html:find('&lt;test&gt;',1,true),'target HTML not escaped')
assert(other.cards.status.html:find('WAIT',1,true),'string zero rendered ready')
state.defense={hold=true,phase='cure-lock + paralysis'};other.refresh(state,combat_v2.runner,combat_v2.cure);assert(other.cards.cure.html:find('cure-lock + paralysis',1,true),'survival phase missing');state.defense=nil

assert(other.cards.status.html:find('STANCE: SCORPION',1,true),'observed stance not visible in sidebar')
local stance,stanced=other.stance(state);assert(stance=='SCORPION' and stanced==true,'confirmed stance presentation failed')
local text=other.prompt_text(state,combat_v2.runner)
assert(text:find('SCORPION',1,true) and text:find('Kai: <white>12',1,true),'subprompt missing stance/Kai')
assert(text:find('B:<yellow>WAIT',1,true),'subprompt treated string zero as ready')
state.player.prone='0';state.player.mounted='0';assert(other.prompt_text(state,combat_v2.runner):find('STANDING',1,true),'zero prone rendered fallen')
state.player.prone='1';state.player.mounted='1';text=other.prompt_text(state,combat_v2.runner);assert(text:find('PRONE',1,true) and text:find('MOUNTED',1,true),'subprompt missing posture/mount')
state.player.stance='none';stance,stanced=other.stance(state);assert(stance=='NOT STANCED' and stanced==false,'no-stance state rendered ready')
assert(other.prompt_text(state,combat_v2.runner):find('<red>NOT STANCED',1,true),'no-stance warning not red')
state.player.stance=nil;stance,stanced=other.stance(state);assert(stance=='UNKNOWN' and stanced==nil,'missing observation claimed not-stanced')
state.player.stance='<red>injected';assert(other.stance(state)=='UNKNOWN','stance accepted formatting injection')
state.player.stance='scs';assert(other.stance(state)=='SCORPION','confirmed abbreviation not expanded')
state.connected=false;assert(other.stance(state)=='UNKNOWN (offline)','offline state showed stale stance as confirmed');state.connected=true
local output={};function cecho(value)output[#output+1]=value end
other.render_prompt(state,combat_v2.runner);assert(#output==1 and output[1]:find('SCORPION',1,true),'subprompt renderer failed')
state.player.dead=true;assert(other.stance(state)=='NOT STANCED (dead)','dead player displayed stanced');state.player.dead=false
state.player.stance='scorpion';state.player.prone=false;state.player.mounted=false

local selected,removed=false,nil
function selectCurrentLine()selected=true end
function replace(value)assert(selected,'replacement before prompt selection');removed=value end
output={};other.render_prompt(state,combat_v2.runner)
assert(selected and removed=='' and #output==1,'original game prompt was not replaced exactly once')
assert(output[1]:find('HP:',1,true) and output[1]:find('MP:',1,true),'replacement lost health or mana')
local vitals=other.vitals_text(state,{Char={Vitals={ep=50,maxep=100,wp=20,maxwp=100,xp=25,maxxp=100}}})
assert(vitals:find('End:',1,true) and vitals:find('Will:',1,true) and vitals:find('25.00%',1,true),'extended prompt resources missing')
state.player.hp=20;state.player.maxhp=100;assert(other.vitals_text(state):find('<red>20 (20%)',1,true),'low health lacks warning')
local opened,shown,cleared,scrolled=0,0,0,0;local help_output
function scrollTo(name,n)assert(name=="Combat V2 Help" and n==0);scrolled=scrolled+1 end
function openUserWindow(name)assert(name=='Combat V2 Help');opened=opened+1 end
function resizeWindow(name,w,h)assert(w>=800 and h>=600)end
function clearWindow()cleared=cleared+1 end
function showWindow()shown=shown+1 end
function cecho(name,text)help_output=text or name end
local prior_mode=combat_v2.runner.mode
assert(other.show_help() and other.show_help(),'help window did not open/reopen')
assert(opened==1 and shown==2 and cleared==2 and scrolled==2,'help duplicated the user window or did not open at the top')
assert(help_output:find('GET STARTED',1,true) and help_output:find('cv2 area yes / no',1,true) and help_output:find('DIAGNOSTICS',1,true),'grouped command guide incomplete')
other.buttons.help.click();assert(shown==3 and combat_v2.runner.mode==prior_mode,'HELP button changed mode or failed')
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

local reset_clicks=0;function combat_v2_reset_enemy_afflictions()reset_clicks=reset_clicks+1;state.target.afflictions={};combat_v2_ui.pages.enemy_afflictions=1;other.refresh(state,combat_v2.runner,combat_v2.cure);return true end
other.buttons.enemy_afflictions_reset.click();assert(reset_clicks==1 and other.cards.enemy_afflictions.html:find('[0]',1,true),'enemy RESET callback failed')
local er=other.buttons.enemy_afflictions_reset.p;local prev=other.buttons.enemy_afflictions_prev.p;local nxt=other.buttons.enemy_afflictions_next.p
assert(er.x>=prev.x+prev.width and er.x+er.width<=nxt.x,'enemy RESET overlaps paging')

-- Paired limb cards and the read-only native body scanner.
assert(other.cards.limbs.p.x+other.cards.limbs.p.width<other.cards.self_limbs.p.x,'self limbs not to the right of enemy limbs')
assert(other.cards.self_limbs.html:find('YOUR LIMBS',1,true),'missing self limb panel')
local d=other.limb_snapshot(state,'self','left_arm');assert(d.value==nil and d.percent=='—','unknown self trauma was invented from arm balance')
state.player.afflictions.left_arm_broken=true;d=other.limb_snapshot(state,'self','left_arm');assert(d.marker=='BROKEN' and d.color=='broken' and d.value==nil,'own injury did not render independently of percentages')
state.target.limbs.right_leg=41;state.target.evidence['limb:right_leg']={confidence=.65};state.target.mangled.head=true
assert(other.limb_snapshot(state,'enemy','right_leg').percent=='~41.0%','enemy estimate lost uncertainty')
Geyser.UserWindow={new=function(_,p)return obj(p)end};function getMudletHomeDir()return '/fixture' end
local sends=0;function send()sends=sends+1;error('GUI must not send')end
local before_mode=combat_v2.runner.mode;other.buttons.body_scan.click();local body=combat_v2_ui.body
assert(body and body.window and body.sides.self.layers.left_arm.image:find('left_arm_broken.png',1,true),'scanner did not use own injured-arm art')
assert(body.sides.enemy.layers.head.image:find('head_mangled.png',1,true),'scanner did not use confirmed enemy-head injury')
assert(body.sides.self.rows.left_arm.html:find('BROKEN',1,true),'scanner readout missing own injury')
local scanner_widgets=created;body.close.click();assert(body.window.hidden,'scanner Close did not hide')
other.show_body();assert(created==scanner_widgets and not body.window.hidden,'scanner reopen duplicated widgets')
state.player.afflictions.left_arm_broken=nil;state.target.mangled.head=nil;other.refresh(state,combat_v2.runner,combat_v2.cure)
assert(body.sides.self.layers.left_arm.image:find('left_arm_clear.png',1,true),'own cure did not update scanner')
assert(body.sides.enemy.layers.head.image:find('head_unknown.png',1,true),'enemy reset left stale injury art')
assert(sends==0 and combat_v2.runner.mode==before_mode,'body scanner changed execution')
local rebuilt=dofile(path..'gui.lua');combat_v2.gui=rebuilt;rebuilt.create();rebuilt.refresh(state,combat_v2.runner,combat_v2.cure);rebuilt.show_body();assert(created==scanner_widgets,'GUI reload leaked scanner objects')

print('PASS GUI: reusable root, escaping, flags, separate large affliction panels, counts, independent paging, cure page clamp, responsive bounds at three resolutions; widgets='..created)
