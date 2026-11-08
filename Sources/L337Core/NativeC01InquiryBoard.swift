import Foundation

/// One canonical source action, not a generic stage router or hidden input key.
enum NativeC01InquiryBoard {
  static let sourceID = "l337.glass-meridian"
  static let requestTitle = "Request continuity inquiry"
  static var requestKey: String { sourceID + "/" + NativeC01InquiryPhase.requestCase.rawValue }
}

extension Game {
  var c01InquiryRequestRows: [ContractBoardRow] {
    guard docked else { return [] }
    let review = c01InquiryRequestReview()
    return [.init(board: NativeC01InquiryBoard.sourceID, offer: nil,
      title: NativeC01InquiryBoard.requestTitle, reason: review.issues.first,
      inquiry: .requestCase)]
  }

  func c01InquiryRequestDetail() -> [String] {
    guard let review = contractBoard.inquiryQuote else {
      return [NativeC01InquiryBoard.requestTitle, "Review the charter evidence desk."]
    }
    var lines = [NativeC01InquiryBoard.requestTitle, "Glass Meridian continuity inquiry"]
    guard review.allowed, let intake = review.presentedIntake, intake.role == .intake else {
      lines += review.issues.isEmpty ? ["The charter evidence desk is unavailable here."] : review.issues
      lines.append("Back leaves your current case and original commission unchanged.")
      return lines
    }
    // This role comes from the real presented request's standing assignment.
    // No personal name, survival claim or available operator is synthesized.
    lines += [
      "Charter evidence service: intake desk.",
      "Confirm rechecks your arrival and opens a separate inquiry case.",
      "No fee, replacement stock or cargo space is required for this request.",
      "Original commission progress, losses, fees and rewards stay unchanged.",
      "Requesting a case earns no payment or clue. New measurements and independent receiving are still required.",
      "Confirm requests this case. Back cancels without opening it.",
    ]
    return lines
  }
}
