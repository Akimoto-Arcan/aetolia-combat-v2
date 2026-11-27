-- Offline regression for the live Known-header/AB-body dispatch overlap.
getEpoch=function()return 100 end
local M=dofile(arg[1]or'combat_v2/earthcaller.lua')
local pending={id='previous-issued',unknown='retained original uncertainty'}
local s={connected=true,mode='BASH',target_generation=1,room={id=1,items={['456']={name='a test denizen'}}},
 player={class='Earthcaller',hp=100,dead=false},
 target={name='456',earth_evidence={source='offline-fixture',generation=1,room=1,at=100,protected=false,loyal=false,eligible=true,kind='npc',player=false}},
 earthcaller={epoch=1,status={class='earthcaller',session='offline-fixture',epoch=1},
 skills={subjugation={epoch=1,known={quash=true}}},physical=pending,native={documentation=true},
 equipment={epoch=1,at=100,wielded=true,calcified=true,bound_to_self=true,shield_wielded=true}}}
local held=M.choose(s)
assert(held.command=='' and held.reason=='native documentation frame still open','AB body must defer new actions after its Known header')
assert(s.earthcaller.physical==pending and pending.unknown=='retained original uncertainty','documentation gate must not erase issued work')
s.earthcaller.native.documentation=nil
local ready=M.choose(s)
assert(ready.command=='QUASH 456','ordinary admission resumes once the real prompt has closed documentation')
print('PASS: documentation defers new actions, retains issued uncertainty, and resumes ordinary admission after frame closure')
