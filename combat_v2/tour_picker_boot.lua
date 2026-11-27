-- Cold persistence adapter; attachment is inert until a numeric command.
local B={}
function B.detach(c)
 local p=c.tour_picker
 if not p then return true end
 if p.query and not p.query.closed then return false,'picker AREAS stream unresolved' end
 p.cancel()
 if combat_v2_tour==p.command then combat_v2_tour=p.original end
 if p.module and p.module.plan==p.plan then p.module.plan=p.original_plan end
 if p.widget then p.widget:hide()end
 c.tour_picker_ui={widget=p.widget,widgets=p.widgets,labels=p.labels,visual_background=p.visual_background,visual_summary=p.visual_summary,visual_close=p.visual_close}
 c.tour_picker=nil
 return true
end
function B.attach(c)
 local prior=c.tour_picker
 if prior and prior.tour==c.tour and prior.attachment==c.tour_attachment then
  assert(combat_v2_tour==prior.command and prior.module.plan==prior.plan,'picker ownership drift')
  return true,prior
 end
 if prior then assert(B.detach(c))end
 local root=getMudletHomeDir()..'/combat_v2/'
 local file=assert(io.open(root..'tour_picker.lua','r'));local source=file:read('*a');file:close()
 local compile=loadstring or load
 local factory=assert(compile(source,'@combat-v2-tour-picker'))()
 local M=assert(c.tour_module)
 local env={get_command=function()return combat_v2_tour end,Geyser=Geyser,
  observe=function(fn,pattern)return tempRegexTrigger(pattern or '^.*$',function()fn(line or '')end)end,
  after=tempTimer,kill_timer=killTimer,kill_trigger=killTrigger,
  report=function(why)print('TOUR: '..tostring(why))end}
 local p=factory.new(c,M,env);p.module=M
 for k,v in pairs(c.tour_picker_ui or {})do p[k]=v end
 if p.visual_close then p.visual_close:setClickCallback(function()p.cancel()end)end
 c.tour_picker=p;combat_v2_tour=p.command;M.plan=p.plan
 dofile(root..'tour_picker_visual.lua')(p)
 return true,p
end
return B
