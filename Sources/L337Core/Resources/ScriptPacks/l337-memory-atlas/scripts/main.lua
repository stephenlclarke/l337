-- Actual native Reris commission only; Lua supplies original briefing text.
-- Original watcher custody and all physical evidence belong to native transactions.
return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "ORR: A beautiful memory is not a measured approach vector."},
      {op = "journal.append", text = "Agent Mara Vale: A navigation publisher has combined voluntary travel diaries with instrument surveys and now presents memories as exact route measurements. Review the complete survey, loan and receiving requirements before confirming."},
    }}
  end
}
