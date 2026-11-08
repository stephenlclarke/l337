import L337Mac

@main
struct L337Launcher {
  @MainActor static func main() async throws {
    try await L337App.main()
  }
}
