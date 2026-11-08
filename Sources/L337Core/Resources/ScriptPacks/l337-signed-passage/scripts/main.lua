-- Current child of original Neron commission; no source stock, reference, serial, collection, crate or receiving is issued.
return {
  accepted = function(e, w, d)
    return {data = {}, commands = {
      {op = "journal.append", text = "SENN: Departure is a promise. Delivery is the receiver taking this exact consignment."},
      {op = "journal.append", text = "Dispatcher Evi Senn: An orbital receiving service repeatedly loses custody of a harmless calibration shipment during carrier handoffs. Review the complete survey, loan and receiving requirements before confirming."},
    }}
  end
}
