// Exact baseline empty-hull source budgets; no occupied/loaded mass or qualification grant.
extension OriginalFleetPhysicalData {
  static let baselineRegistrations: [String: Registration] = [
    "SH029": .init(
      id: "SH029", sha256: "f64a24c2863cf047f852d99313ca7ee131ebcda40c3e140f43572d6fbf3aa827", bytes: 33093,
      detailedSHA256: "0d0741f3c0a1eed7595b65274eab5726bc1b22c258b6943f6fdb5332931e91b7",
      componentsSHA256: "f284cfd590e8d741a5b9f2b133cdf2879c6ed8104c9f6d5773252bb8df707b21",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH029-design.toml",
      nativeSourceSHA256: "585cb9a7f47fb13f6249c09f2ccc262eb852c98ad10721a95730b68fc4eb7b5c",
      roleMapSHA256: "cd6f1104333dd94aa78b758e6ef0dac1504ab79fe6a3e6d5ef3ef3287536b3c3"),
    "SH061": .init(
      id: "SH061", sha256: "7e94b9a638bcc373da033d68c322706ed0261abf2f10b7544e3bf601c8683ff0", bytes: 212678,
      detailedSHA256: "fad88f0e9cfc1f9a3748ab995b9fca058f675a0c8a6fc89bc72ccefd8399e26b",
      componentsSHA256: "14597def726535eaba7de1dfe1d34ac922da23f907b582b945cfa45f59fcd61c",
      nativeSourcePath: "replacement-hulls/SH061-design.toml",
      nativeSourceSHA256: "fad88f0e9cfc1f9a3748ab995b9fca058f675a0c8a6fc89bc72ccefd8399e26b",
      roleMapSHA256: "3116ad99f94910fbc0c111fbfb539af0cec9998388f0527e0bff4f45bc8d1583",
      calibration: .existingRelative(scale: 20, exact: "20")),
  ]
}
