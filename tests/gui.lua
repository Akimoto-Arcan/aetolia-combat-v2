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
state.player.class='Monk';state.player.balance='0';state.target.name='<test>';state.connected=true;state.player.stance='scorpion';state.player.kai=12
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
state.player.afflictions={blindness=true,deafness=true};state.target.afflictions={blindness=true,deafness=true}
other.refresh(state,combat_v2.runner,combat_v2.cure)
assert(other.cards.player_afflictions.html:find('[2]',1,true)and other.cards.player_afflictions.html:find('blindness',1,true)and other.cards.player_afflictions.html:find('deafness',1,true),'curable sensory afflictions missing from self display/count')
assert(other.cards.enemy_afflictions.html:find('[2]',1,true)and other.cards.enemy_afflictions.html:find('blindness',1,true)and other.cards.enemy_afflictions.html:find('deafness',1,true),'enemy sensory tracking was hidden')
assert(state.player.afflictions.blindness and state.player.afflictions.deafness,'render mutated authoritative afflictions')
-- Both raw sensory entries participate in page count and reused callbacks.
local saved_per_page=combat_v2_ui.per_page;combat_v2_ui.per_page=1
combat_v2_ui.pages.player_afflictions=9;other.refresh(state,combat_v2.runner,combat_v2.cure)
assert(other.cards.player_afflictions.html:find('[2]',1,true)and combat_v2_ui.pages.player_afflictions==2,'sensory paging/count wrong')
other.create();combat_v2_ui.per_page=1
other.buttons.player_afflictions_next.click();assert(combat_v2_ui.pages.player_afflictions==1,'reused callback omitted sensory page')
assert(other.cards.player_afflictions.html:find('blindness',1,true),'blindness page hidden')
other.buttons.player_afflictions_next.click();assert(combat_v2_ui.pages.player_afflictions==2 and other.cards.player_afflictions.html:find('deafness',1,true),'deafness page hidden')
combat_v2_ui.per_page=saved_per_page
state.player.afflictions={};state.target.afflictions={};other.refresh(state,combat_v2.runner,combat_v2.cure)

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

