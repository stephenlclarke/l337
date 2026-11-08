-- Only the actual native commission dispatches this briefing-only event.
-- No button, journal line or script command awards an original physical receipt.
return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "VOSS: A share certificate cannot stand in for the people on the next shift."},
      {op = "journal.append", text = "Marshal Nera Voss: A cluster of orbital homes must share a single transfer corridor during a maintenance season. Review the complete survey, loan and receiving requirements before confirming."},
    }}
  end
}
