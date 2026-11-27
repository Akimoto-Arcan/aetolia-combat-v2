-- Disconnected exact-friend-line tests. No game connection or real sends.
local M=dofile(assert(arg[1])..'/minigames.lua');local n=0
local function check(x,msg)assert(x,msg);n=n+1 end
local function fresh()
 local c={mode='OFF',current={mode='OFF',connected=true,player={dead=false}},runner={}}
 local sent={};local o=M.new(c,{send=function(cmd)sent[#sent+1]=cmd end});return o,c,sent
end
local prompts={
 {'It is now your turn. Do you wish to check, raise, fold or allin?','poker check'},
 {'It is now your turn. Do you wish to call, raise, fold or allin?','poker call'},
 {'It is now your turn. Do you wish to check, fold, allin or bet?','poker check'},
 {'It is your turn to open. Do you wish to call, raise, fold or allin?','poker call'},
 {'It is now your turn! Please FARKLE ROLL to continue.','farkle done'},
 {'Friend has initiated a game of Farkle! You can PLAY FARKLE within the next thirty seconds to join.','PLAY FARKLE'},
}
local o,c,s=fresh();for _,p in ipairs(prompts)do o.line(p[1])end;o.line('Friend takes a seat at the poker table.');check(#s==0,'default OFF no commands or buy-in')
check(o.command('games','on'),'explicit opt-in');for _,p in ipairs(prompts)do local before=#s;check(o.line(p[1]),'literal recognized');check(#s==before+1 and s[#s]==p[2],'friend command preserved exactly')end
for _,p in ipairs(prompts)do local before=#s;o.line('prefix '..p[1]);o.line(p[1]..' extra');check(#s==before,'not a substring trigger')end
local before=#s;check(o.line('Friend takes a seat at the poker table.'),'first seat');check(s[#s]=='poker buyin for 200'and o.playing,'exact buy-in 200')
o.line('Other takes a seat at the poker table.');check(#s==before+1,'no repeated buy-in')
o.command('poker','off');o.line('You take your remaining 199 gold and leave the poker table.');check(not o.playing,'leave tracked while disabled');o.command('poker','on');o.line('Another takes a seat at the poker table.');check(#s==before+2,'new buy-in only after leaving')
for _,text in ipairs({'Two Words takes a seat at the poker table.','Friend takes a seat at the poker table','You take your remaining gold and leave the poker table.'})do before=#s;o.line(text);check(#s==before,'anchored regex behavior')end
o,c,s=fresh();o.command('poker','on');o.line(prompts[1][1]);o.line(prompts[5][1]);check(#s==1,'poker-only toggle');o.command('poker','off');o.command('farkle','on');o.line(prompts[1][1]);o.line(prompts[5][1]);check(#s==2 and s[2]=='farkle done','farkle-only toggle')
o.stop();o.line(prompts[5][1]);check(#s==2 and not o.poker and not o.farkle,'global STOP disarms both')
o,c,s=fresh();o.command('games','on');o.playing=true;o.disconnect();check(not o.poker and not o.farkle and not o.playing,'disconnect reset and opt-in required')
o,c,s=fresh();o.command('games','on');c.mode='BASH';o.line(prompts[1][1]);check(#s==0,'combat paused');c.mode='PVP';o.line(prompts[5][1]);check(#s==0,'PvP paused');c.mode='OFF';c.current.connected=false;o.line(prompts[1][1]);check(#s==0,'disconnected paused');c.current.connected=true;c.current.player.dead=true;o.line(prompts[1][1]);check(#s==0,'dead paused')
for _,flag in ipairs({'waiting','dispatching','transport_commit','transport_unknown','transport_barrier'})do o,c,s=fresh();o.command('games','on');c.runner[flag]=true;o.line(prompts[1][1]);check(#s==0,'issued runner '..flag)end
for _,owner in ipairs({'buffs','mental','walker','earthcaller','class_observations'})do
 o,c,s=fresh();o.command('games','on');local field=owner=='earthcaller'and'physical'or owner=='class_observations'and'issued'or'pending';c.current[owner]={[field]={}};o.line(prompts[1][1]);check(#s==0,'owner barrier '..owner)
end
o,c,s=fresh();o.command('games','on');c.travel_owner={phase='FIND'};o.line(prompts[1][1]);check(#s==0,'travel phase pause')
o,c,s=fresh();o.command('games','on');o.line('Name_2 takes a seat at the poker table.');check(s[1]=='poker buyin for 200','underscore word regex retained')
local previous=o;previous.stop('reload');o=M.new(c,{send=function()error('unexpected')end},previous.playing);check(not o.poker and not o.farkle and o.playing,'reload OFF preserves table bookkeeping')
o,c,s=fresh();check(not o.command('games','on;look'),'invalid toggle not sent');check(not o.command('other','on'),'invalid command scope');check(#s==0,'configuration never sends')
o=M.new(c,{send=function()error('transport failure')end});o.command('games','on');check(not o.line('Friend takes a seat at the poker table.')and not o.poker and not o.farkle and o.playing,'failed buy-in no blind retry; requested state retained')
print('PASS minigames '..n..' assertions ('.._VERSION..')')
