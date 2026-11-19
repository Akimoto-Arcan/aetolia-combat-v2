-- TEST ONLY: reconstruct the retired catalog in memory to exercise the retained
-- acknowledgement/resource/barrier algorithm. Never installed or loaded live.
-- Production has no switch to enable this catalog or its self-affliction routes.
return function(path)
 local file=assert(io.open(path,'r'));local source=file:read('*a');file:close()
 local function insert(anchor,text)
  local a,b=source:find(anchor,1,true);assert(a,'legacy fixture anchor missing: '..anchor)
  source=source:sub(1,a-1)..text..source:sub(a)
 end
 insert('local passive_tattoos=',[[
for _,k in ipairs({'blindness','deafness'}) do
 M.catalog[#M.catalog+1]={key=k,label=k=='blindness' and 'Blindness (intentional)' or 'Deafness (intentional)',class='shared',group='curatives',curative=true,self_afflicted=true,default=false,command='eat '..sensory[k],prepare='outc '..sensory[k]}
end
]])
 insert('metadata.mountain=',[[
for _,k in ipairs({'blindness','deafness'}) do
 metadata[k]={key=k,self_afflicted=true,reason='Legacy fixture only'}
 general_order[#general_order+1]=k
end
]])
 insert("aliases.blind='blindness'",[[
for _,k in ipairs({'blindness','deafness'}) do
 M.curative_catalog[#M.curative_catalog+1]={key=k,kind='intentional_affliction',source='Herbalism',producer=sensory[k],delivery='consumed',class='shared',owner='CURATIVE'}
end
]])
 return assert((loadstring or load)(source,'@legacy-sensory-fixture'))()
end