-- Defense popup: pure B.rows view, fixed slots and explicit scoped dispatch.
local ok,why=rebuilt.show_defenses();assert(ok==false and why:find('core unavailable',1,true))
local entries={
 {key='toughness',label='<Toughness>',active=false,wanted=true,owner='MONK',control='class'},
 {key='cloak',label='Cloak',active=true,wanted=false,owner='MONK',control='class',drain=true},
 {key='speed',label='Speed',active=false,wanted=true,owner='FIRSTAID',control='native',priority=3},
 {key='levitation',label='Levitation',wanted=false,owner='FIRSTAID',control='native',priority=26},
 {key='unknown',label='Unknown',owner='FIRSTAID',control='native'},
 {key='tattoo',label='<Tattoo>',active=true,owner='OBSERVED',control='observed'},
 {key='bad;send',label='Invalid',control='class'},
}
for i=7,47 do entries[#entries+1]={key='def_'..i,label='Defense '..i,active=i%2==0,wanted=false,owner='MONK',control='class'}end
local calls={};local initializations=0
combat_v2.buffs={rows=function(s)assert(s==state);return entries end,state=function()initializations=initializations+1;error('GUI initialized service')end}
state.buffs={master=false,have={cloak=true},wanted={}};combat_v2.buff_status='<paused>'
function combat_v2_buffs(action,rest)
 calls[#calls+1]={action,rest}
 if action=='keep' and (rest=='on' or rest=='off') then state.buffs.master=rest=='on'
 elseif action=='stop' then state.buffs.master=false
 elseif action=='keep' or action=='native' then
  local key,value=rest:match('^([%w_]+) (%a+)$')
  for _,e in ipairs(entries)do if e.key==key then e.wanted=value=='on';if action=='keep' and e.wanted then state.buffs.master=true end end end
 end
 return true
end
local raised={};function raiseWindow(name)raised[#raised+1]=name end
local mode_before=combat_v2.runner.mode;local pending={command='unchanged'};combat_v2.runner.pending=pending
local root_before=rebuilt.root;local walker_before=combat_v2_ui.walk_popup
assert(rebuilt.buttons.defenses.click());local manager=combat_v2_ui.defenses;local manager_count=created
assert(manager.window.p.autoDock==false and manager.window.p.docked==false and manager.window.p.restoreLayout==false)
assert(raised[#raised]=='Combat V2 Defenses' and #manager.rows==14)
local function contains(o,s)assert(o.html:find(s,1,true),'missing '..s)end
contains(manager.header,'MASTER OFF');contains(manager.header,'&lt;paused&gt;')
contains(manager.rows[1].info,'&lt;Toughness&gt;');contains(manager.rows[1].info,'MISSING');contains(manager.rows[1].info,'#ee8897');contains(manager.rows[1].toggle,'WANTED ON')
contains(manager.rows[2].info,'ACTIVE');contains(manager.rows[2].info,'#76d39b');contains(manager.rows[2].info,'DRAIN: resources');contains(manager.rows[2].toggle,'WANTED OFF')
contains(manager.rows[3].info,'FIRSTAID · P3');contains(manager.rows[4].info,'P26 OFF');contains(manager.rows[4].info,'UNKNOWN');contains(manager.rows[4].info,'#e5c07b')
contains(manager.rows[5].info,'PRIORITY UNKNOWN');contains(manager.footer,'default P8');contains(manager.warning,'client skills only');contains(manager.warning,'NOT cancel active drains');contains(manager.footer,'defup audit')
assert(manager.rows[6].toggle.hidden and rebuilt.defense_slot(6)==false,'observed row actionable')
assert(manager.rows[5].toggle.click()==false and #calls==0,'unknown priority dispatched')
manager.buttons.refresh.click();manager.window:hide();rebuilt.refresh(state,combat_v2.runner,combat_v2.cure)
assert(manager.window.hidden,'refresh opened hidden manager')
assert(rebuilt.show_defenses() and created==manager_count and #calls==0 and initializations==0 and sends==0)
manager.rows[3].toggle.click();assert(calls[#calls][1]=='native' and calls[#calls][2]=='speed off' and not state.buffs.master)
manager.rows[4].toggle.click();assert(calls[#calls][1]=='native' and calls[#calls][2]=='levitation on' and not state.buffs.master)
assert(entries[4].active==nil,'native toggle fabricated active state')
-- Received observations update the view without requesting anything.
local before_event=#calls;entries[3].active=true;entries[4].active=false;rebuilt.refresh_defenses(state)
contains(manager.rows[3].info,'ACTIVE');contains(manager.rows[4].info,'MISSING');assert(#calls==before_event)
for _,priority in ipairs({0,27,1.5})do
 entries[5].priority=priority;assert(manager.rows[5].toggle.click()==false and #calls==before_event,'invalid native priority dispatched')
end
entries[5].priority=nil
manager.rows[2].toggle.click();assert(calls[#calls][1]=='keep' and calls[#calls][2]=='cloak on' and state.buffs.master)
manager.rows[2].toggle.click();assert(calls[#calls][2]=='cloak off' and entries[2].active==true)
manager.buttons.defup.click();assert(calls[#calls][1]=='start')
manager.buttons.keep_on.click();assert(calls[#calls][1]=='keep' and calls[#calls][2]=='on')
manager.buttons.keep_off.click();assert(calls[#calls][2]=='off' and entries[4].wanted and entries[2].active)
manager.buttons.stop.click();assert(calls[#calls][1]=='stop')
local dispatched=#calls
for _,input in ipairs({'unknown on','cloak on;send','bad;send on','cloak ON','speed on'})do assert(rebuilt.defense_action('keep',input)==false)end
assert(rebuilt.defense_action('native','cloak on')==false and rebuilt.defense_action('native','on')==false)
assert(rebuilt.defense_action('reset','')==false and rebuilt.defense_action('audit','')==false)
manager.buttons.next.click();assert(manager.page==2 and manager.rows[1].key=='def_15')
manager.rows[1].toggle.click();assert(calls[#calls][2]=='def_15 on');dispatched=#calls
for i=1,10 do manager.buttons.next.click()end
assert(manager.page==4 and manager.rows[1].key=='def_43' and manager.rows[6].info.hidden and manager.rows[6].toggle.hidden)
assert(manager.rows[6].toggle.click()==false and #calls==dispatched)
manager.buttons.FIRSTAID.click();assert(manager.page==1 and manager.filter=='FIRSTAID' and manager.rows[1].key=='speed' and manager.rows[4].info.hidden)
manager.buttons.ACTIVE.click();for _,row in ipairs(manager.rows)do if not row.info.hidden then contains(row.info,'ACTIVE')end end
manager.buttons.CLIENT.click();for _,row in ipairs(manager.rows)do if not row.info.hidden then contains(row.info,'MONK')end end
manager.buttons.ALL.click();manager.page=2
assert(manager.rows[1].toggle.click()==false and #calls==dispatched,'stale page dispatched')
rebuilt.refresh_defenses(state)
local saved=entries;entries={saved[1]}
assert(manager.rows[1].toggle.click()==false and #calls==dispatched,'stale row dispatched')
rebuilt.refresh_defenses(state);assert(manager.page==1 and manager.rows[2].info.hidden and manager.rows[2].toggle.hidden)
entries={};manager.buttons.ACTIVE.click();contains(manager.page_label,'Page 1 / 1 · 0 rows');assert(manager.rows[1].info.hidden)
entries=saved;manager.buttons.ALL.click()
local control=entries[1].control;entries[1].control='observed'
assert(manager.rows[1].toggle.click()==false and #calls==dispatched,'changed control dispatched');entries[1].control=control
for i=48,2000 do entries[#entries+1]={key='def_'..i,label='<extra>',active=true,owner='OBSERVED',control='observed'}end
rebuilt.refresh_defenses(state);manager.buttons.next.click();assert(created==manager_count and #manager.rows==14,'catalog growth allocated widgets')
for _,row in ipairs(manager.rows)do
 assert(row.info.p.y>=194 and row.info.p.y+row.info.p.height<=manager.footer.p.y)
 assert(row.info.p.x+row.info.p.width<row.toggle.p.x and row.toggle.p.x+row.toggle.p.width<=860)
end
assert(manager.footer.p.y+manager.footer.p.height<=manager.window.p.height)
local reloaded=dofile(path..'gui.lua');combat_v2.gui=reloaded;reloaded.create();reloaded.show_defenses()
assert(created==manager_count and combat_v2_ui.defenses==manager,'reload leaked manager')
local callback=combat_v2_buffs;combat_v2_buffs=nil;assert(reloaded.defense_action('start')==false);combat_v2_buffs=callback
local core=combat_v2.buffs;combat_v2.buffs=nil;assert(reloaded.refresh_defenses(state)==false and reloaded.show_defenses()==false);combat_v2.buffs=core
assert(#calls==dispatched and initializations==0 and sends==0)
assert(combat_v2.runner.mode==mode_before and combat_v2.runner.pending==pending and reloaded.root==root_before and combat_v2_ui.walk_popup==walker_before)
local db=reloaded.buttons.defenses.p;local bb=reloaded.buttons.body_scan.p;local hb=reloaded.buttons.help.p
assert(db.width==90 and db.x+db.width<bb.x and bb.x+bb.width<hb.x)
-- Capability revocation between paint and click must not dispatch; metadata survives projection.
manager.buttons.ALL.click();entries[1].available=false;entries[1].availability='NOT LEARNED';entries[1].required=true
entries[1].requires_full=true;entries[1].cooldown_loss=180;entries[1].cooldown_activation=120;entries[1].off='verified off'
local safe_calls=#calls
assert(reloaded.defense_action('keep',entries[1].key..' on')==false and #calls==safe_calls,'unavailable direct callback dispatched')
reloaded.refresh_defenses(state);assert(manager.rows[1].toggle.hidden,'unavailable row showed fake ON')
contains(manager.rows[1].info,'NOT LEARNED');contains(manager.rows[1].info,'REQUIRED');contains(manager.rows[1].info,'full resources');contains(manager.rows[1].info,'loss cooldown');contains(manager.rows[1].info,'activation cooldown 120s');contains(manager.rows[1].info,'verified cancel')
assert(manager.rows[1].toggle.click()==false and #calls==safe_calls,'hidden stale capability dispatched')
entries[1].available=true;entries[1].availability='AVAILABLE';reloaded.refresh_defenses(state)
-- Current class (not guild) defines CLIENT; shared skills/tattoos stay visible.
local full_entries=entries;local class_before=state.player.class
entries={
 {key='archive_manual',owner='ARCHIVIST',control='class',can_toggle=false,available=true,availability='PREREQUISITES UNVALIDATED'},
 {key='nightsight',owner='SKILL',control='class',available=true},
 {key='cloak',owner='TATTOO',control='class',available=true},
 {key='daydream',owner='CURATIVE MANUAL',control='observed',tracking_only=true,availability='MANUAL ONLY'},
 {key='toughness',owner='MONK',control='class',available=false,active=true,availability='WRONG CLASS'},
 {key='speed',owner='FIRSTAID',control='native',priority=3},
}
state.player.class='Archivist';state.player.guild='Monks';manager.buttons.CLIENT.click()
assert(manager.rows[1].key=='archive_manual' and manager.rows[2].key=='nightsight' and manager.rows[3].key=='cloak' and manager.rows[4].key=='daydream' and manager.rows[5].info.hidden,'CLIENT omitted Archivist/shared/tattoo/manual or included foreign/native')
assert(manager.rows[1].toggle.hidden and manager.rows[4].toggle.hidden and not reloaded.defense_slot(1),'read-only manual row actionable')
assert(not reloaded.defense_action('keep','archive_manual on') and not reloaded.defense_action('keep','daydream on'),'manual direct callback dispatched')
entries[2].known=false
assert(not reloaded.defense_action('keep','nightsight on') and not reloaded.defense_slot(2),'known=false row actionable');entries[2].known=nil
manager.buttons.ACTIVE.click();assert(manager.rows[1].info.hidden,'foreign active row escaped ALL')
manager.buttons.ALL.click();for _,row in ipairs(manager.rows)do assert(row.key~='toughness','ALL exposed a foreign-class defense')end;assert(manager.rows[5].key=='speed','ALL lost native shared defense')
-- Same key/control at same slot is still stale across a class boundary.
local old_shared_click=manager.rows[2].toggle.click
state.player.class='Monk'
assert(not reloaded.defense_slot(2) and #calls==safe_calls,'class switch accepted old shared-row click')
reloaded.refresh_defenses(state)
assert(not old_shared_click() and #calls==safe_calls,'queued old-class click activated repainted shared row')
state.player.class='Archivist';manager.buttons.CLIENT.click()
-- Simulate the cached MONK button from the previously loaded paged manager.
local cached_button=manager.buttons.CLIENT;manager.buttons.MONK=cached_button;manager.buttons.CLIENT=nil;manager.filter='MONK'
cached_button:echo('MONK');cached_button:setClickCallback(function()error('stale MONK callback')end)
local popup_window=manager.window;local widget_count=created
reloaded=dofile(path..'gui.lua');combat_v2.gui=reloaded;reloaded.create();reloaded.refresh_defenses(state)
assert(manager.buttons.CLIENT==cached_button and manager.buttons.MONK==nil and manager.filter=='CLIENT' and manager.window==popup_window and created==widget_count,'paged MONK migration recreated widgets or lost popup')
contains(cached_button,'CLIENT');cached_button.click();assert(manager.filter=='CLIENT' and #calls==safe_calls,'cached filter callback not rebound')
entries=full_entries;state.player.class=class_before;manager.buttons.ALL.click()
-- Upgrade a previously open catalog-keyed manager without touching other UI.
local legacy={rows={old={info=obj({name='legacy_info'}),toggle=obj({name='legacy_toggle'})}},buttons={old=obj({name='legacy_button'})},window=obj({name='legacy_window'}),header=obj({name='legacy_header'})}
combat_v2_ui.defenses=legacy
reloaded.refresh_defenses(state);assert(reloaded.show_defenses())
assert(legacy.rows.old.info.deleted and legacy.rows.old.toggle.deleted and legacy.buttons.old.deleted and legacy.header.deleted and legacy.window.deleted,'legacy manager children leaked')
assert(combat_v2_ui.walk_popup==walker_before and reloaded.root==root_before and #calls==dispatched,'migration touched other UI or dispatched')
-- Final composed backend row projection: do not assume manual owners equal SKILL.
local actual=dofile(path..'buffs.lua');local archive_state=dofile(path..'state.lua').new()
archive_state.player.class='Archivist';actual.set_class(archive_state,'Archivist')
local saved_core=combat_v2.buffs;combat_v2.buffs=actual;combat_v2.current=archive_state
reloaded.defense_page(0,'CLIENT');local archive_manager=combat_v2_ui.defenses
local seen_rows={};local archives=0
repeat
 for slot,row in ipairs(archive_manager.rows)do if not row.info.hidden then
  seen_rows[row.key]=true
  if row.info.html:find('ARCHIVIST',1,true)then archives=archives+1;assert(row.toggle.hidden and not reloaded.defense_slot(slot),'actual Archivist manual row actionable')end
  if row.key=='daydream'then assert(row.toggle.hidden and not reloaded.defense_slot(slot),'actual Daydream manual row actionable')end
 end end
 local page=archive_manager.page;reloaded.defense_page(1)
 if archive_manager.page==page then break end
until false
assert(archives==14 and seen_rows.daydream and not seen_rows.blindness and not seen_rows.deafness and seen_rows.cloak and seen_rows.nightsight and seen_rows.clarity and not seen_rows.weathering and not seen_rows.speed,'actual CLIENT projection lost class/shared/manual rows or included sensory/foreign/native')
-- Even fresh legacy policy/stock proof cannot restore sensory defense controls.
local sensory_clock=500;function getEpoch()return sensory_clock end
local ap=archive_state.player;ap.balance=true;ap.equilibrium=true;ap.left_arm_balance=true;ap.right_arm_balance=true
actual.vitals(archive_state,{herb='1',blind='0',deaf='0'})
assert(actual.set_sensory_context(archive_state,{class='archivist',epoch=archive_state.buffs.sensory_epoch or 0,observed_at=500,herb='1',priorities={blindness=26,deafness=26},stocks={amaurosis=10,ototoxin=10},eating_allowed=true,curing_clear=true,barriers_clear=true}))
reloaded.defense_page(0,'CLIENT')
archive_state.buffs.wanted.blindness=true;archive_state.buffs.wanted.deafness=true
archive_state.buffs.sensory_optin={blindness=true,deafness=true}
local call_count=#calls
repeat
 for _,row in ipairs(archive_manager.rows)do if not row.info.hidden then assert(row.key~='blindness' and row.key~='deafness','retired sensory defense visible')end end
 local page=archive_manager.page;reloaded.defense_page(1);if page==archive_manager.page then break end
until false
assert(not reloaded.defense_action('keep','blindness on') and not reloaded.defense_action('keep','deafness on') and #calls==call_count,'retired sensory GUI producer dispatched')
sensory_clock=506
reloaded.refresh_defenses(archive_state)
assert(not reloaded.defense_action('keep','daydream on') and #calls==dispatched and sends==0,'actual manual row dispatched')
assert(archive_state.buffs.wanted.blindness==false and archive_state.buffs.wanted.deafness==false and not next(archive_state.buffs.sensory_optin),'GUI refresh retained obsolete saved intent')
archive_state.buffs.wanted.mindseye=true;archive_state.buffs.tattoos.mindseye=nil
assert(reloaded.defense_action('keep','mindseye off'),'missing ink prevented deselection')
archive_state.buffs.wanted.toughness=true
local foreign_calls=#calls
assert(not reloaded.defense_action('keep','toughness off')and #calls==foreign_calls,'foreign Monk OFF escaped class fence')
combat_v2.current=state;combat_v2.buffs=saved_core
print('PASS GUI defenses: 14 reusable slots, 2000 rows, paging/filter/clamp, native/class dispatch, unknown-priority/stale-slot rejection, read-only rows, escaped/color states, no sends, unchanged executor/UI, legacy migration')

print('PASS GUI: reusable root, escaping, flags, separate large affliction panels, counts, independent paging, cure page clamp, responsive bounds at three resolutions; widgets='..created)
