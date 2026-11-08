-- Native Taledea commission only. Private patient records remain outside this module.
return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "SERA DAIN: Our tenders have been called to three empty wrecks. Meanwhile, a real casualty waited alone. Compare the relay records at Ilasaeli. Do not broadcast patient locations; someone may be listening with one of our own keys."},
      {op = "journal.append", text = "DAIN: These calls use a genuine rescue key. I cannot tell the tenders to ignore it until we can distinguish a victim from an imitation. Take measurements first. An accusation will not keep anyone alive."},
    }}
  end
}
