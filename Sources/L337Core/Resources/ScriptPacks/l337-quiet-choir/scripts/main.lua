-- Native Omdogan commission only. No field evidence or custody is produced by Lua.
return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "Captain Tamsin Holt: No one has proved these pulses are an attack. Calibrate your receiver at Lobagom before approaching the source. Agent Mara Vale will compare what you find with the mining relays."},
      {op = "journal.append", text = "HOLT: Our miners are losing their bearings. I will not order an attack on the basis of interference. Find out whether someone is calling, warning or hiding."},
    }}
  end
}
