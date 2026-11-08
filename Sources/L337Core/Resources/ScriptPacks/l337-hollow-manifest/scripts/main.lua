-- Only genuine native acceptance may dispatch this briefing-only handler.
-- This module grants no custody, scan, progress, arrival, payment or clue.
return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "Nia Toren: Two paid manifests name the same crate, and both captains insist it never reached them. Scan the freighters at Garrivek. If we follow the seal rather than the accusation, we can find where the cargo really went."},
      {op = "journal.append", text = "TOREN: The mutual has paid for the same machinery twice. I want a complete custody record. Keep the captains alive and their original seals intact."},
      {op = "journal.append", text = "Speak to freight auditor Nia Toren at Narargan in Galaxy 2 after completing one normal commodity sale. No score gate or link to another campaign."},
    }}
  end
}
