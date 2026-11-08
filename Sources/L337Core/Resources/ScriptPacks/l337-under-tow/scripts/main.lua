-- Only the actual native commission dispatches this briefing-only event.
-- Native original custody and physical evidence never come from these journal commands.
return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "PENN: Matching form numbers do not make these collars fit."},
      {op = "journal.append", text = "Tug Lead Mira Penn: An emergency transport network has standardised its forms but not the physical coupling limits of its vessels. Review the complete survey, loan and receiving requirements before confirming."},
    }}
  end
}
