-- The native transaction owns the original case, warning and journal.
-- This required module supplies no command or source authority.
return {
  accepted = function(e, w, d)
    return {data = d, commands = {}}
  end
}
