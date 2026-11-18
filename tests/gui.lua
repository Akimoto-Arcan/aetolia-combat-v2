local created=0
local function obj(p,parent)
 created=created+1
 local o={p=p,parent=parent,name=p.name}
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


state.last_event='H:3475 (82%) M:2934 (100%)';state.recent_events={{time=100,text='<injury> observed'},{time=99,text='A cure was confirmed.'},{time=98,text='An enemy was slain.'},{time=97,text='older invisible event'}}
rebuilt.refresh(state,combat_v2.runner,combat_v2.cure)
local feed=rebuilt.cards.events.html
assert(feed:find('RECENT EVENTS',1,true) and feed:find('&lt;injury&gt;',1,true),'recent event rendering/escaping failed')
assert(feed:find('%d%d:%d%d:%d%d') and feed:find('A cure was confirmed.',1,true),'event timestamps/history missing')
assert(not feed:find('H:3475',1,true) and not feed:find('older invisible event',1,true),'prompt or old event replaced recent history')

-- Defense popup: pure rendering, authoritative observations, explicit dispatch only.
local ok,why=rebuilt.show_defenses();assert(ok==false and why:find('core unavailable',1,true),'missing core did not fail gracefully')
local calls={};local initializations=0
combat_v2.buffs={catalog={
 {key='toughness',label='<Toughness>',command='toughness',default=true},
 {key='vitality',label='Vitality',command='vitality',default=true,requires_full=true,cooldown_loss=true},
 {key='cloak',label='Cloak',command='cloak',off='uncloak',default=false,drain='mana'},
 {key='bad;send',label='Invalid',command='no'},
},state=function()initializations=initializations+1;error('GUI initialized service')end}
state.buffs={master=false,sequence=false,wanted={toughness=true,cloak=false},have={cloak=true},defs_known=true}
state.player.defences={toughness=true};combat_v2.buff_status='<paused>'
function combat_v2_buffs(action,rest)
 calls[#calls+1]={action,rest}
 if action=='keep' then
  if rest=='on' or rest=='off' then state.buffs.master=rest=='on'
  else local key,value=rest:match('^([%w_]+) (%a+)$');state.buffs.wanted[key]=value=='on';if value=='on' then state.buffs.master=true end end
 elseif action=='stop' then state.buffs.master=false;state.buffs.sequence=false end
 return true
end
local raised={};function raiseWindow(name)raised[#raised+1]=name end
local mode_before=combat_v2.runner.mode;local pending={command='unchanged'};combat_v2.runner.pending=pending
local root_before=rebuilt.root;local walker_before=combat_v2_ui.walk_popup
assert(rebuilt.buttons.defenses.click(),'DEFENSES did not open')
local manager=combat_v2_ui.defenses;local manager_count=created
assert(manager.window.p.autoDock==false and manager.window.p.docked==false and manager.window.p.restoreLayout==false,'defenses not native floating')
assert(raised[#raised]=='Combat V2 Defenses','defenses not raised after show')
assert(manager.header.html:find('MASTER OFF',1,true) and manager.header.html:find('&lt;paused&gt;',1,true),'master/service status missing or unescaped')
assert(manager.rows.toughness.info.html:find('MISSING',1,true) and manager.rows.toughness.toggle.html:find('WANTED ON',1,true),'wanted/native list incorrectly treated as active')
assert(manager.rows.cloak.info.html:find('ACTIVE',1,true) and manager.rows.cloak.toggle.html:find('WANTED OFF',1,true),'active state conflated with wanted')
assert(manager.rows.toughness.info.html:find('&lt;Toughness&gt;',1,true),'defense label not escaped')
assert(manager.rows.cloak.info.html:find('DRAIN: mana',1,true) and manager.rows.cloak.info.html:find('verified cancel',1,true),'drain/cancel warning missing')
assert(manager.rows.toughness.info.html:find('upkeep only',1,true) and manager.warning.html:find('ON arms upkeep',1,true) and manager.warning.html:find('NOT cancel active drains',1,true),'arming/pause warnings missing')
assert(not manager.rows['bad;send'],'invalid catalog key rendered')
manager.buttons.refresh.click();manager.window:hide();rebuilt.refresh(state,combat_v2.runner,combat_v2.cure)
assert(manager.window.hidden,'refresh opened a hidden manager')
assert(rebuilt.show_defenses() and created==manager_count and not manager.window.hidden,'reopen duplicated defense widgets')
assert(#calls==0 and initializations==0 and sends==0,'opening/refreshing dispatched or mutated service')
state.buffs.defs_known=false;rebuilt.refresh_defenses(state)
assert(manager.rows.cloak.info.html:find('UNKNOWN',1,true),'stale defense snapshot claimed ACTIVE')
state.buffs.defs_known=true
manager.rows.cloak.toggle.click();assert(calls[#calls][1]=='keep' and calls[#calls][2]=='cloak on' and state.buffs.master,'row ON not explicit upkeep arm')
assert(manager.header.html:find('MASTER ON',1,true),'master ON not refreshed')
manager.rows.cloak.toggle.click();assert(calls[#calls][2]=='cloak off','row OFF wrong selector')
manager.rows.toughness.toggle.click();assert(calls[#calls][2]=='toughness off','safe-defense OFF wrong selector')
manager.buttons.defup.click();assert(calls[#calls][1]=='start','DEFUP did not route one-shot')
manager.buttons.keep_on.click();assert(calls[#calls][1]=='keep' and calls[#calls][2]=='on','global ON incorrect')
manager.buttons.keep_off.click();assert(calls[#calls][1]=='keep' and calls[#calls][2]=='off' and state.buffs.have.cloak==true,'global pause cancelled active defense')
manager.buttons.stop.click();assert(calls[#calls][1]=='stop','STOP did not disarm service')
local dispatched=#calls
for _,input in ipairs({'unknown on','cloak on;send','bad;send on','cloak ON'})do assert(rebuilt.defense_action('keep',input)==false,'invalid selector accepted')end
assert(rebuilt.defense_action('reset','')==false and rebuilt.defense_action('audit','')==false,'GUI allowed reset/audit dispatch')
local old_catalog=combat_v2.buffs.catalog;combat_v2.buffs.catalog={old_catalog[1],old_catalog[2]}
rebuilt.refresh_defenses(state);assert(manager.rows.cloak.info.hidden and manager.rows.cloak.toggle.hidden,'removed defense remained visible')
manager.rows.cloak.toggle.click();assert(#calls==dispatched,'stale selector dispatched removed key')
combat_v2.buffs.catalog=old_catalog
local reloaded=dofile(path..'gui.lua');combat_v2.gui=reloaded;reloaded.create();reloaded.show_defenses()
assert(created==manager_count and combat_v2_ui.defenses==manager,'GUI reload leaked manager widgets')
local public_callback=combat_v2_buffs;combat_v2_buffs=nil;assert(reloaded.defense_action('start')==false,'missing public callback not guarded');combat_v2_buffs=public_callback
local core=combat_v2.buffs;combat_v2.buffs=nil;assert(reloaded.refresh_defenses(state)==false and reloaded.show_defenses()==false,'lost core not guarded');combat_v2.buffs=core
assert(#calls==dispatched and sends==0 and initializations==0,'invalid selection/render unexpectedly executed')
assert(combat_v2.runner.mode==mode_before and combat_v2.runner.pending==pending and reloaded.root==root_before and combat_v2_ui.walk_popup==walker_before,'defenses changed mode, executor or existing UI')
local db=reloaded.buttons.defenses.p;local bb=reloaded.buttons.body_scan.p;local hb=reloaded.buttons.help.p
assert(db.width==90 and db.x+db.width<bb.x and bb.x+bb.width<hb.x,'header defense button overlap')
-- A complete fourteen-row catalog remains ordered and inside its native content.
local full={};for i=1,14 do full[i]={key='def_'..i,label='Defense '..i,command='fixture',default=i<=8,drain=i>8 and 'mana' or nil}end
combat_v2.buffs.catalog=full;reloaded.refresh_defenses(state)
for i,entry in ipairs(full)do
 local row=manager.rows[entry.key];assert(row.info.p.y==170+(i-1)*34,'catalog order lost')
 assert(row.info.p.x+row.info.p.width<row.toggle.p.x and row.toggle.p.x+row.toggle.p.width<=860,'defense row overlap/overflow')
 assert(row.info.p.y+row.info.p.height<=manager.footer.p.y,'defense row overlaps footer')
end
assert(manager.footer.p.y+manager.footer.p.height<=manager.window.p.height,'defense footer overflow')
manager.rows.def_14.toggle.click();assert(calls[#calls][2]=='def_14 on','row closure did not retain validated key')
manager.rows.def_1.toggle.click();assert(calls[#calls][2]=='def_1 on','row callback captured wrong key')
assert(state.buffs.wanted.def_9==nil,'render auto-selected a drain')
local full_count=created;manager.window:hide();reloaded.show_defenses();assert(created==full_count and raised[#raised]=='Combat V2 Defenses','full manager reopen leaked or failed to raise')
assert(combat_v2.runner.mode==mode_before and sends==0,'catalog refresh changed execution')
print('PASS GUI defenses: pure open/refresh, native singleton/reload/raise, authoritative ACTIVE/MISSING/UNKNOWN vs wanted, master/drain warnings, validated per-row/global callbacks, stale-key rejection, fourteen-row bounds, unchanged executor/layout')

print('PASS GUI: reusable root, escaping, flags, separate large affliction panels, counts, independent paging, cure page clamp, responsive bounds at three resolutions; widgets='..created)
