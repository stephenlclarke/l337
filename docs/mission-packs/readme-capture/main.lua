local M = {}
function M.accepted(e,w,d)
  return {data={},commands={{op='milestone.ensure',index=0}}}
end
function M.undocked(e,w,d)
  return {data=d,commands={{op='encounter.ensure',id='opponents'}}}
end
function M.admitted(e,w,d)
  local commands={}
  for _,actor in ipairs({'lead','wing','port','upper'}) do
    commands[#commands+1]={op='actor.intent',id=actor..'-capture-attack',
      encounter='opponents',actor=actor,mode='attack',target='player',
      offset={0,0,0},speed=0,tolerance=1}
  end
  return {data=d,commands=commands}
end
return M
