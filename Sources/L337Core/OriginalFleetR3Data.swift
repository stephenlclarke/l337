// Authored from the exact R3 contracts pinned in docs/FLEET-BACKLOG.json.
// This table supplies requirements; it never enables an actor or creates installed property.
enum OriginalFleetR3Data {
  static let ids: [String] = [
    "SH001", "SH002", "SH003", "SH004", "SH005", "SH006", "SH007", "SH008",
    "SH009", "SH010", "SH011", "SH012", "SH013", "SH014", "SH015", "SH016",
    "SH017", "SH018", "SH019", "SH020", "SH021", "SH022", "SH023", "SH024",
    "SH025", "SH026", "SH027", "SH028", "SH029", "SH030", "SH031", "SH032",
    "SH033", "SH034", "SH035", "SH036", "SH037", "SH038", "SH039", "SH040",
    "SH041", "SH042", "SH043", "SH044", "SH045", "SH046", "SH047", "SH048",
    "SH049", "SH050", "SH051", "SH052", "SH053", "SH054", "SH055", "SH056",
    "SH057", "SH058", "SH059", "SH060", "SH061", "SH062", "SH063", "SH064",
    "SH065", "SH066", "SH067", "SH068", "SH069", "SH070", "SH071", "SH072",
    "SH073", "SH074", "SH075", "SH076", "SH077", "SH078", "SH079", "SH080",
    "SH081", "SH082", "SH083", "SH084", "SH085", "SH086", "SH087", "SH088",
    "SH089", "SH090", "SH091", "SH092", "SH093", "SH094", "SH095", "SH096",
    "SH097", "SH098", "SH099", "SH100", "SH101", "SH102", "SH103", "SH104",
    "SH105", "SH106", "SH107", "SH108", "SH109", "SH110", "SH111", "SH112",
    "SH113", "SH114", "SH115", "SH116", "SH117", "SH118", "SH119", "SH120",
    "SH121", "SH122", "SH123", "SH124", "SH125", "SH126", "SH127", "SH128",
    "SH129", "SH130", "SH131", "SH132", "SH133", "SH134", "SH135", "SH136",
    "SH137", "SH138", "SH139", "SH140", "SH141", "SH142", "SH143", "SH144",
    "SH145", "SH146", "SH147", "SH148", "SH149", "SH150", "SH151", "SH152",
    "SH153", "SH154", "SH155", "SH156", "SH157", "SH158", "SH159", "SH160",
    "SH161", "SH162", "SH163", "SH164", "SH165", "SH166", "SH167", "SH168",
    "SH169", "SH170", "SH171",
  ]

  static func contract(for id: String) -> OriginalFleetR3Contract? {
    guard let load = contractLoader(for: id) else { return nil }
    return load()
  }

  // Select a small loader without constructing the large contract result in this dispatcher.
  @inline(never)
  private static func contractLoader(for id: String) -> (@Sendable () -> OriginalFleetR3Contract)? {
    switch id {
    case "SH001": return { sh001 }
    case "SH002": return { sh002 }
    case "SH003": return { sh003 }
    case "SH004": return { sh004 }
    case "SH005": return { sh005 }
    case "SH006": return { sh006 }
    case "SH007": return { sh007 }
    case "SH008": return { sh008 }
    case "SH009": return { sh009 }
    case "SH010": return { sh010 }
    case "SH011": return { sh011 }
    case "SH012": return { sh012 }
    case "SH013": return { sh013 }
    case "SH014": return { sh014 }
    case "SH015": return { sh015 }
    case "SH016": return { sh016 }
    case "SH017": return { sh017 }
    case "SH018": return { sh018 }
    case "SH019": return { sh019 }
    case "SH020": return { sh020 }
    case "SH021": return { sh021 }
    case "SH022": return { sh022 }
    case "SH023": return { sh023 }
    case "SH024": return { sh024 }
    case "SH025": return { sh025 }
    case "SH026": return { sh026 }
    case "SH027": return { sh027 }
    case "SH028": return { sh028 }
    case "SH029": return { sh029 }
    case "SH030": return { sh030 }
    case "SH031": return { sh031 }
    case "SH032": return { sh032 }
    case "SH033": return { sh033 }
    case "SH034": return { sh034 }
    case "SH035": return { sh035 }
    case "SH036": return { sh036 }
    case "SH037": return { sh037 }
    case "SH038": return { sh038 }
    case "SH039": return { sh039 }
    case "SH040": return { sh040 }
    case "SH041": return { sh041 }
    case "SH042": return { sh042 }
    case "SH043": return { sh043 }
    case "SH044": return { sh044 }
    case "SH045": return { sh045 }
    case "SH046": return { sh046 }
    case "SH047": return { sh047 }
    case "SH048": return { sh048 }
    case "SH049": return { sh049 }
    case "SH050": return { sh050 }
    case "SH051": return { sh051 }
    case "SH052": return { sh052 }
    case "SH053": return { sh053 }
    case "SH054": return { sh054 }
    case "SH055": return { sh055 }
    case "SH056": return { sh056 }
    case "SH057": return { sh057 }
    case "SH058": return { sh058 }
    case "SH059": return { sh059 }
    case "SH060": return { sh060 }
    case "SH061": return { sh061 }
    case "SH062": return { sh062 }
    case "SH063": return { sh063 }
    case "SH064": return { sh064 }
    case "SH065": return { sh065 }
    case "SH066": return { sh066 }
    case "SH067": return { sh067 }
    case "SH068": return { sh068 }
    case "SH069": return { sh069 }
    case "SH070": return { sh070 }
    case "SH071": return { sh071 }
    case "SH072": return { sh072 }
    case "SH073": return { sh073 }
    case "SH074": return { sh074 }
    case "SH075": return { sh075 }
    case "SH076": return { sh076 }
    case "SH077": return { sh077 }
    case "SH078": return { sh078 }
    case "SH079": return { sh079 }
    case "SH080": return { sh080 }
    case "SH081": return { sh081 }
    case "SH082": return { sh082 }
    case "SH083": return { sh083 }
    case "SH084": return { sh084 }
    case "SH085": return { sh085 }
    case "SH086": return { sh086 }
    case "SH087": return { sh087 }
    case "SH088": return { sh088 }
    case "SH089": return { sh089 }
    case "SH090": return { sh090 }
    case "SH091": return { sh091 }
    case "SH092": return { sh092 }
    case "SH093": return { sh093 }
    case "SH094": return { sh094 }
    case "SH095": return { sh095 }
    case "SH096": return { sh096 }
    case "SH097": return { sh097 }
    case "SH098": return { sh098 }
    case "SH099": return { sh099 }
    case "SH100": return { sh100 }
    case "SH101": return { sh101 }
    case "SH102": return { sh102 }
    case "SH103": return { sh103 }
    case "SH104": return { sh104 }
    case "SH105": return { sh105 }
    case "SH106": return { sh106 }
    case "SH107": return { sh107 }
    case "SH108": return { sh108 }
    case "SH109": return { sh109 }
    case "SH110": return { sh110 }
    case "SH111": return { sh111 }
    case "SH112": return { sh112 }
    case "SH113": return { sh113 }
    case "SH114": return { sh114 }
    case "SH115": return { sh115 }
    case "SH116": return { sh116 }
    case "SH117": return { sh117 }
    case "SH118": return { sh118 }
    case "SH119": return { sh119 }
    case "SH120": return { sh120 }
    case "SH121": return { sh121 }
    case "SH122": return { sh122 }
    case "SH123": return { sh123 }
    case "SH124": return { sh124 }
    case "SH125": return { sh125 }
    case "SH126": return { sh126 }
    case "SH127": return { sh127 }
    case "SH128": return { sh128 }
    case "SH129": return { sh129 }
    case "SH130": return { sh130 }
    case "SH131": return { sh131 }
    case "SH132": return { sh132 }
    case "SH133": return { sh133 }
    case "SH134": return { sh134 }
    case "SH135": return { sh135 }
    case "SH136": return { sh136 }
    case "SH137": return { sh137 }
    case "SH138": return { sh138 }
    case "SH139": return { sh139 }
    case "SH140": return { sh140 }
    case "SH141": return { sh141 }
    case "SH142": return { sh142 }
    case "SH143": return { sh143 }
    case "SH144": return { sh144 }
    case "SH145": return { sh145 }
    case "SH146": return { sh146 }
    case "SH147": return { sh147 }
    case "SH148": return { sh148 }
    case "SH149": return { sh149 }
    case "SH150": return { sh150 }
    case "SH151": return { sh151 }
    case "SH152": return { sh152 }
    case "SH153": return { sh153 }
    case "SH154": return { sh154 }
    case "SH155": return { sh155 }
    case "SH156": return { sh156 }
    case "SH157": return { sh157 }
    case "SH158": return { sh158 }
    case "SH159": return { sh159 }
    case "SH160": return { sh160 }
    case "SH161": return { sh161 }
    case "SH162": return { sh162 }
    case "SH163": return { sh163 }
    case "SH164": return { sh164 }
    case "SH165": return { sh165 }
    case "SH166": return { sh166 }
    case "SH167": return { sh167 }
    case "SH168": return { sh168 }
    case "SH169": return { sh169 }
    case "SH170": return { sh170 }
    case "SH171": return { sh171 }
    default: return nil
    }
  }

  private static let sh001: OriginalFleetR3Contract = .init(
    id: "SH001", name: "Mule", family: "mule",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "27c960f32df859e67b969e2d9a25d9fb15f8a887a253cd20f7cd213a728bf14c",
    referencedGeometrySHA256: "5a5c99c1ab2c481e0891a90a18f9376b054709f14604c2fa5a45771d4d2817fe",
    performance: .init(
      cargo: 76, speed: 33.2, acceleration: 9.6,
      energy: 290, recharge: 4.0, roll: 0.88,
      pitch: 0.77, yaw: 0.72, shield: 240,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 25, price: 310000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 15),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh002: OriginalFleetR3Contract = .init(
    id: "SH002", name: "Gyrfalcon Assault", family: "gyrfalcon",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "c2319489558505ed3d4eb6a437e8870e4f6f20055912e337792e324200d0230f",
    referencedGeometrySHA256: "5e665c3443a3f1fb2341d418dc9d5cbde7bc1f11d2761c67289defeb26e3c51a",
    performance: .init(
      cargo: 14, speed: 44.8, acceleration: 15.4,
      energy: 420, recharge: 5.4, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 8.0,
      spool: 12, missiles: 8, facings: 7,
      cargoExpansion: 5, price: 366000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: true),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh003: OriginalFleetR3Contract = .init(
    id: "SH003", name: "Gyrfalcon Command", family: "gyrfalcon",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "e4470633a66738c674f5e6cb61e1b464a89fd83c2f9b1c4b8a77b4b022788e0b",
    referencedGeometrySHA256: "fb28b8fbf3ac54e12bd0513f70ab6ca9140e8c361086b42bc3bfe5e71b91a90a",
    performance: .init(
      cargo: 28, speed: 39.0, acceleration: 15.4,
      energy: 460, recharge: 6.8, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 5, facings: 15,
      cargoExpansion: 5, price: 397000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "salvageCutter", "rescueReceiver", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh004: OriginalFleetR3Contract = .init(
    id: "SH004", name: "Gyrfalcon Patrol", family: "gyrfalcon",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "9d5f40fbdb42fe6539e9cee6906a07aff1a6caa192f164cffda019e8b79e3d47",
    referencedGeometrySHA256: "aa7bd053625093d77bdb1414e43c77278e68f1bbb6db3ab37c409700bcdcfeb5",
    performance: .init(
      cargo: 20, speed: 44.0, acceleration: 15.4,
      energy: 340, recharge: 5.0, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 6, facings: 3,
      cargoExpansion: 5, price: 345000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh005: OriginalFleetR3Contract = .init(
    id: "SH005", name: "Bison", family: "bison",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "abb18a2f94877670d18008dddde590a16a2322bdcc2311cd11b3f241fac43bcd",
    referencedGeometrySHA256: "63aba498e570d6b6e33f77c261019502cbe2c23b7aed69629a84c7ac17f52a08",
    performance: .init(
      cargo: 1108, speed: 17.7, acceleration: 3.44,
      energy: 1120, recharge: 6.4, roll: 0.267,
      pitch: 0.232, yaw: 0.215, shield: 590,
      shieldRecharge: 1.7, fuel: 130, jump: 7.0,
      spool: 16, missiles: 7, facings: 15,
      cargoExpansion: 445, price: 814000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 12, intrinsicCrewPlaces: 12,
      nativeAutonomous: false, nativeCrew: 12,
      conversionCrew: 12, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 221),
    fitting: .init(
      equipmentUnits: 48, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh006: OriginalFleetR3Contract = .init(
    id: "SH006", name: "Bison Mk II", family: "bison",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a01ab6d02762226d4dc194b3311c731e694af1e179b07791755e7a330ba86f6c",
    referencedGeometrySHA256: "fedf4bda1c86c1a580b4799f6476446c98bb7a319d39c8452245a92c5f9f1108",
    performance: .init(
      cargo: 1220, speed: 16.8, acceleration: 3.35,
      energy: 1300, recharge: 7.1, roll: 0.258,
      pitch: 0.224, yaw: 0.215, shield: 640,
      shieldRecharge: 1.78, fuel: 130, jump: 7.0,
      spool: 16, missiles: 8, facings: 15,
      cargoExpansion: 490, price: 908000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 14, intrinsicCrewPlaces: 14,
      nativeAutonomous: false, nativeCrew: 14,
      conversionCrew: 14, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 244),
    fitting: .init(
      equipmentUnits: 54, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh007: OriginalFleetR3Contract = .init(
    id: "SH007", name: "Impala Voyager", family: "impala",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "362f40c5d357d80c6559090d528a09f71858e09155b162996902c10aa4c7ff63",
    referencedGeometrySHA256: "911be33ac10be443afd3d33c6d20f65079bb9a5c20b58752597c52d50d12aad3",
    performance: .init(
      cargo: 60, speed: 38.0, acceleration: 11.0,
      energy: 260, recharge: 3.8, roll: 1.01,
      pitch: 0.89, yaw: 0.83, shield: 220,
      shieldRecharge: 1.7, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 15, price: 319000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 12),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh008: OriginalFleetR3Contract = .init(
    id: "SH008", name: "Goshawk Explorer", family: "goshawk",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "6815e92d5480692d18576ab5ed5e98cd1f99b1bff622c3c7eb346ed59bcf8d42",
    referencedGeometrySHA256: "9a6b3e1403a5cbb45691592f2db2e1dac79bfc7c0d328a4b86a234487943e127",
    performance: .init(
      cargo: 40, speed: 41.0, acceleration: 11.5,
      energy: 250, recharge: 4.6, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 230,
      shieldRecharge: 1.7, fuel: 150, jump: 13.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 15, price: 333000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 8),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh009: OriginalFleetR3Contract = .init(
    id: "SH009", name: "Goshawk Mk II", family: "goshawk",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "8487d3b24cff75389b9451eb6a3e9f041c907df16caf696a67cd31f46feec670",
    referencedGeometrySHA256: "41cda75d40e41e4de1a745de9f5c8770618fe5de2f0df0568a49a8c72ba92722",
    performance: .init(
      cargo: 20, speed: 42.0, acceleration: 11.27,
      energy: 420, recharge: 6.2, roll: 0.937,
      pitch: 0.826, yaw: 0.765, shield: 330,
      shieldRecharge: 2.1, fuel: 120, jump: 8.0,
      spool: 12, missiles: 8, facings: 7,
      cargoExpansion: 10, price: 375000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh010: OriginalFleetR3Contract = .init(
    id: "SH010", name: "Goshawk Mk II Custom", family: "goshawk",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "755f776227dcb1d7816b5e426fbe239a98f0f9d1df46fc1ebdbd90c5b15e5983",
    referencedGeometrySHA256: "3e131707177a4b934ad969dc62da49963adf9aa6a71985e6dcf21c8ba9dd179c",
    performance: .init(
      cargo: 16, speed: 40.0, acceleration: 13.1,
      energy: 470, recharge: 7.4, roll: 1.09,
      pitch: 0.96, yaw: 0.89, shield: 330,
      shieldRecharge: 2.1, fuel: 120, jump: 9.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 10, price: 398000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh011: OriginalFleetR3Contract = .init(
    id: "SH011", name: "Goshawk Scout", family: "goshawk",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "2d61d0afa8810dfec66208bee0b5b95555f64ddd9d2df76ce54b9a5c8a7c8ad1",
    referencedGeometrySHA256: "f0e1bf789ccad1f445f9d576c03affc853b7beb41b6820c03739b7e45a5e6884",
    performance: .init(
      cargo: 12, speed: 48.0, acceleration: 13.4,
      energy: 280, recharge: 4.5, roll: 1.13,
      pitch: 0.99, yaw: 0.93, shield: 300,
      shieldRecharge: 2.0, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 5, price: 333000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh012: OriginalFleetR3Contract = .init(
    id: "SH012", name: "Sable Liner", family: "sable-liner",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a59ed199acd7c681bc4e590076b0853d19db9724c777c0aee483878d30fcb0df",
    referencedGeometrySHA256: "980854a3c77366b6c0e1d8f559ffcbdad7bbf2fe510988fdd86a380477f6e297",
    performance: .init(
      cargo: 160, speed: 31.0, acceleration: 10.32,
      energy: 400, recharge: 5.3, roll: 0.903,
      pitch: 0.791, yaw: 0.74, shield: 220,
      shieldRecharge: 1.7, fuel: 160, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 10, price: 395000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 6, intrinsicCrewPlaces: 6,
      nativeAutonomous: false, nativeCrew: 6,
      conversionCrew: 6, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 32),
    fitting: .init(
      equipmentUnits: 40, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["lifeSupportService", "passengerCabin"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh013: OriginalFleetR3Contract = .init(
    id: "SH013", name: "Buffalo", family: "buffalo",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "84abd93c7ee81072ef52d70a95e7054bf30d778e988fd05452cb6bf959a37271",
    referencedGeometrySHA256: "dee5a8a5d108dbcc5bf4d035c7e55c40fae022a4c5a8af3249aa9e06ec348f97",
    performance: .init(
      cargo: 396, speed: 21.9, acceleration: 5.6,
      energy: 710, recharge: 5.2, roll: 0.43,
      pitch: 0.38, yaw: 0.35, shield: 470,
      shieldRecharge: 1.7, fuel: 150, jump: 10.0,
      spool: 14, missiles: 6, facings: 7,
      cargoExpansion: 160, price: 522000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 6, intrinsicCrewPlaces: 6,
      nativeAutonomous: false, nativeCrew: 6,
      conversionCrew: 6, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 79),
    fitting: .init(
      equipmentUnits: 34, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh014: OriginalFleetR3Contract = .init(
    id: "SH014", name: "Buffalo Mk II", family: "buffalo",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "17f2bcd6a0b854eb3c3f05714e6eca1fe2abb6935d79137dd4e222b78ec103e7",
    referencedGeometrySHA256: "a0d4eee2241d52161e1442f527bfd22bcd629dcb424f844cd5f7401e34e4b81c",
    performance: .init(
      cargo: 460, speed: 20.5, acceleration: 5.5,
      energy: 850, recharge: 5.9, roll: 0.41,
      pitch: 0.36, yaw: 0.34, shield: 510,
      shieldRecharge: 1.78, fuel: 150, jump: 10.0,
      spool: 14, missiles: 7, facings: 15,
      cargoExpansion: 175, price: 590000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 7, intrinsicCrewPlaces: 7,
      nativeAutonomous: false, nativeCrew: 7,
      conversionCrew: 7, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 92),
    fitting: .init(
      equipmentUnits: 38, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh015: OriginalFleetR3Contract = .init(
    id: "SH015", name: "Raven", family: "raven",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "9996fa6457ac946c7f01ed8dcab21275b17f260fd4f4cf106bd9d0fa1df71c66",
    referencedGeometrySHA256: "e91491dc97b465dea7c09c06f0d0da96a50b8ab0155d3e2af22ed1f99a14e1ca",
    performance: .init(
      cargo: 30, speed: 46.0, acceleration: 13.8,
      energy: 250, recharge: 3.3, roll: 1.39,
      pitch: 1.22, yaw: 1.14, shield: 170,
      shieldRecharge: 1.6, fuel: 120, jump: 9.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 10, price: 304000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh016: OriginalFleetR3Contract = .init(
    id: "SH016", name: "Mole Miner", family: "mole",
    classification: "miner", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "d1bf21e0ad41a1fab71976310b850c67c28de10666f331b9b09e99363967d366",
    referencedGeometrySHA256: "dd0e951f8c8d46e91b58fa65f45446fe8604f29f213439ddb060fe5c9ee248f6",
    performance: .init(
      cargo: 128, speed: 25.0, acceleration: 8.3,
      energy: 400, recharge: 5.2, roll: 0.67,
      pitch: 0.59, yaw: 0.55, shield: 310,
      shieldRecharge: 1.8, fuel: 120, jump: 8.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 45, price: 349000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 25),
    fitting: .init(
      equipmentUnits: 28, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh017: OriginalFleetR3Contract = .init(
    id: "SH017", name: "Mole Prospector", family: "mole",
    classification: "miner", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "c31408f9cbf0e76af47c583fcf084080addb1d8e84970cc0168d7c065bae385a",
    referencedGeometrySHA256: "2a5efee25247b09a861d5112c7d070685b1f9aa2892143505fca28332fb2d4f3",
    performance: .init(
      cargo: 96, speed: 29.0, acceleration: 8.3,
      energy: 350, recharge: 4.8, roll: 0.67,
      pitch: 0.59, yaw: 0.55, shield: 310,
      shieldRecharge: 1.8, fuel: 130, jump: 11.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 45, price: 347000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 19),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop", "surveyArray"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh018: OriginalFleetR3Contract = .init(
    id: "SH018", name: "Onager", family: "onager",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "93ec89428324d31d6639ad069107c767d7c0129d1683d26f27475fc89a56cc38",
    referencedGeometrySHA256: "40e2a5fdd0f7945141cb55701deab76a64f974a38133f86333bb4fd8d199fbf6",
    performance: .init(
      cargo: 58, speed: 39.0, acceleration: 11.0,
      energy: 220, recharge: 3.1, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 220,
      shieldRecharge: 1.5, fuel: 130, jump: 10.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 20, price: 281000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 11),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh019: OriginalFleetR3Contract = .init(
    id: "SH019", name: "Gazelle Explorer", family: "gazelle",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "9eb70cd7503964f5613f86cd6ceec2cf34f64598e8018779380fc6eca5b08a04",
    referencedGeometrySHA256: "56172839f14cc1aca09814de34d181b98832e87e071130d0c4c930a760d66944",
    performance: .init(
      cargo: 34, speed: 43.0, acceleration: 12.0,
      energy: 230, recharge: 3.8, roll: 1.05,
      pitch: 0.92, yaw: 0.86, shield: 220,
      shieldRecharge: 1.7, fuel: 160, jump: 14.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 10, price: 321000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh020: OriginalFleetR3Contract = .init(
    id: "SH020", name: "Crow Prototype", family: "crow",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a4578fb4a6fc9bddd3bbda55fe802ed80e153c0389610e21bf98c5e5521062c5",
    referencedGeometrySHA256: "626bcedd13d6affb1aaab5bc77ec7558a649fcc04e207ef34d3f848169be5b3d",
    performance: .init(
      cargo: 18, speed: 54.0, acceleration: 15.0,
      energy: 210, recharge: 3.5, roll: 1.45,
      pitch: 1.28, yaw: 1.19, shield: 170,
      shieldRecharge: 1.6, fuel: 140, jump: 11.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 10, price: 306000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh021: OriginalFleetR3Contract = .init(
    id: "SH021", name: "Zebra", family: "zebra",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "49908a275fb7e5af7c0715b384e8dcc0a9072e453c94c73826d177fccf3a20ea",
    referencedGeometrySHA256: "90942461424c81049c241869ac934058a53ae9f75cd494e9c50bebf10f6313e9",
    performance: .init(
      cargo: 66, speed: 34.0, acceleration: 9.4,
      energy: 330, recharge: 3.4, roll: 0.84,
      pitch: 0.74, yaw: 0.69, shield: 260,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 6, facings: 15,
      cargoExpansion: 25, price: 316000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 13),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh022: OriginalFleetR3Contract = .init(
    id: "SH022", name: "Peregrine Mk I", family: "peregrine",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f8502a924dca78b9274ae9ad282cb3d9636ce094087a2ab4365aae7f733a736d",
    referencedGeometrySHA256: "60cd55b2c752e53200a950ad9481c6f49bd6e9eed228071abb2d8794ed0a6979",
    performance: .init(
      cargo: 64, speed: 37.0, acceleration: 10.0,
      energy: 260, recharge: 3.2, roll: 0.9,
      pitch: 0.79, yaw: 0.74, shield: 230,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 25, price: 292000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 12),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh023: OriginalFleetR3Contract = .init(
    id: "SH023", name: "Peregrine Mk III", family: "peregrine",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "ecdb62da81e8b87f802dd92f60374dc4375375575855971b0bb25fb3ba0a679f",
    referencedGeometrySHA256: "b6fa2593479b011b08fe7818874da9263cc671d01270619081183f578c7ebbb3",
    performance: .init(
      cargo: 78, speed: 35.7, acceleration: 9.5,
      energy: 320, recharge: 3.7, roll: 0.84,
      pitch: 0.74, yaw: 0.69, shield: 270,
      shieldRecharge: 1.65, fuel: 130, jump: 9.0,
      spool: 13, missiles: 7, facings: 7,
      cargoExpansion: 30, price: 325000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 15),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh024: OriginalFleetR3Contract = .init(
    id: "SH024", name: "Peregrine Mk IV", family: "peregrine",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "2117edc243ad7386d00555caa6c05bf155f0d91f32af288d04c5e67ee914844c",
    referencedGeometrySHA256: "3148e8e17afe9a7be6e903cb563afd5e9547a4bb5c4f6267def86fbc78f37dbf",
    performance: .init(
      cargo: 86, speed: 34.6, acceleration: 9.3,
      energy: 360, recharge: 4.0, roll: 0.81,
      pitch: 0.71, yaw: 0.66, shield: 290,
      shieldRecharge: 1.72, fuel: 130, jump: 10.0,
      spool: 14, missiles: 6, facings: 15,
      cargoExpansion: 35, price: 348000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 17),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh025: OriginalFleetR3Contract = .init(
    id: "SH025", name: "Peregrine Mk V", family: "peregrine",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a305641b7be704a2af0129e146d4ef1d72d165a1cbc7b935458c4c35aea14cc0",
    referencedGeometrySHA256: "5c76051fbb6f681065858b312dadfb1acad3e10ea22559d6da6f62d6684d25cc",
    performance: .init(
      cargo: 92, speed: 34.3, acceleration: 9.1,
      energy: 380, recharge: 4.2, roll: 0.79,
      pitch: 0.7, yaw: 0.65, shield: 300,
      shieldRecharge: 1.8, fuel: 130, jump: 9.0,
      spool: 15, missiles: 9, facings: 15,
      cargoExpansion: 35, price: 362000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 18),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh026: OriginalFleetR3Contract = .init(
    id: "SH026", name: "Harrier", family: "harrier",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f23d79dc0c1a0caf93d36a118fc33db7bc7289eac393f49d0c64795d6aa0972e",
    referencedGeometrySHA256: "d0b3155b579a53d027741e93cae48295749c315447e0891319946f569421dd58",
    performance: .init(
      cargo: 18, speed: 44.5, acceleration: 15.4,
      energy: 390, recharge: 5.8, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 8.0,
      spool: 12, missiles: 7, facings: 7,
      cargoExpansion: 5, price: 362000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: true),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh027: OriginalFleetR3Contract = .init(
    id: "SH027", name: "Ibex", family: "ibex",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "7b038e5e6675b715d56d0ffbecf5ebaed4dd0216109c63aaf5c7dd990efa1aa8",
    referencedGeometrySHA256: "db3494ecc09b427242eed021bae074124aad87c38fe03b654161d49269952484",
    performance: .init(
      cargo: 54, speed: 36.2, acceleration: 11.0,
      energy: 270, recharge: 3.8, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 220,
      shieldRecharge: 1.5, fuel: 130, jump: 11.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 20, price: 307000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 10),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh028: OriginalFleetR3Contract = .init(
    id: "SH028", name: "Lion Citadel", family: "lion-citadel",
    classification: "station", objectKind: .station,
    origin: .human,
    environment: .init(
      playerCrewRequired: false, purchasePolicy: .never,
      physicalService: .stationServices),
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "b053d76b1912881af248045b29cf29d31cb2f77214b4f1697b8d69a78afa8768",
    referencedGeometrySHA256: "739d9bb076fcb0212ca48e7a00312e87f1f959d37d6ab1ff247b75ff2b39305a",
    performance: nil,
    accommodation: nil,
    fitting: nil,
    acquisition: nil)


  private static let sh029: OriginalFleetR3Contract = .init(
    id: "SH029", name: "Okapi", family: "okapi",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "229d27ea2c5213bd0993c99b9545997e065673e578b7120829e5c6bd06dafc59",
    referencedGeometrySHA256: "585cb9a7f47fb13f6249c09f2ccc262eb852c98ad10721a95730b68fc4eb7b5c",
    performance: .init(
      cargo: 60, speed: 37.8, acceleration: 10.6,
      energy: 280, recharge: 3.5, roll: 0.95,
      pitch: 0.84, yaw: 0.78, shield: 230,
      shieldRecharge: 1.5, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 20, price: 312000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 12),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh030: OriginalFleetR3Contract = .init(
    id: "SH030", name: "Sparrowhawk", family: "sparrowhawk",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "774d49d514d03dba198d09762d04d30e74d3ea07dad7f1c34167f0978defb36d",
    referencedGeometrySHA256: "92a8ba49e684eca12580df930e999bd6f21186821b92b87f8c381b0a3e017e66",
    performance: .init(
      cargo: 22, speed: 51.0, acceleration: 17.25,
      energy: 330, recharge: 5.0, roll: 1.478,
      pitch: 1.299, yaw: 1.21, shield: 250,
      shieldRecharge: 1.9, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 10, price: 352000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh031: OriginalFleetR3Contract = .init(
    id: "SH031", name: "Kite Interceptor", family: "kite",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "cedbde09b76675e9fb3f6022d9c78330524be816ec3d3878f600c0b5244fc8b0",
    referencedGeometrySHA256: "099246e4cea539c64042a0749ba1873e3fdbe2dfba92c53bc7370c03719dea56",
    performance: .init(
      cargo: 10, speed: 55.0, acceleration: 15.68,
      energy: 270, recharge: 4.6, roll: 1.288,
      pitch: 1.131, yaw: 1.053, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 9.0,
      spool: 12, missiles: 6, facings: 1,
      cargoExpansion: 5, price: 325000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 14, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh032: OriginalFleetR3Contract = .init(
    id: "SH032", name: "Panther Explorer", family: "panther",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "9bbbecb8af20c7c20d0d95e0a1d82aeb27950d4a6243329af3a0e6848ecd3a6f",
    referencedGeometrySHA256: "d87094362d608526b5e257173478f305b0b2f786d573abdb51f7ef613a4bb131",
    performance: .init(
      cargo: 32, speed: 47.0, acceleration: 12.5,
      energy: 220, recharge: 3.6, roll: 1.07,
      pitch: 0.94, yaw: 0.88, shield: 200,
      shieldRecharge: 1.7, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 10, price: 312000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh033: OriginalFleetR3Contract = .init(
    id: "SH033", name: "Panther Scout", family: "panther",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f2e0376401c62989cac6f1faad27d484e53627008818dabe0e49ae2e3f194c76",
    referencedGeometrySHA256: "2bdbe5b0f70a0d0316d8288d73457f96364fdad930fd7b746ce311437dacf435",
    performance: .init(
      cargo: 14, speed: 50.2, acceleration: 14.6,
      energy: 300, recharge: 4.9, roll: 1.17,
      pitch: 1.03, yaw: 0.96, shield: 270,
      shieldRecharge: 2.0, fuel: 130, jump: 11.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 5, price: 342000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh034: OriginalFleetR3Contract = .init(
    id: "SH034", name: "Frog Station", family: "frog",
    classification: "station", objectKind: .station,
    origin: .human,
    environment: .init(
      playerCrewRequired: false, purchasePolicy: .never,
      physicalService: .stationServices),
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "cfa885e19c022d6dfe201d03c009f9fad1859cd3ee1966eb9daf379f557622c1",
    referencedGeometrySHA256: "72b115f13920c18166a75fa9959ec8b0051af4a957773a7da1dccfd3fbb03e4e",
    performance: nil,
    accommodation: nil,
    fitting: nil,
    acquisition: nil)


  private static let sh035: OriginalFleetR3Contract = .init(
    id: "SH035", name: "Stag Liner", family: "stag",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "dff26cfb4027b272cb7e82c1fd967ec5aa8e27e4a74d2cdfd28a5a01a5836dae",
    referencedGeometrySHA256: "78f0f2a3940b7c50c9dafc17323320da23173b25af19c16a0be427167949334a",
    performance: .init(
      cargo: 100, speed: 35.0, acceleration: 10.92,
      energy: 330, recharge: 4.8, roll: 0.946,
      pitch: 0.834, yaw: 0.774, shield: 220,
      shieldRecharge: 1.7, fuel: 140, jump: 11.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 10, price: 353000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 20),
    fitting: .init(
      equipmentUnits: 34, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["lifeSupportService", "passengerCabin"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh036: OriginalFleetR3Contract = .init(
    id: "SH036", name: "Zebu", family: "zebu",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "4fc25d2778c8e0ab927313a279ca31fcb68df46557223e2cb268a99e7e97dcc4",
    referencedGeometrySHA256: "3dd03d7688ee39b0009b257bb5cb0b65f20f5c4ac4580549396b07a48fceb1de",
    performance: .init(
      cargo: 72, speed: 33.0, acceleration: 10.0,
      energy: 300, recharge: 3.9, roll: 0.9,
      pitch: 0.79, yaw: 0.74, shield: 230,
      shieldRecharge: 1.5, fuel: 150, jump: 11.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 25, price: 319000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 14),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh037: OriginalFleetR3Contract = .init(
    id: "SH037", name: "Vulture Mk I", family: "vulture",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "1205c491e12819aaed94eff59ab4c8e22bc52cea61abbdbdb77834fa03301099",
    referencedGeometrySHA256: "c00f8163a07a5c90c2867334d03e275311afb3060ea5434841b6ab6005553f23",
    performance: .init(
      cargo: 14, speed: 58.3, acceleration: 19.1,
      energy: 140, recharge: 2.7, roll: 2.03,
      pitch: 1.79, yaw: 1.66, shield: 140,
      shieldRecharge: 1.6, fuel: 110, jump: 8.0,
      spool: 10, missiles: 4, facings: 1,
      cargoExpansion: 5, price: 262000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 14, utilityMounts: 1,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh038: OriginalFleetR3Contract = .init(
    id: "SH038", name: "Vulture Mk II", family: "vulture",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "55d9bb7a617e090e120ae639b19a6eb1f8fa91d220928bf58a498193c425ffd6",
    referencedGeometrySHA256: "41e9704f9c177717f42dabc4290bbe67b6792b9916a837dfaf9ef63d820191d4",
    performance: .init(
      cargo: 18, speed: 55.8, acceleration: 18.7,
      energy: 210, recharge: 3.6, roll: 1.97,
      pitch: 1.73, yaw: 1.62, shield: 150,
      shieldRecharge: 1.68, fuel: 110, jump: 9.0,
      spool: 10, missiles: 5, facings: 3,
      cargoExpansion: 5, price: 303000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh039: OriginalFleetR3Contract = .init(
    id: "SH039", name: "Vulture Mk III", family: "vulture",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a64233f42e9882bba36eaba7cb1d997bee73881dff3eb06e72cffc70d3ebba9e",
    referencedGeometrySHA256: "2b69475d2bc724889e10506f88e72df522dd054328c486d5cc67a36d209438c2",
    performance: .init(
      cargo: 24, speed: 52.5, acceleration: 15.65,
      energy: 300, recharge: 4.8, roll: 1.634,
      pitch: 1.436, yaw: 1.342, shield: 160,
      shieldRecharge: 1.76, fuel: 110, jump: 9.0,
      spool: 11, missiles: 7, facings: 7,
      cargoExpansion: 5, price: 352000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: true),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh040: OriginalFleetR3Contract = .init(
    id: "SH040", name: "Newt Escape Pod", family: "newt-escape-pod",
    classification: "capsule", objectKind: .capsule,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .never,
    sourceSHA256: "6dd8182abf9a00406132db7926c962d470ea7f6c112bb29fad8646aef9aec0ed",
    referencedGeometrySHA256: "5b52208ecf64228a843dc792ff4614af3ff9109034de4bedb6ddb0b7918072d9",
    performance: .init(
      cargo: 0, speed: 18.0, acceleration: 3.0,
      energy: 70, recharge: 0.6, roll: 0.55,
      pitch: 0.48, yaw: 0.45, shield: 30,
      shieldRecharge: 0.4, fuel: 0, jump: 0.0,
      spool: 0, missiles: 0, facings: 0,
      cargoExpansion: 0, price: 0, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 0),
    fitting: .init(
      equipmentUnits: 0, utilityMounts: 0,
      compatibleUtilities: [],
      recommendedRoleKit: [], roleKitIncluded: false,
      passengerCabinGrades: [],
      externalMissilePylons: false),
    acquisition: nil)


  private static let sh041: OriginalFleetR3Contract = .init(
    id: "SH041", name: "Serval Fighter", family: "serval",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "7f7213ef84d6fc2e1895bf0097f9106c37df199b33d72bf6c78c975a9df197bb",
    referencedGeometrySHA256: "5d3e7b5da7bee8f62a47aeac58f13064e185d6dc49c842863da82e2a97679fa6",
    performance: .init(
      cargo: 20, speed: 43.6, acceleration: 13.4,
      energy: 390, recharge: 6.1, roll: 1.13,
      pitch: 0.99, yaw: 0.93, shield: 300,
      shieldRecharge: 2.0, fuel: 120, jump: 9.0,
      spool: 12, missiles: 6, facings: 7,
      cargoExpansion: 5, price: 365000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh042: OriginalFleetR3Contract = .init(
    id: "SH042", name: "Saker", family: "saker",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "36a903484eb884b1774baf0c18270d99916c54cc1cfa55aad32253284faf4293",
    referencedGeometrySHA256: "8b64ebb1529abe86018b7b2553c45f961c06f0e0a9182321ec1b528cb0a716c8",
    performance: .init(
      cargo: 12, speed: 51.0, acceleration: 15.68,
      energy: 330, recharge: 5.2, roll: 1.288,
      pitch: 1.131, yaw: 1.053, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 5, price: 350000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh043: OriginalFleetR3Contract = .init(
    id: "SH043", name: "Eagle Cruiser", family: "eagle",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "be5d22e65550f8420a4f61ce6c784b1161fcc645d3e542c671dd864e9e736368",
    referencedGeometrySHA256: "1c7a31a989c833da95651924fa5f44ce9d7fbb56be68b4b6cffe710b1c393216",
    performance: .init(
      cargo: 172, speed: 22.8, acceleration: 5.2,
      energy: 1490, recharge: 9.7, roll: 0.42,
      pitch: 0.37, yaw: 0.34, shield: 600,
      shieldRecharge: 2.0, fuel: 140, jump: 7.0,
      spool: 18, missiles: 10, facings: 15,
      cargoExpansion: 70, price: 0, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 28, intrinsicCrewPlaces: 28,
      nativeAutonomous: false, nativeCrew: 28,
      conversionCrew: 28, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 34),
    fitting: .init(
      equipmentUnits: 60, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: nil)


  private static let sh044: OriginalFleetR3Contract = .init(
    id: "SH044", name: "Harpy Assault", family: "harpy",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "4e52c59c8ea67c28ed0c85e6bc8d6bd2adc33ef268aac2b902a02a4860b94aab",
    referencedGeometrySHA256: "6221e902c9893e7c3e9b9557e7f3331dc95da26282b76c1edfdbeba8f9f94f25",
    performance: .init(
      cargo: 18, speed: 42.4, acceleration: 14.0,
      energy: 480, recharge: 6.0, roll: 1.15,
      pitch: 1.01, yaw: 0.94, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 8.0,
      spool: 12, missiles: 8, facings: 7,
      cargoExpansion: 5, price: 394000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh045: OriginalFleetR3Contract = .init(
    id: "SH045", name: "Erne Corvette", family: "erne",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "7328c686a42309644a8a413272ba723bd367422e2e7315f5f10cf107a82f54bb",
    referencedGeometrySHA256: "af9e790882ec54bdc368ba1adc7edd757a032c3557d381a50a109bff5abc1ca9",
    performance: .init(
      cargo: 32, speed: 36.0, acceleration: 13.2,
      energy: 610, recharge: 7.0, roll: 1.07,
      pitch: 0.94, yaw: 0.88, shield: 330,
      shieldRecharge: 2.0, fuel: 120, jump: 9.0,
      spool: 12, missiles: 9, facings: 15,
      cargoExpansion: 5, price: 453000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 5, intrinsicCrewPlaces: 5,
      nativeAutonomous: false, nativeCrew: 5,
      conversionCrew: 5, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 28, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh046: OriginalFleetR3Contract = .init(
    id: "SH046", name: "Harpy Dropship", family: "harpy",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "18403611eadeb9ccad245863016046fb2df9ef19041f428d52492fdda9574951",
    referencedGeometrySHA256: "2619b8ca62cad610226c8f3862882d17de9b6b83186c192eb0e099dc66eb1c4f",
    performance: .init(
      cargo: 48, speed: 36.8, acceleration: 14.0,
      energy: 450, recharge: 5.8, roll: 1.15,
      pitch: 1.01, yaw: 0.94, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 9.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 5, price: 384000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 5, intrinsicCrewPlaces: 5,
      nativeAutonomous: false, nativeCrew: 5,
      conversionCrew: 5, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 9),
    fitting: .init(
      equipmentUnits: 30, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["lifeSupportService", "passengerCabin"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh047: OriginalFleetR3Contract = .init(
    id: "SH047", name: "Harpy Gunship", family: "harpy",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "9dfe04c0823e82541eb1cde7f54438b81b78ed3f6d94e21ab47fef7802879375",
    referencedGeometrySHA256: "7cb0dad60b3f677c8710677403cba2213ffd5bfb1a7ee1a2d2b012cacc381dd7",
    performance: .init(
      cargo: 14, speed: 38.0, acceleration: 12.04,
      energy: 560, recharge: 8.2, roll: 0.989,
      pitch: 0.869, yaw: 0.808, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 8.0,
      spool: 12, missiles: 9, facings: 15,
      cargoExpansion: 5, price: 436000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh048: OriginalFleetR3Contract = .init(
    id: "SH048", name: "Lanner", family: "lanner",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f8ed0cb8dcbc123a34d9c6718041de1913b6c63c4958adfbe455f1500dcacaaf",
    referencedGeometrySHA256: "e55137ce5a91f7b2fc6521f3ebe11be865ee7b2c1467452844f33bb10edc90f6",
    performance: .init(
      cargo: 10, speed: 65.3, acceleration: 21.62,
      energy: 190, recharge: 3.6, roll: 1.882,
      pitch: 1.658, yaw: 1.546, shield: 190,
      shieldRecharge: 1.9, fuel: 120, jump: 9.0,
      spool: 10, missiles: 4, facings: 1,
      cargoExpansion: 5, price: 302000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 14, utilityMounts: 1,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh049: OriginalFleetR3Contract = .init(
    id: "SH049", name: "Hyena", family: "hyena",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "5259887cd03e65b86d4430361cbedfa2c6a1f6876d3e212540fa2c2c79c3f04a",
    referencedGeometrySHA256: "2a7b44a76ef0f5c34c5e0596d5636f746145dfdc08cc75f151834bf11e477b10",
    performance: .init(
      cargo: 32, speed: 49.5, acceleration: 15.0,
      energy: 280, recharge: 3.8, roll: 1.45,
      pitch: 1.28, yaw: 1.19, shield: 170,
      shieldRecharge: 1.6, fuel: 120, jump: 8.0,
      spool: 12, missiles: 6, facings: 7,
      cargoExpansion: 10, price: 324000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh050: OriginalFleetR3Contract = .init(
    id: "SH050", name: "Yak", family: "yak",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "bbe9e3acc93bd75e24ee42500c8b836d1a4d7eecf765c9f34bd879a6c38eaa0a",
    referencedGeometrySHA256: "7f555c4821c9de8bea3026e88273c58acf7a778299ec67883f1e5990a31768b0",
    performance: .init(
      cargo: 80, speed: 31.5, acceleration: 10.0,
      energy: 340, recharge: 4.3, roll: 0.9,
      pitch: 0.79, yaw: 0.74, shield: 230,
      shieldRecharge: 1.5, fuel: 150, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 25, price: 334000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 16),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh051: OriginalFleetR3Contract = .init(
    id: "SH051", name: "Jackal", family: "jackal",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "218b167b067e238569c619e73bd5f4ba08f941b115aaeec7a2466d2569061da6",
    referencedGeometrySHA256: "20199532d8d84d93152c05161e5f0af52ca6400ccdac0b326115a0d65c9fe5de",
    performance: .init(
      cargo: 28, speed: 48.0, acceleration: 14.4,
      energy: 250, recharge: 4.3, roll: 1.42,
      pitch: 1.25, yaw: 1.16, shield: 180,
      shieldRecharge: 1.6, fuel: 120, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 10, price: 322000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["salvageBeam", "salvageCutter", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh052: OriginalFleetR3Contract = .init(
    id: "SH052", name: "Banteng", family: "banteng",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "d68c0e8af3ba7c75ba30a23441b2adb2b380ccaf755c974c46c822a657c70cce",
    referencedGeometrySHA256: "861010b50f1117030293cec1a8bed050112252ffe9373dde98b9b00cdc467ed2",
    performance: .init(
      cargo: 68, speed: 37.4, acceleration: 10.4,
      energy: 250, recharge: 3.3, roll: 0.92,
      pitch: 0.81, yaw: 0.75, shield: 210,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 25, price: 288000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 13),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh053: OriginalFleetR3Contract = .init(
    id: "SH053", name: "Caracal Scout", family: "caracal",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "d460619fc51986f13b5c54d08654755341da670df9ece4b755ff2cb35753aba0",
    referencedGeometrySHA256: "0894d36fe7de3b645594fa7665a7b7231722e1b2f23c4a904278e91d4099ada0",
    performance: .init(
      cargo: 10, speed: 52.0, acceleration: 14.6,
      energy: 300, recharge: 5.0, roll: 1.17,
      pitch: 1.03, yaw: 0.96, shield: 270,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 5, facings: 1,
      cargoExpansion: 5, price: 340000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh054: OriginalFleetR3Contract = .init(
    id: "SH054", name: "Hobby Fighter", family: "hobby",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "dafe7d8be715227740f0a7d3a05f106fa6f4bf7faa775955b456e8338f413848",
    referencedGeometrySHA256: "1a933aff0cb9f12bfb23ef4d8a834350e33021f5d7942934db94401ce350ab54",
    performance: .init(
      cargo: 12, speed: 49.0, acceleration: 15.4,
      energy: 280, recharge: 4.8, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 9.0,
      spool: 12, missiles: 6, facings: 3,
      cargoExpansion: 5, price: 320000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 14, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh055: OriginalFleetR3Contract = .init(
    id: "SH055", name: "Condor", family: "condor",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "58333569187849df206f88e371a9102bda0d98eb2fdb922a317533ce5c3a4038",
    referencedGeometrySHA256: "770a05d0e3faacffb915e1bc5ccfc3bb0e5142d940132843e182ca0b71d9752f",
    performance: .init(
      cargo: 38, speed: 43.0, acceleration: 13.8,
      energy: 320, recharge: 4.1, roll: 1.39,
      pitch: 1.22, yaw: 1.14, shield: 170,
      shieldRecharge: 1.6, fuel: 120, jump: 9.0,
      spool: 12, missiles: 5, facings: 15,
      cargoExpansion: 10, price: 337000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 7),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["salvageBeam", "salvageCutter", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh056: OriginalFleetR3Contract = .init(
    id: "SH056", name: "Aplomado Interceptor", family: "aplomado",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "95499ece85aad0bf86717d4f71101e5be9e9f23251c26b6a68a482395383288d",
    referencedGeometrySHA256: "625559c0932f56b8971d90606d0c861811dca3353318b632a300bdb5fbfcf11f",
    performance: .init(
      cargo: 10, speed: 56.0, acceleration: 15.01,
      energy: 260, recharge: 4.4, roll: 1.266,
      pitch: 1.109, yaw: 1.042, shield: 300,
      shieldRecharge: 2.0, fuel: 120, jump: 9.0,
      spool: 12, missiles: 5, facings: 1,
      cargoExpansion: 5, price: 319000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 14, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh057: OriginalFleetR3Contract = .init(
    id: "SH057", name: "Falconet", family: "falconet",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "ffe134c836380aa65bfa648403c6954daff113f4fef4dfc6467c03ef8e01410d",
    referencedGeometrySHA256: "08f2a4ceeb05e5ba652c2691301d17a285ec99de0c4f79d9fcdcdaec18bb5fa9",
    performance: .init(
      cargo: 10, speed: 51.8, acceleration: 13.4,
      energy: 310, recharge: 5.4, roll: 1.13,
      pitch: 0.99, yaw: 0.93, shield: 300,
      shieldRecharge: 2.0, fuel: 120, jump: 8.0,
      spool: 12, missiles: 6, facings: 3,
      cargoExpansion: 5, price: 336000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh058: OriginalFleetR3Contract = .init(
    id: "SH058", name: "Muskox", family: "muskox",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "fd5f2d8a64762ab74e1849985e6cf3bf25184968e5cf6f7d6d15213eadd3b11c",
    referencedGeometrySHA256: "13ef038a1ab17ffb777bd43f6a63b0a973bbea8bfd6076248cc14f8f1d49b2b8",
    performance: .init(
      cargo: 430, speed: 20.2, acceleration: 5.3,
      energy: 860, recharge: 5.6, roll: 0.4,
      pitch: 0.35, yaw: 0.33, shield: 540,
      shieldRecharge: 1.7, fuel: 130, jump: 8.0,
      spool: 14, missiles: 6, facings: 15,
      cargoExpansion: 165, price: 574000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 7, intrinsicCrewPlaces: 7,
      nativeAutonomous: false, nativeCrew: 7,
      conversionCrew: 7, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 86),
    fitting: .init(
      equipmentUnits: 38, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh059: OriginalFleetR3Contract = .init(
    id: "SH059", name: "Barbary", family: "barbary",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "682ea6695deaf59ec229599d0fbcea0b86b8f307de68f220e15e1201bc8dbd94",
    referencedGeometrySHA256: "1c642950f8d6c5ef773cc36b9c73c249e87e582de19d412e62e4e76e8f7b8b14",
    performance: .init(
      cargo: 24, speed: 41.0, acceleration: 12.9,
      energy: 440, recharge: 6.0, roll: 1.1,
      pitch: 0.97, yaw: 0.9, shield: 300,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 6, facings: 7,
      cargoExpansion: 10, price: 383000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh060: OriginalFleetR3Contract = .init(
    id: "SH060", name: "Wombat", family: "wombat",
    classification: "miner", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "7741929f5e69b590c7a0324963e1e45d3b298eb63b4ea4419c1f186fb1684677",
    referencedGeometrySHA256: "d7e3fcf666702d6cdd5b8b78f73fdb0117a58a8b5a219b9107da04e1fb1c4b70",
    performance: .init(
      cargo: 88, speed: 28.5, acceleration: 9.5,
      energy: 430, recharge: 5.8, roll: 0.73,
      pitch: 0.64, yaw: 0.6, shield: 290,
      shieldRecharge: 1.8, fuel: 120, jump: 8.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 30, price: 365000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 17),
    fitting: .init(
      equipmentUnits: 28, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh061: OriginalFleetR3Contract = .init(
    id: "SH061", name: "Saiga", family: "saiga",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a5b9e65f897bebac9f94ab7ba88c5f38908bf13da7c85c5c3eff5b74ed96a4a4",
    referencedGeometrySHA256: "fad88f0e9cfc1f9a3748ab995b9fca058f675a0c8a6fc89bc72ccefd8399e26b",
    performance: .init(
      cargo: 84, speed: 32.7, acceleration: 9.2,
      energy: 310, recharge: 3.6, roll: 0.86,
      pitch: 0.76, yaw: 0.71, shield: 230,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 5, facings: 7,
      cargoExpansion: 30, price: 315000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 16),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh062: OriginalFleetR3Contract = .init(
    id: "SH062", name: "Moose Clipper", family: "moose",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "af7e5b06c322c002069f6c7ea99d3ba77a7c421a33231c983d49643572e84c42",
    referencedGeometrySHA256: "ec91173e7ff65ed64271fabdae0c237519774c07d5ef6a97a2e21c36287324f0",
    performance: .init(
      cargo: 360, speed: 27.0, acceleration: 5.8,
      energy: 600, recharge: 5.1, roll: 0.44,
      pitch: 0.39, yaw: 0.36, shield: 440,
      shieldRecharge: 1.7, fuel: 130, jump: 9.0,
      spool: 14, missiles: 5, facings: 3,
      cargoExpansion: 160, price: 476000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 72),
    fitting: .init(
      equipmentUnits: 30, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh063: OriginalFleetR3Contract = .init(
    id: "SH063", name: "Seriema Courier", family: "seriema",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "234fb257ba59abe14540cb18f87c9fbf62332f0d6172b91487b67bc355a81faa",
    referencedGeometrySHA256: "557e9ad9e2a496ee0f29ae34b5db40a05ceddd7e8f8ed5ddf9a7ee0b78edc722",
    performance: .init(
      cargo: 26, speed: 48.0, acceleration: 13.4,
      energy: 300, recharge: 4.6, roll: 1.13,
      pitch: 0.99, yaw: 0.93, shield: 300,
      shieldRecharge: 2.0, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 5, price: 346000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh064: OriginalFleetR3Contract = .init(
    id: "SH064", name: "Arna Cutter", family: "arna",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "91172f72834f1078bb886c2bc8581fb880dc2641b7b5c92ab16eda4181d0f4ad",
    referencedGeometrySHA256: "470c4f3530d75eb55cd74e896922e26b26df6771b65af04112639db4209d5c80",
    performance: .init(
      cargo: 340, speed: 25.6, acceleration: 5.8,
      energy: 670, recharge: 5.5, roll: 0.44,
      pitch: 0.39, yaw: 0.36, shield: 440,
      shieldRecharge: 1.7, fuel: 130, jump: 10.0,
      spool: 14, missiles: 5, facings: 3,
      cargoExpansion: 160, price: 505000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 5, intrinsicCrewPlaces: 5,
      nativeAutonomous: false, nativeCrew: 5,
      conversionCrew: 5, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 68),
    fitting: .init(
      equipmentUnits: 32, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh065: OriginalFleetR3Contract = .init(
    id: "SH065", name: "Vulture Raider", family: "vulture",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "9cf0eb3f8ec63b539dbb093734c1833f8cb95775c76d547580c99511b054fa83",
    referencedGeometrySHA256: "b29e5447be715c56e804b43d4ef5b71ecad354d18c48cf7e6e16d2aac78771af",
    performance: .init(
      cargo: 20, speed: 56.0, acceleration: 19.1,
      energy: 180, recharge: 3.2, roll: 2.03,
      pitch: 1.79, yaw: 1.66, shield: 140,
      shieldRecharge: 1.6, fuel: 110, jump: 8.0,
      spool: 10, missiles: 5, facings: 3,
      cargoExpansion: 5, price: 286000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh066: OriginalFleetR3Contract = .init(
    id: "SH066", name: "Rabbit Explorer", family: "rabbit",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "10fe257691fbe5ee08953837dd65002ec547c02362a1f09436ab97d78e515676",
    referencedGeometrySHA256: "9ade27660044661f97105983b4995184ab7347aadf2efb5e62ae5d030b0f12e5",
    performance: .init(
      cargo: 28, speed: 49.0, acceleration: 12.5,
      energy: 200, recharge: 3.5, roll: 1.07,
      pitch: 0.94, yaw: 0.88, shield: 200,
      shieldRecharge: 1.7, fuel: 140, jump: 11.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 10, price: 297000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh067: OriginalFleetR3Contract = .init(
    id: "SH067", name: "Rhinoceros Trader", family: "rhinoceros",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "18e33608d5ff332934812bfcf40b6f99cafdcc900727a0a5f2090ab183dd15af",
    referencedGeometrySHA256: "7cd4727a35a98a558d717bb3f16cf2d92a7bbd20d40f391f31b1854c1fa7736f",
    performance: .init(
      cargo: 74, speed: 31.0, acceleration: 10.6,
      energy: 420, recharge: 4.1, roll: 0.95,
      pitch: 0.84, yaw: 0.78, shield: 230,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 6, facings: 15,
      cargoExpansion: 20, price: 350000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 14),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh068: OriginalFleetR3Contract = .init(
    id: "SH068", name: "Badger", family: "badger",
    classification: "miner", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f715749177b8a3897f5af27b32f991205965847a1aa90da63ee37c5f11f74196",
    referencedGeometrySHA256: "9a793c007844bbb9fe72ebc51cfe0e5d671739ac087b63628a3d91857e868fe5",
    performance: .init(
      cargo: 116, speed: 25.5, acceleration: 8.3,
      energy: 470, recharge: 6.4, roll: 0.67,
      pitch: 0.59, yaw: 0.55, shield: 310,
      shieldRecharge: 1.8, fuel: 120, jump: 9.0,
      spool: 12, missiles: 5, facings: 7,
      cargoExpansion: 45, price: 395000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 23),
    fitting: .init(
      equipmentUnits: 32, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop", "salvageCutter"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh069: OriginalFleetR3Contract = .init(
    id: "SH069", name: "Baza Fighter", family: "baza",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "d807c75dab09754cdf61f174014ed1714dc8c03002f8fb5e4848d37524f18aa6",
    referencedGeometrySHA256: "02c42c3c40b2a4542db58570f3b689c31dcaa49503c9b8d930f3aae52e1a6bb4",
    performance: .init(
      cargo: 16, speed: 46.3, acceleration: 15.4,
      energy: 350, recharge: 5.2, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 9.0,
      spool: 12, missiles: 7, facings: 7,
      cargoExpansion: 5, price: 352000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh070: OriginalFleetR3Contract = .init(
    id: "SH070", name: "Baza Mk II", family: "baza",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a93cfc8d733b3d667ec1f24cf877e2d689102913a42acc30cdb77078ade6c6fe",
    referencedGeometrySHA256: "25c56839704deba785e7c381a9db70ddc7e225d94ca37d144a4becb150f7c4fd",
    performance: .init(
      cargo: 20, speed: 53.1, acceleration: 19.26,
      energy: 310, recharge: 4.8, roll: 1.68,
      pitch: 1.478, yaw: 1.378, shield: 250,
      shieldRecharge: 1.99, fuel: 130, jump: 10.0,
      spool: 12, missiles: 6, facings: 3,
      cargoExpansion: 10, price: 350000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: true),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh071: OriginalFleetR3Contract = .init(
    id: "SH071", name: "Griffon", family: "griffon",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "aae0fbafceeb0adf78d050c184bdca3eb4b0a1f11240c83430aaa27e1a5c3519",
    referencedGeometrySHA256: "3f1d908400f032a2a90b8a4ee486c58e93368e4c49a1fa8a742ba52b7c9a80cc",
    performance: .init(
      cargo: 26, speed: 48.0, acceleration: 14.1,
      energy: 270, recharge: 3.6, roll: 1.35,
      pitch: 1.19, yaw: 1.11, shield: 190,
      shieldRecharge: 1.6, fuel: 120, jump: 9.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 10, price: 317000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["salvageBeam", "salvageCutter", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh072: OriginalFleetR3Contract = .init(
    id: "SH072", name: "Griffon Mk II", family: "griffon",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "4be1bb6109ec00b2bb05dbba194562054f10d27ee8ff4a105a310b7aa3370498",
    referencedGeometrySHA256: "8ea9b1346142ef4c31e71b802258b859d54be0cdc12ac05bf3f6a02d55733d70",
    performance: .init(
      cargo: 34, speed: 45.0, acceleration: 13.8,
      energy: 350, recharge: 4.5, roll: 1.3,
      pitch: 1.14, yaw: 1.07, shield: 210,
      shieldRecharge: 1.68, fuel: 120, jump: 10.0,
      spool: 12, missiles: 7, facings: 15,
      cargoExpansion: 10, price: 361000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh073: OriginalFleetR3Contract = .init(
    id: "SH073", name: "Griffon Spectre", family: "griffon",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0b64d1c988e9863bf08810fd36047b50626182795da99f0e2df8f5b48ad85230",
    referencedGeometrySHA256: "f132d3229d67b58a29dfda4707dcbc17537163ab31da7d20a77645c8fcc3268e",
    performance: .init(
      cargo: 20, speed: 53.0, acceleration: 14.1,
      energy: 220, recharge: 3.9, roll: 1.35,
      pitch: 1.19, yaw: 1.11, shield: 190,
      shieldRecharge: 1.6, fuel: 130, jump: 11.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 10, price: 316000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh074: OriginalFleetR3Contract = .init(
    id: "SH074", name: "Dzo", family: "dzo",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0711a5d64904da6ecc41ecb46cf978dc5065321ce4757c7390c0172b6b4d6822",
    referencedGeometrySHA256: "85d5ac77d76ea8543428b015aca6c8a0025e332ca69f5f6900f83092cda40459",
    performance: .init(
      cargo: 420, speed: 20.8, acceleration: 4.82,
      energy: 740, recharge: 5.3, roll: 0.37,
      pitch: 0.327, yaw: 0.301, shield: 470,
      shieldRecharge: 1.7, fuel: 150, jump: 11.0,
      spool: 14, missiles: 5, facings: 3,
      cargoExpansion: 160, price: 538000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 6, intrinsicCrewPlaces: 6,
      nativeAutonomous: false, nativeCrew: 6,
      conversionCrew: 6, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 84),
    fitting: .init(
      equipmentUnits: 36, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh075: OriginalFleetR3Contract = .init(
    id: "SH075", name: "Dzo Mk II", family: "dzo",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "3f6f6790a6ba48313118d7ab8cfc191b05c03f42a1d1c2596c3e1c007e1b991a",
    referencedGeometrySHA256: "6f88aa80d06f3d269d925fde3ad1add3eaa655a64df229e30c0af37bff39397d",
    performance: .init(
      cargo: 480, speed: 19.8, acceleration: 4.73,
      energy: 880, recharge: 6.0, roll: 0.353,
      pitch: 0.31, yaw: 0.292, shield: 510,
      shieldRecharge: 1.78, fuel: 150, jump: 10.0,
      spool: 14, missiles: 6, facings: 7,
      cargoExpansion: 175, price: 606000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 8, intrinsicCrewPlaces: 8,
      nativeAutonomous: false, nativeCrew: 8,
      conversionCrew: 8, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 96),
    fitting: .init(
      equipmentUnits: 40, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh076: OriginalFleetR3Contract = .init(
    id: "SH076", name: "Hog", family: "hog",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "799045a816586eff2fe721601e0d5a8ab46a3acc1d7e09351d423b5b39087b0c",
    referencedGeometrySHA256: "5e8fa307307bf36b5d5c52c556d92157091ed05f74765d06c241e386f14a72d5",
    performance: .init(
      cargo: 450, speed: 19.0, acceleration: 4.56,
      energy: 900, recharge: 5.8, roll: 0.344,
      pitch: 0.301, yaw: 0.284, shield: 540,
      shieldRecharge: 1.7, fuel: 130, jump: 8.0,
      spool: 14, missiles: 6, facings: 15,
      cargoExpansion: 165, price: 587000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 7, intrinsicCrewPlaces: 7,
      nativeAutonomous: false, nativeCrew: 7,
      conversionCrew: 7, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 90),
    fitting: .init(
      equipmentUnits: 38, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh077: OriginalFleetR3Contract = .init(
    id: "SH077", name: "Tamaraw", family: "tamaraw",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "b47b47578defd762547b0f25c6c64697cc340eadb534b0543b3d0dd89325c9dc",
    referencedGeometrySHA256: "9d21c021df62f73a9f15b11455f88439fd178cca60ac72d99e1253f0339ac441",
    performance: .init(
      cargo: 380, speed: 23.2, acceleration: 4.82,
      energy: 690, recharge: 5.0, roll: 0.37,
      pitch: 0.327, yaw: 0.301, shield: 470,
      shieldRecharge: 1.7, fuel: 150, jump: 10.0,
      spool: 14, missiles: 5, facings: 3,
      cargoExpansion: 160, price: 508000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 5, intrinsicCrewPlaces: 5,
      nativeAutonomous: false, nativeCrew: 5,
      conversionCrew: 5, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 76),
    fitting: .init(
      equipmentUnits: 32, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh078: OriginalFleetR3Contract = .init(
    id: "SH078", name: "Oryx Voyager", family: "oryx-voyager",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "ec614af96ca542fc5ad47f512bd5d3a88aa04b46f86fa5a0cd7f72b7d00031b9",
    referencedGeometrySHA256: "ca5f64a1c396f81cc062345f1659e36113ee6c81a127ac7d7dad872452184e6c",
    performance: .init(
      cargo: 80, speed: 36.5, acceleration: 11.5,
      energy: 320, recharge: 5.2, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 230,
      shieldRecharge: 1.7, fuel: 150, jump: 13.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 15, price: 365000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 16),
    fitting: .init(
      equipmentUnits: 32, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh079: OriginalFleetR3Contract = .init(
    id: "SH079", name: "Carabao Freighter", family: "carabao",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f1e712171f85fce0e633fbff4dfe99e69eb77e07f52eaef46411cb7025e62024",
    referencedGeometrySHA256: "5c3b5974e095cfe792ce8b518267cd5d848b4a36ec9ef37e04dabaacddea6c79",
    performance: .init(
      cargo: 786, speed: 19.6, acceleration: 4.8,
      energy: 970, recharge: 6.4, roll: 0.37,
      pitch: 0.33, yaw: 0.3, shield: 550,
      shieldRecharge: 1.7, fuel: 130, jump: 7.0,
      spool: 16, missiles: 7, facings: 7,
      cargoExpansion: 315, price: 696000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 9, intrinsicCrewPlaces: 9,
      nativeAutonomous: false, nativeCrew: 9,
      conversionCrew: 9, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 157),
    fitting: .init(
      equipmentUnits: 44, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh080: OriginalFleetR3Contract = .init(
    id: "SH080", name: "Carabao Highliner", family: "carabao",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "e03e647a7312e9caa8dd86cedffa6df274ed4c5ef76b03ff526b97d7eb135782",
    referencedGeometrySHA256: "e853662580668e4a89c37f46ffd6a49c69aee98b3f324dd0bc77acce960ea009",
    performance: .init(
      cargo: 680, speed: 21.0, acceleration: 4.13,
      energy: 1020, recharge: 6.8, roll: 0.318,
      pitch: 0.284, yaw: 0.258, shield: 550,
      shieldRecharge: 1.7, fuel: 130, jump: 10.0,
      spool: 16, missiles: 6, facings: 7,
      cargoExpansion: 315, price: 709000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 10, intrinsicCrewPlaces: 10,
      nativeAutonomous: false, nativeCrew: 10,
      conversionCrew: 10, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 136),
    fitting: .init(
      equipmentUnits: 48, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["lifeSupportService", "passengerCabin"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh081: OriginalFleetR3Contract = .init(
    id: "SH081", name: "Jaguar", family: "jaguar",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "57ea57735c368d832a43ed1bade04accf4bf71577dd3439a876a45f610f366f4",
    referencedGeometrySHA256: "22f8667772b9461bdd59bb7f6d9ef26bf49303cf174ab1ef5415f34277d72b0d",
    performance: .init(
      cargo: 144, speed: 23.3, acceleration: 5.4,
      energy: 1480, recharge: 11.5, roll: 0.43,
      pitch: 0.38, yaw: 0.35, shield: 620,
      shieldRecharge: 2.0, fuel: 140, jump: 7.0,
      spool: 18, missiles: 10, facings: 15,
      cargoExpansion: 60, price: 0, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 24, intrinsicCrewPlaces: 24,
      nativeAutonomous: false, nativeCrew: 24,
      conversionCrew: 24, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 28),
    fitting: .init(
      equipmentUnits: 58, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: nil)


  private static let sh082: OriginalFleetR3Contract = .init(
    id: "SH082", name: "Cheetah", family: "cheetah",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "ccbea073da64824196b980c1baeb2163869dc2f75ea780f19056b18cc520bf93",
    referencedGeometrySHA256: "1588cff096e99efafd72688aeb3f764080c36517658a682c296f0b872ca33f49",
    performance: .init(
      cargo: 14, speed: 57.0, acceleration: 19.49,
      energy: 250, recharge: 3.8, roll: 1.714,
      pitch: 1.512, yaw: 1.4, shield: 240,
      shieldRecharge: 1.9, fuel: 120, jump: 9.0,
      spool: 10, missiles: 4, facings: 1,
      cargoExpansion: 5, price: 310000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 1,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh083: OriginalFleetR3Contract = .init(
    id: "SH083", name: "Hare Explorer", family: "hare",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "bb7350c1b3035b058625a398139fc15df0146e1c760a640e5ee9bd552ea88095",
    referencedGeometrySHA256: "aa694d328600f03ee21f7f9c8496b229347e2e6c1c4d0f5d1da250aa9392ac0e",
    performance: .init(
      cargo: 36, speed: 45.0, acceleration: 11.5,
      energy: 240, recharge: 4.4, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 230,
      shieldRecharge: 1.7, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 15, price: 324000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 7),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh084: OriginalFleetR3Contract = .init(
    id: "SH084", name: "Llama", family: "llama",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "d80ac8f22ee304bb730d16d2206a660168cb0a762a668eec0775a32c45d21467",
    referencedGeometrySHA256: "63e88e1098ea8b59080a254675819a1330bf1ce9a274e2df28be4ca48d2a716d",
    performance: .init(
      cargo: 62, speed: 36.5, acceleration: 11.0,
      energy: 240, recharge: 3.7, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 220,
      shieldRecharge: 1.5, fuel: 130, jump: 11.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 20, price: 300000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 12),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh085: OriginalFleetR3Contract = .init(
    id: "SH085", name: "Laggar", family: "laggar",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "fdf156b257cfa0ea113403c0b85b45d53ee87af25a56f5b891a06f448e92804f",
    referencedGeometrySHA256: "1e1fad73a50483702f87fcbb64839d8954604b0751dcf4cede6283bb6197a85c",
    performance: .init(
      cargo: 18, speed: 54.1, acceleration: 17.6,
      energy: 280, recharge: 4.4, roll: 1.55,
      pitch: 1.36, yaw: 1.27, shield: 230,
      shieldRecharge: 1.9, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 5, price: 335000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh086: OriginalFleetR3Contract = .init(
    id: "SH086", name: "Alpaca", family: "alpaca",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "845645594b80228376299805b54e24044ddca1078a3bb573727de61f64fa2fdd",
    referencedGeometrySHA256: "f1d7fc3e040aaf7f480ed0dadb32b35a3501c20b2c99452edf194c4bec80d0c0",
    performance: .init(
      cargo: 60, speed: 35.8, acceleration: 9.4,
      energy: 290, recharge: 4.0, roll: 0.84,
      pitch: 0.74, yaw: 0.69, shield: 260,
      shieldRecharge: 1.5, fuel: 130, jump: 10.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 25, price: 314000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 12),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh087: OriginalFleetR3Contract = .init(
    id: "SH087", name: "Elk", family: "elk",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "ee415f26d288d66cbc448c51a5c15bcd362acd0e3e4220d085c5e2162a695b0e",
    referencedGeometrySHA256: "63298c43a80e0134b18cb10c9bc93cde9abcda8158db1094b036235a14270e94",
    performance: .init(
      cargo: 70, speed: 34.8, acceleration: 9.4,
      energy: 320, recharge: 3.8, roll: 0.84,
      pitch: 0.74, yaw: 0.69, shield: 260,
      shieldRecharge: 1.5, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 7,
      cargoExpansion: 25, price: 321000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 14),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh088: OriginalFleetR3Contract = .init(
    id: "SH088", name: "Springbok Starliner", family: "springbok",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a68eca7fb52dba02989f82a1c23a1201ac4ce28b2125f9a6a357fd4eb785ee82",
    referencedGeometrySHA256: "8382b438252441ae6bb373bf307f7d341ec4d5d16fc525ab8d3edfa8cefbb8de",
    performance: .init(
      cargo: 200, speed: 29.0, acceleration: 9.46,
      energy: 470, recharge: 5.8, roll: 0.869,
      pitch: 0.765, yaw: 0.714, shield: 220,
      shieldRecharge: 1.7, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 15, price: 434000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 8, intrinsicCrewPlaces: 8,
      nativeAutonomous: false, nativeCrew: 8,
      conversionCrew: 8, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 40),
    fitting: .init(
      equipmentUnits: 46, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["lifeSupportService", "passengerCabin"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh089: OriginalFleetR3Contract = .init(
    id: "SH089", name: "Antelope", family: "antelope",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "92cdce3357540ac17a213a8f5f034d0fc58f7af6e3b541539c951d45e0439d65",
    referencedGeometrySHA256: "75eaa16f5496ef1164f9665d1ee98da814d309562421addb3f86e78b778ed4d5",
    performance: .init(
      cargo: 52, speed: 41.0, acceleration: 11.0,
      energy: 220, recharge: 3.0, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 220,
      shieldRecharge: 1.5, fuel: 130, jump: 10.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 20, price: 282000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 10),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh090: OriginalFleetR3Contract = .init(
    id: "SH090", name: "Elephant", family: "elephant",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "af105a6530de697eecb95e7efbc58b833aae9f3ee55d7a7c78f3ce4ca25842c3",
    referencedGeometrySHA256: "697cff048bc9b9af4f8cd02948cfc2877d2684109797c6477a2a34854a2952f9",
    performance: .init(
      cargo: 96, speed: 29.5, acceleration: 9.12,
      energy: 440, recharge: 4.2, roll: 0.817,
      pitch: 0.722, yaw: 0.671, shield: 230,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 6, facings: 15,
      cargoExpansion: 20, price: 364000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 19),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh091: OriginalFleetR3Contract = .init(
    id: "SH091", name: "Gopher", family: "gopher",
    classification: "miner", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "eda1e9dceb8b3594fa99bb2d8ed9f21e2e7fab320ee1ae3dc154b1b82aa52f81",
    referencedGeometrySHA256: "fd2fe452563dc9641dd4e48d5bf2beebec411ab225041c4da8c2ff97d36366e3",
    performance: .init(
      cargo: 100, speed: 29.5, acceleration: 8.3,
      energy: 360, recharge: 5.0, roll: 0.67,
      pitch: 0.59, yaw: 0.55, shield: 310,
      shieldRecharge: 1.8, fuel: 120, jump: 10.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 45, price: 345000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 20),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop", "surveyArray"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh092: OriginalFleetR3Contract = .init(
    id: "SH092", name: "Aurochs", family: "aurochs",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "160a1fb62c14ac65098bf97be6ef956c7c791e93d1efe16869cf2368551ff78a",
    referencedGeometrySHA256: "5636b640e4ece28c7985d56f9643e6f6a24e011fd826ea085f1e811ccf5d30d7",
    performance: .init(
      cargo: 64, speed: 35.2, acceleration: 11.0,
      energy: 300, recharge: 4.1, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 220,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 5, facings: 7,
      cargoExpansion: 20, price: 315000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 12),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh093: OriginalFleetR3Contract = .init(
    id: "SH093", name: "Giraffe Liner", family: "giraffe",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "763c3badc87a28e0d9c431d0ddc417297f0cc99066f83cf33e6bf9fe1fd96a8e",
    referencedGeometrySHA256: "a19630347a9a31555430539402ad797754f16a30d51eceba6b27f7214e1ceab7",
    performance: .init(
      cargo: 120, speed: 33.0, acceleration: 9.72,
      energy: 380, recharge: 5.0, roll: 0.843,
      pitch: 0.74, yaw: 0.688, shield: 250,
      shieldRecharge: 1.7, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 10, price: 379000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 5, intrinsicCrewPlaces: 5,
      nativeAutonomous: false, nativeCrew: 5,
      conversionCrew: 5, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 24),
    fitting: .init(
      equipmentUnits: 38, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["lifeSupportService", "passengerCabin"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh094: OriginalFleetR3Contract = .init(
    id: "SH094", name: "Shikra", family: "shikra",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0a2256276dbfcf8d5490c3dfaffb9446a00be5337e7b591d76f4d2c245e0c175",
    referencedGeometrySHA256: "1aa22f477556aba2ff1265a82c193cc6dcd921813c3690c3f8c89018951a05b2",
    performance: .init(
      cargo: 16, speed: 46.0, acceleration: 14.0,
      energy: 370, recharge: 5.8, roll: 1.15,
      pitch: 1.01, yaw: 0.94, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 10.0,
      spool: 12, missiles: 6, facings: 3,
      cargoExpansion: 5, price: 365000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh095: OriginalFleetR3Contract = .init(
    id: "SH095", name: "Shikra Interdictor", family: "shikra",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "4f14b1d022195ef57d3b35966b902b8afd2f192d8326e1f3ba9c97cc1dcf09b4",
    referencedGeometrySHA256: "441934d5018c83268f327097a52cd3add8482aab0d433dc91aa3d7466a0ca3b2",
    performance: .init(
      cargo: 12, speed: 43.0, acceleration: 14.0,
      energy: 520, recharge: 7.5, roll: 1.15,
      pitch: 1.01, yaw: 0.94, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 9.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 5, price: 420000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM", "EMP"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh096: OriginalFleetR3Contract = .init(
    id: "SH096", name: "Wisent", family: "wisent",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f487b23ff82c66f2dc67f018e81e6c2afdd78176c796ff92565892b1737fa6d4",
    referencedGeometrySHA256: "3ed7051c06c65f78d7f58e7fdfc875b61aa54c616d8907aa9e37cf470ec69072",
    performance: .init(
      cargo: 188, speed: 27.2, acceleration: 7.7,
      energy: 420, recharge: 4.4, roll: 0.63,
      pitch: 0.55, yaw: 0.52, shield: 360,
      shieldRecharge: 1.7, fuel: 120, jump: 9.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 75, price: 372000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 37),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh097: OriginalFleetR3Contract = .init(
    id: "SH097", name: "Wisent Mk II", family: "wisent",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "e669e500f1fa5a3ff5ee65470d2095c3d550ff75233c019f275fcb66c60baca4",
    referencedGeometrySHA256: "c5bff7a81f87ad4b6ad0a05ba8e689fc1114f1812e6e85461b09a4c15aac2b0a",
    performance: .init(
      cargo: 224, speed: 25.6, acceleration: 7.5,
      energy: 490, recharge: 4.9, roll: 0.61,
      pitch: 0.54, yaw: 0.5, shield: 390,
      shieldRecharge: 1.78, fuel: 120, jump: 9.0,
      spool: 12, missiles: 6, facings: 7,
      cargoExpansion: 80, price: 410000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 44),
    fitting: .init(
      equipmentUnits: 30, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh098: OriginalFleetR3Contract = .init(
    id: "SH098", name: "Anoa", family: "anoa",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "ed1addd7a35c62ff86bfb2af5fe3c4b83f826b8f98d36b003f48e050c0e48f5a",
    referencedGeometrySHA256: "ed66a28884ae514dbbd74b07e9792b96936328b549edc9d1cac9bcc2966d7e98",
    performance: .init(
      cargo: 330, speed: 25.1, acceleration: 5.8,
      energy: 620, recharge: 5.0, roll: 0.44,
      pitch: 0.39, yaw: 0.36, shield: 440,
      shieldRecharge: 1.7, fuel: 130, jump: 10.0,
      spool: 14, missiles: 5, facings: 3,
      cargoExpansion: 160, price: 477000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 66),
    fitting: .init(
      equipmentUnits: 30, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh099: OriginalFleetR3Contract = .init(
    id: "SH099", name: "Ox", family: "ox",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "4576979bb379ce9e5560be83fbe2085973136518104c7f144ed9fe1aaaa869cc",
    referencedGeometrySHA256: "b80ded1ddf179eab04e383c13a2017d0f07c990f5c69daa5de084ed9372391d9",
    performance: .init(
      cargo: 440, speed: 22.6, acceleration: 5.6,
      energy: 710, recharge: 5.2, roll: 0.43,
      pitch: 0.38, yaw: 0.35, shield: 470,
      shieldRecharge: 1.7, fuel: 130, jump: 8.0,
      spool: 14, missiles: 6, facings: 7,
      cargoExpansion: 175, price: 523000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 6, intrinsicCrewPlaces: 6,
      nativeAutonomous: false, nativeCrew: 6,
      conversionCrew: 6, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 88),
    fitting: .init(
      equipmentUnits: 34, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh100: OriginalFleetR3Contract = .init(
    id: "SH100", name: "Ox Mk II", family: "ox",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "51052443fd83b5480ab4b35a91cda57dc820284ed4b128430a567a1063d48ea3",
    referencedGeometrySHA256: "22cb04f635bcc998ad623853f1a147e087eade2fc3a0da0414d3c0a6b884f5e7",
    performance: .init(
      cargo: 510, speed: 20.8, acceleration: 5.5,
      energy: 840, recharge: 5.9, roll: 0.41,
      pitch: 0.36, yaw: 0.34, shield: 510,
      shieldRecharge: 1.78, fuel: 130, jump: 8.0,
      spool: 14, missiles: 7, facings: 15,
      cargoExpansion: 195, price: 589000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 8, intrinsicCrewPlaces: 8,
      nativeAutonomous: false, nativeCrew: 8,
      conversionCrew: 8, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 102),
    fitting: .init(
      equipmentUnits: 38, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh101: OriginalFleetR3Contract = .init(
    id: "SH101", name: "Cavy Racer", family: "cavy",
    classification: "leisure", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "1b9d47d25ced3e9ecdde52fe636747d3e456b959fa76be89d97b8de0af316019",
    referencedGeometrySHA256: "82a26071a46ad1fc2cd4827ee8387e8cfa7d824c738cf29afbde35df740a042b",
    performance: .init(
      cargo: 10, speed: 61.0, acceleration: 14.22,
      energy: 170, recharge: 3.0, roll: 1.232,
      pitch: 1.086, yaw: 1.008, shield: 220,
      shieldRecharge: 1.7, fuel: 140, jump: 10.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 10, price: 288000, workTools: []
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 14, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "rescueReceiver", "cargoScoop", "auxiliaryFuelTank"],
      recommendedRoleKit: ["flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh102: OriginalFleetR3Contract = .init(
    id: "SH102", name: "Dhole Haven", family: "dhole",
    classification: "station", objectKind: .station,
    origin: .human,
    environment: .init(
      playerCrewRequired: false, purchasePolicy: .never,
      physicalService: .stationServices),
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "71c01d62bbb79cc605c6be8ef8f3cbf3e48e788969ecd7b4b3b0ddcac02e2071",
    referencedGeometrySHA256: "1af4b8817f6a2abc85c6445e4131f3571a135cde24f95125c61ce16be9d23723",
    performance: nil,
    accommodation: nil,
    fitting: nil,
    acquisition: nil)


  private static let sh103: OriginalFleetR3Contract = .init(
    id: "SH103", name: "Redtail Mk III", family: "redtail",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "a867f71cdc9693f245c54a8c63d15a657a00c6ba7db782cfa384b6f6ee41ccdf",
    referencedGeometrySHA256: "39ec7a78c9da5b4ff652255b4d278d1169821bb27941e1d34ccc2f97ce61eb90",
    performance: .init(
      cargo: 26, speed: 51.4, acceleration: 13.93,
      energy: 430, recharge: 6.2, roll: 1.135,
      pitch: 0.998, yaw: 0.929, shield: 270,
      shieldRecharge: 2.09, fuel: 130, jump: 9.0,
      spool: 13, missiles: 8, facings: 15,
      cargoExpansion: 10, price: 409000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 3,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh104: OriginalFleetR3Contract = .init(
    id: "SH104", name: "Wildebeest", family: "wildebeest",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "771cf33fa828f8a6d26daec429a61baf705393c9ad9c5651198a9d8f144603e9",
    referencedGeometrySHA256: "794a626f1d98fc2437c26fba3a57eb6c2aa923ac8424174fe9ea613bf7553ee8",
    performance: .init(
      cargo: 78, speed: 30.8, acceleration: 9.4,
      energy: 370, recharge: 4.6, roll: 0.84,
      pitch: 0.74, yaw: 0.69, shield: 260,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 25, price: 341000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 15),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "salvageCutter", "rescueReceiver", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh105: OriginalFleetR3Contract = .init(
    id: "SH105", name: "Tapir Shuttle", family: "tapir",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "c3e044e23e9f4c87d9d9f06318d5bda37e2a5d79d2c69a4e727a99039701c489",
    referencedGeometrySHA256: "daf3fa9551a9f488edbcfd5ee164507616cf120b43f912c07171a3ddead2d96e",
    performance: .init(
      cargo: 300, speed: 23.0, acceleration: 5.4,
      energy: 680, recharge: 5.6, roll: 0.42,
      pitch: 0.37, yaw: 0.34, shield: 500,
      shieldRecharge: 1.7, fuel: 130, jump: 9.0,
      spool: 14, missiles: 4, facings: 3,
      cargoExpansion: 175, price: 491000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 5, intrinsicCrewPlaces: 5,
      nativeAutonomous: false, nativeCrew: 5,
      conversionCrew: 5, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 60),
    fitting: .init(
      equipmentUnits: 38, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["lifeSupportService", "passengerCabin"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh106: OriginalFleetR3Contract = .init(
    id: "SH106", name: "Tapir Mk II", family: "tapir",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "3afaae56e461c018053ee63f4629b4ec9412fa0fa34d80e954d8dd315a5a3ff3",
    referencedGeometrySHA256: "20131f3bbc888dc52c51e0e950a50a7b2ee72ce62c47cf42dae0151d5db8fc65",
    performance: .init(
      cargo: 360, speed: 21.5, acceleration: 5.2,
      energy: 800, recharge: 6.2, roll: 0.41,
      pitch: 0.36, yaw: 0.34, shield: 540,
      shieldRecharge: 1.78, fuel: 130, jump: 10.0,
      spool: 14, missiles: 5, facings: 7,
      cargoExpansion: 195, price: 558000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 7, intrinsicCrewPlaces: 7,
      nativeAutonomous: false, nativeCrew: 7,
      conversionCrew: 7, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 72),
    fitting: .init(
      equipmentUnits: 44, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["lifeSupportService", "passengerCabin"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh107: OriginalFleetR3Contract = .init(
    id: "SH107", name: "Magpie", family: "magpie",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0469be178a7140df3f8643b275580e9fee75d02a5843f07d8274c9747aaba905",
    referencedGeometrySHA256: "9f8ba7417e607a8ce5c16433e673249754853ef57312ff2b5a1ce6bbeecd73e6",
    performance: .init(
      cargo: 26, speed: 50.0, acceleration: 15.0,
      energy: 240, recharge: 3.8, roll: 1.45,
      pitch: 1.28, yaw: 1.19, shield: 170,
      shieldRecharge: 1.6, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 10, price: 324000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["salvageBeam", "salvageCutter", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh108: OriginalFleetR3Contract = .init(
    id: "SH108", name: "Besra", family: "besra",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "e6dd044e8985abfeb14b7a23296389c5acbb210e901bebe64aa4cbbdc49c4de8",
    referencedGeometrySHA256: "ef7d78789eed53b721c6f9417abe5f79a0394613540ff901d8af1fd9c76e13f1",
    performance: .init(
      cargo: 24, speed: 47.8, acceleration: 15.0,
      energy: 390, recharge: 5.4, roll: 1.26,
      pitch: 1.11, yaw: 1.03, shield: 270,
      shieldRecharge: 1.9, fuel: 130, jump: 11.0,
      spool: 12, missiles: 5, facings: 7,
      cargoExpansion: 10, price: 380000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["salvageCutter", "cargoScoop", "rescueReceiver"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh109: OriginalFleetR3Contract = .init(
    id: "SH109", name: "Hippo", family: "hippo",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f5ddce9ce6d78f9000775b8dc12adae3d8ccfb183618418e43babd944315913f",
    referencedGeometrySHA256: "4f403f4d2f7e675428b853a67069778a3e501890b4444901a671e19dc130f02e",
    performance: .init(
      cargo: 82, speed: 30.0, acceleration: 10.4,
      energy: 410, recharge: 4.0, roll: 0.92,
      pitch: 0.81, yaw: 0.75, shield: 210,
      shieldRecharge: 1.5, fuel: 130, jump: 8.0,
      spool: 12, missiles: 6, facings: 15,
      cargoExpansion: 25, price: 341000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 16),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh110: OriginalFleetR3Contract = .init(
    id: "SH110", name: "Leopard Fighter", family: "leopard",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "5673b36946ecb6cdcfeea77976e2bad35483c8124e761ab4374a778e6696b651",
    referencedGeometrySHA256: "844723bc0ce222cfa70ebb6ec53d25130b9bd39a14cda2548b5c806ca1255318",
    performance: .init(
      cargo: 18, speed: 43.0, acceleration: 15.4,
      energy: 450, recharge: 5.7, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 8.0,
      spool: 12, missiles: 8, facings: 7,
      cargoExpansion: 5, price: 383000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: true),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh111: OriginalFleetR3Contract = .init(
    id: "SH111", name: "Puma", family: "puma",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "e4e13abef63d92f973cd41c2b15ce806754ddd1442cd34e65cc5e0e61bab4eef",
    referencedGeometrySHA256: "8eef0062ca13fac1a993ab12c71a536dd25a0569d94cf14981dbd33afa308dad",
    performance: .init(
      cargo: 12, speed: 53.0, acceleration: 14.6,
      energy: 300, recharge: 4.8, roll: 1.17,
      pitch: 1.03, yaw: 0.96, shield: 270,
      shieldRecharge: 2.0, fuel: 120, jump: 9.0,
      spool: 12, missiles: 6, facings: 1,
      cargoExpansion: 5, price: 335000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh112: OriginalFleetR3Contract = .init(
    id: "SH112", name: "Larvaal Warden", family: "larvaal-warden",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "cbcdc5e45436d78d490b00f76b8e3f430e963fb5204cd6162f51fc802ad8674b",
    referencedGeometrySHA256: "32f71d1edac325cffe3299c12c89d87ade907c42f81986820622127ca6f716e1",
    performance: .init(
      cargo: 28, speed: 45.0, acceleration: 17.0,
      energy: 470, recharge: 6.4, roll: 1.3,
      pitch: 1.14, yaw: 1.07, shield: 310,
      shieldRecharge: 2.1, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 7,
      cargoExpansion: 10, price: 408000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh113: OriginalFleetR3Contract = .init(
    id: "SH113", name: "Larvaal Ravager", family: "larvaal-ravager",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "1a86eadf7eae395da5bf6f1329cc56d4bf24e14f97bfa34a39b598ed6ff3062f",
    referencedGeometrySHA256: "5e9d7670be4b1997ad270d55f1cbecb1009eafc697ab4ddd2df1b34cc7a9e007",
    performance: .init(
      cargo: 22, speed: 49.0, acceleration: 17.0,
      energy: 420, recharge: 5.8, roll: 1.3,
      pitch: 1.14, yaw: 1.07, shield: 310,
      shieldRecharge: 2.1, fuel: 130, jump: 9.0,
      spool: 12, missiles: 7, facings: 3,
      cargoExpansion: 10, price: 388000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 2,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh114: OriginalFleetR3Contract = .init(
    id: "SH114", name: "Larvaal Sentinel", family: "larvaal-sentinel",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "52fa731ac2d363006a35c0dd4a7318b5e94cf51892f0e6abae6f70bb01c94143",
    referencedGeometrySHA256: "d999e2f3324a8a593191765c20fcd48c03ed17fefa102d4ed1156710685d51f0",
    performance: .init(
      cargo: 24, speed: 43.0, acceleration: 18.7,
      energy: 520, recharge: 7.0, roll: 1.49,
      pitch: 1.31, yaw: 1.22, shield: 290,
      shieldRecharge: 2.1, fuel: 130, jump: 10.0,
      spool: 12, missiles: 4, facings: 15,
      cargoExpansion: 10, price: 423000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 28, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh115: OriginalFleetR3Contract = .init(
    id: "SH115", name: "Larvaal Lancer", family: "larvaal-lancer",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "6ed36170e9691f0f12aaf19b49eb0eeee314135c1931af965806c823dac7bf45",
    referencedGeometrySHA256: "9b38f9641e6503b8aa2a7430f81d91c6f6870bc28f0c9dc13baee16397b01ab2",
    performance: .init(
      cargo: 18, speed: 55.0, acceleration: 20.94,
      energy: 340, recharge: 4.8, roll: 1.669,
      pitch: 1.467, yaw: 1.366, shield: 290,
      shieldRecharge: 2.1, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 1,
      cargoExpansion: 10, price: 360000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh116: OriginalFleetR3Contract = .init(
    id: "SH116", name: "Larvaal Broodlord", family: "larvaal-broodlord",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0ac287f26c28101ac8999e38dc9a7b26a145370ccdaa248ba6d7eed04afe1fb2",
    referencedGeometrySHA256: "62153467e98fbf3e98a095a50bfc536227d322345d74a6a048e720b65c9fed73",
    performance: .init(
      cargo: 56, speed: 36.0, acceleration: 15.6,
      energy: 610, recharge: 7.5, roll: 1.25,
      pitch: 1.1, yaw: 1.02, shield: 320,
      shieldRecharge: 2.1, fuel: 130, jump: 11.0,
      spool: 12, missiles: 4, facings: 7,
      cargoExpansion: 15, price: 463000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 5, intrinsicCrewPlaces: 5,
      nativeAutonomous: false, nativeCrew: 5,
      conversionCrew: 5, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 11),
    fitting: .init(
      equipmentUnits: 34, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "salvageCutter", "rescueReceiver", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh117: OriginalFleetR3Contract = .init(
    id: "SH117", name: "Larvaal Provoker", family: "larvaal-provoker",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "d3bd98bd547c59cf62b6c1891f1fe3554754a140796f1dbb2060b89369ac6442",
    referencedGeometrySHA256: "9a48f2e812240a38f2b90ea0333eda83f8032b0472dcba9fcb694931cc0a902e",
    performance: .init(
      cargo: 20, speed: 51.0, acceleration: 18.0,
      energy: 420, recharge: 6.0, roll: 1.37,
      pitch: 1.21, yaw: 1.12, shield: 300,
      shieldRecharge: 2.1, fuel: 130, jump: 9.0,
      spool: 12, missiles: 7, facings: 3,
      cargoExpansion: 10, price: 393000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 2,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh118: OriginalFleetR3Contract = .init(
    id: "SH118", name: "Larvaal Reaver", family: "larvaal-reaver",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "960a541ea826d2cb8634794e52772874570d4d9e7dc5dc949527ec1db41d80f7",
    referencedGeometrySHA256: "65a9c46ec8547b76bc94aa261668b05f6a651bd39ee735c671d90f338be6f0e6",
    performance: .init(
      cargo: 26, speed: 48.0, acceleration: 18.0,
      energy: 480, recharge: 6.2, roll: 1.37,
      pitch: 1.21, yaw: 1.12, shield: 300,
      shieldRecharge: 2.1, fuel: 130, jump: 10.0,
      spool: 12, missiles: 6, facings: 7,
      cargoExpansion: 10, price: 418000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh119: OriginalFleetR3Contract = .init(
    id: "SH119", name: "Larvaal Wraith", family: "larvaal-wraith",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f44ea27d0015ea2fdc28491277d4d5fc2625f66a597670db8351c68211dd91f3",
    referencedGeometrySHA256: "3d7d4b77a9f9c44ff9b15c3cf379bf68b4ca0106628a59eaae978e59394fa7d1",
    performance: .init(
      cargo: 18, speed: 56.0, acceleration: 17.7,
      energy: 330, recharge: 5.0, roll: 1.33,
      pitch: 1.17, yaw: 1.09, shield: 290,
      shieldRecharge: 2.1, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 10, price: 373000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh120: OriginalFleetR3Contract = .init(
    id: "SH120", name: "Larvaal Seeker", family: "larvaal-seeker",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "b510e195c30517d6ad5cd4a04277612fdb4800198dffc8f01c695a95573f2eaf",
    referencedGeometrySHA256: "4968b8ce9ac6fc316fe67b58dd04e7fb2297ab8d40aa20e8322a26540437fedc",
    performance: .init(
      cargo: 34, speed: 45.0, acceleration: 15.6,
      energy: 410, recharge: 6.8, roll: 1.25,
      pitch: 1.1, yaw: 1.02, shield: 320,
      shieldRecharge: 2.1, fuel: 150, jump: 13.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 15, price: 411000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 28, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh121: OriginalFleetR3Contract = .init(
    id: "SH121", name: "Larvaal Mender", family: "larvaal-mender",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "48146ed3f79c033f8b3b6342c9642cfaaf62c949ec6a479e28a22e0a88a6d270",
    referencedGeometrySHA256: "f205cf86f74b26cc75542f65a940aa92f287d24c58d53d4e250ba6e24a05218b",
    performance: .init(
      cargo: 48, speed: 39.0, acceleration: 16.0,
      energy: 570, recharge: 8.2, roll: 1.21,
      pitch: 1.06, yaw: 0.99, shield: 350,
      shieldRecharge: 2.1, fuel: 130, jump: 11.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 10, price: 460000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 9),
    fitting: .init(
      equipmentUnits: 34, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["salvageCutter", "cargoScoop", "rescueReceiver"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh122: OriginalFleetR3Contract = .init(
    id: "SH122", name: "Larvaal Harvester", family: "larvaal-harvester",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "65f2ecb53a56251a6b3e38f5d459f636732bfdb017ae341a32aef0361d32d6f3",
    referencedGeometrySHA256: "c0392366f0a900584961def6feed02002cced6a9760fa0178518f2f020600556",
    performance: .init(
      cargo: 100, speed: 32.0, acceleration: 18.0,
      energy: 540, recharge: 7.4, roll: 1.37,
      pitch: 1.21, yaw: 1.12, shield: 300,
      shieldRecharge: 2.1, fuel: 130, jump: 10.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 10, price: 439000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 20),
    fitting: .init(
      equipmentUnits: 36, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh123: OriginalFleetR3Contract = .init(
    id: "SH123", name: "Larvaal Sovereign", family: "larvaal-sovereign",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "113645d823bf6ad3e81a10fad4e854a0e64363cc6454fc23332cded47a203d6a",
    referencedGeometrySHA256: "a430c5e8946db1d2f27d5030ae3f245f0838e52f2dadf1409323a16fc1c67499",
    performance: .init(
      cargo: 180, speed: 27.7, acceleration: 7.2,
      energy: 1660, recharge: 9.5, roll: 0.52,
      pitch: 0.46, yaw: 0.43, shield: 620,
      shieldRecharge: 2.1, fuel: 150, jump: 8.0,
      spool: 18, missiles: 8, facings: 15,
      cargoExpansion: 70, price: 0, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 18, intrinsicCrewPlaces: 18,
      nativeAutonomous: false, nativeCrew: 18,
      conversionCrew: 18, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 36),
    fitting: .init(
      equipmentUnits: 64, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: nil)


  private static let sh124: OriginalFleetR3Contract = .init(
    id: "SH124", name: "Larvaal Warship", family: "larvaal-warship",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "851502c15a6922797e9c650e8a126fd73ce7ccc76f5e1419a870625c72abe21e",
    referencedGeometrySHA256: "1715f8fc7da8e0a7e3c0c17534087477b443508c174a0a4da4eb158829438732",
    performance: .init(
      cargo: 28, speed: 40.0, acceleration: 14.62,
      energy: 720, recharge: 8.6, roll: 1.118,
      pitch: 0.98, yaw: 0.92, shield: 310,
      shieldRecharge: 2.1, fuel: 130, jump: 9.0,
      spool: 12, missiles: 8, facings: 15,
      cargoExpansion: 10, price: 503000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 30, utilityMounts: 2,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh125: OriginalFleetR3Contract = .init(
    id: "SH125", name: "Larvaal Drone", family: "larvaal-drone",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "66671c43983362d99fa0ecbc361fe224db0a7ac50799fd7d35cedb4d3fa4506e",
    referencedGeometrySHA256: "43340089afa8c01e2fe8e2482d9b8fa98e4735480ba45c65083d617e43bc66b1",
    performance: .init(
      cargo: 16, speed: 48.0, acceleration: 16.0,
      energy: 360, recharge: 6.2, roll: 1.21,
      pitch: 1.06, yaw: 0.99, shield: 350,
      shieldRecharge: 2.1, fuel: 130, jump: 10.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 10, price: 368000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: true, nativeCrew: 0,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh126: OriginalFleetR3Contract = .init(
    id: "SH126", name: "Mangalica", family: "mangalica",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "eb30d59059901c0273749a8abfb7aeff688f47136bb976099644a7919d5e0304",
    referencedGeometrySHA256: "e99e3eec8c2898bb44ae37dce41a5c253068760ba438d9efbad0bdea0c2f698d",
    performance: .init(
      cargo: 56, speed: 37.2, acceleration: 11.0,
      energy: 260, recharge: 3.6, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 220,
      shieldRecharge: 1.5, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 20, price: 299000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 11),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh127: OriginalFleetR3Contract = .init(
    id: "SH127", name: "Gaur Trader", family: "gaur",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "ec3704708a19b702c148805bc1bb94dea7eeae14617bf89d6948697bdf011993",
    referencedGeometrySHA256: "33a5a9a095e417a76cdc2e55b73fc9819aa1b7390cfdee36d28661ff89bf6c70",
    performance: .init(
      cargo: 88, speed: 32.0, acceleration: 11.0,
      energy: 350, recharge: 4.4, roll: 1.03,
      pitch: 0.91, yaw: 0.84, shield: 220,
      shieldRecharge: 1.5, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 7,
      cargoExpansion: 20, price: 342000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 17),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh128: OriginalFleetR3Contract = .init(
    id: "SH128", name: "Boar Transport", family: "boar",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "28b46e525d66545d6c34367574714913126558c765cef6d54d16764774563487",
    referencedGeometrySHA256: "f5b934ab51d55b29d5cdcfc112b9e5300030dbc2d9f0f33d5290562c1b2cd4aa",
    performance: .init(
      cargo: 374, speed: 23.1, acceleration: 6.2,
      energy: 640, recharge: 5.2, roll: 0.49,
      pitch: 0.43, yaw: 0.4, shield: 450,
      shieldRecharge: 1.7, fuel: 130, jump: 8.0,
      spool: 14, missiles: 6, facings: 7,
      cargoExpansion: 150, price: 486000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 5, intrinsicCrewPlaces: 5,
      nativeAutonomous: false, nativeCrew: 5,
      conversionCrew: 5, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 74),
    fitting: .init(
      equipmentUnits: 32, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh129: OriginalFleetR3Contract = .init(
    id: "SH129", name: "Warthog Escort", family: "warthog",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "5a6e261a1f2c5224062c05bb35a24cd5d19f1cef920f565bd81bffc4d3797db9",
    referencedGeometrySHA256: "1e1a84f58ecc47dceacffcaf0b3cbbffd9fdb1e4f55a596137ee30a3e1da5f19",
    performance: .init(
      cargo: 36, speed: 35.5, acceleration: 10.8,
      energy: 650, recharge: 7.2, roll: 0.88,
      pitch: 0.77, yaw: 0.72, shield: 380,
      shieldRecharge: 2.0, fuel: 130, jump: 8.0,
      spool: 14, missiles: 9, facings: 15,
      cargoExpansion: 15, price: 462000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 7),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh130: OriginalFleetR3Contract = .init(
    id: "SH130", name: "Marmot Prospector", family: "marmot",
    classification: "miner", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "83ce030b30b99f053df1a789a8f0656210cb01ec729b5db30c9166b8599951af",
    referencedGeometrySHA256: "585648ea93bf0d9cbd081057b5bc18b15f9de4e06323bb1895fad054ce3086bb",
    performance: .init(
      cargo: 200, speed: 22.0, acceleration: 6.9,
      energy: 620, recharge: 7.2, roll: 0.54,
      pitch: 0.48, yaw: 0.44, shield: 390,
      shieldRecharge: 1.8, fuel: 130, jump: 9.0,
      spool: 14, missiles: 6, facings: 7,
      cargoExpansion: 70, price: 470000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 6, intrinsicCrewPlaces: 6,
      nativeAutonomous: false, nativeCrew: 6,
      conversionCrew: 6, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 40),
    fitting: .init(
      equipmentUnits: 38, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh131: OriginalFleetR3Contract = .init(
    id: "SH131", name: "Warthog Light", family: "warthog",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "9f4d98e8805dc047394b1bbdc4faa339dedd387da734e1345a16445f8639cc8d",
    referencedGeometrySHA256: "082cca85c6f5b3c2ca65818099ec43983507d85952d2085d8d8d262e6e9ecab3",
    performance: .init(
      cargo: 220, speed: 27.0, acceleration: 5.4,
      energy: 510, recharge: 4.7, roll: 0.42,
      pitch: 0.37, yaw: 0.34, shield: 500,
      shieldRecharge: 1.7, fuel: 130, jump: 9.0,
      spool: 14, missiles: 4, facings: 3,
      cargoExpansion: 175, price: 408000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 44),
    fitting: .init(
      equipmentUnits: 28, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh132: OriginalFleetR3Contract = .init(
    id: "SH132", name: "Warthog Freighter", family: "warthog",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "93daa375d45a467981bb6992291302a43d32e4ef5e98e7dcee981b6ac9494863",
    referencedGeometrySHA256: "821d3467382c0b672a115f2c7d3ccc48d4a09a7e41fa0d872fd1cb5e517f438b",
    performance: .init(
      cargo: 440, speed: 21.3, acceleration: 5.4,
      energy: 730, recharge: 6.2, roll: 0.42,
      pitch: 0.37, yaw: 0.34, shield: 500,
      shieldRecharge: 1.7, fuel: 130, jump: 8.0,
      spool: 14, missiles: 6, facings: 7,
      cargoExpansion: 175, price: 537000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 6, intrinsicCrewPlaces: 6,
      nativeAutonomous: false, nativeCrew: 6,
      conversionCrew: 6, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 88),
    fitting: .init(
      equipmentUnits: 36, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh133: OriginalFleetR3Contract = .init(
    id: "SH133", name: "Warthog Tanker", family: "warthog",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0680055333de4af0d353a5e7a3369ccff40ff4f60a73dd4c8cb47b3bb53affd3",
    referencedGeometrySHA256: "a98398a837b69114e29784381918de0f1d2ded6fa7ad782b032d63247eed6aa1",
    performance: .init(
      cargo: 350, speed: 20.0, acceleration: 5.4,
      energy: 790, recharge: 6.5, roll: 0.42,
      pitch: 0.37, yaw: 0.34, shield: 500,
      shieldRecharge: 1.7, fuel: 190, jump: 12.0,
      spool: 14, missiles: 5, facings: 3,
      cargoExpansion: 175, price: 560000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 6, intrinsicCrewPlaces: 6,
      nativeAutonomous: false, nativeCrew: 6,
      conversionCrew: 6, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 70),
    fitting: .init(
      equipmentUnits: 40, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["auxiliaryFuelTank", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh134: OriginalFleetR3Contract = .init(
    id: "SH134", name: "Warthog Heavy", family: "warthog",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "7ce96ac1716e50c1a53919b5e46d2b93110676b357e9ff286819bb59ce9be36a",
    referencedGeometrySHA256: "405632ced74ba51a1a9c76ecedad1cc42488dff8b9a1dc4f582212a9472c0de6",
    performance: .init(
      cargo: 620, speed: 18.0, acceleration: 4.64,
      energy: 980, recharge: 6.0, roll: 0.361,
      pitch: 0.318, yaw: 0.292, shield: 500,
      shieldRecharge: 1.7, fuel: 130, jump: 8.0,
      spool: 14, missiles: 8, facings: 15,
      cargoExpansion: 175, price: 661000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 9, intrinsicCrewPlaces: 9,
      nativeAutonomous: false, nativeCrew: 9,
      conversionCrew: 9, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 124),
    fitting: .init(
      equipmentUnits: 44, utilityMounts: 3,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh135: OriginalFleetR3Contract = .init(
    id: "SH135", name: "Javelina", family: "javelina",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "b825090136e4cdb090221ffc21de4eea157da71e2d06f15fed390b21332b6bdc",
    referencedGeometrySHA256: "639883bc947fce13fbc77203825a9a705c51f224d558f0f47c393fc882097b25",
    performance: .init(
      cargo: 54, speed: 39.2, acceleration: 10.6,
      energy: 270, recharge: 3.5, roll: 0.95,
      pitch: 0.84, yaw: 0.78, shield: 230,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 20, price: 300000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 10),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh136: OriginalFleetR3Contract = .init(
    id: "SH136", name: "Falcon Mk I", family: "falcon",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "7ab120fd7e6a97467bc5faf76d4bbb6f616d933219ea07e3845acf3ea5595625",
    referencedGeometrySHA256: "fdbf3fb120a965482dcf3f00cca9b27598f881aab297911f4ba802c17a90a6fc",
    performance: .init(
      cargo: 10, speed: 55.0, acceleration: 19.26,
      energy: 270, recharge: 4.2, roll: 1.646,
      pitch: 1.445, yaw: 1.355, shield: 250,
      shieldRecharge: 2.0, fuel: 110, jump: 8.0,
      spool: 10, missiles: 6, facings: 1,
      cargoExpansion: 5, price: 317000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 14, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh137: OriginalFleetR3Contract = .init(
    id: "SH137", name: "Falcon Mk II", family: "falcon",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "773713dedad2f1352d296b425a65ddeb2abebc3681c7201f6a9b42f78fd3012e",
    referencedGeometrySHA256: "1ae68958ef5c8372692b3540b03a3ce699c8de8f247958b06e5f18d344d78137",
    performance: .init(
      cargo: 12, speed: 53.0, acceleration: 18.82,
      energy: 320, recharge: 4.8, roll: 1.59,
      pitch: 1.4, yaw: 1.299, shield: 270,
      shieldRecharge: 2.1, fuel: 110, jump: 9.0,
      spool: 10, missiles: 7, facings: 3,
      cargoExpansion: 5, price: 345000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh138: OriginalFleetR3Contract = .init(
    id: "SH138", name: "Falcon Mk III", family: "falcon",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "7e1f9e93799c01e265397bc4737c99932c6f910142c68d06a0ba701711373814",
    referencedGeometrySHA256: "459a954252a56474df93d17d5e7e103d5cf2918af442c1630a26e65cb5e309ef",
    performance: .init(
      cargo: 14, speed: 50.5, acceleration: 18.37,
      energy: 390, recharge: 5.8, roll: 1.546,
      pitch: 1.355, yaw: 1.266, shield: 290,
      shieldRecharge: 2.2, fuel: 110, jump: 9.0,
      spool: 11, missiles: 8, facings: 7,
      cargoExpansion: 5, price: 381000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh139: OriginalFleetR3Contract = .init(
    id: "SH139", name: "Falcon Mk IV", family: "falcon",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "d033cfb048e5fb53bb9688bc4841b7bb9476431401c6a8e1f1c82c5d3945e19c",
    referencedGeometrySHA256: "2c55c3a5c5d954684cc71cf7ee9c6420771cd2f1243d1cb888f89f9f3e0cee39",
    performance: .init(
      cargo: 16, speed: 47.0, acceleration: 17.92,
      energy: 470, recharge: 6.8, roll: 1.49,
      pitch: 1.31, yaw: 1.221, shield: 310,
      shieldRecharge: 2.3, fuel: 120, jump: 10.0,
      spool: 12, missiles: 9, facings: 15,
      cargoExpansion: 5, price: 420000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh140: OriginalFleetR3Contract = .init(
    id: "SH140", name: "Chimango", family: "chimango",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "bc0475aaef5cc400e321fc3322a4b56ef20317cc2652f0cc93710fa0ae01a3e1",
    referencedGeometrySHA256: "eb4503a63f35300965be5c0f892894e7d727dfd19a4d238bdd1a691ca812a8d7",
    performance: .init(
      cargo: 20, speed: 55.0, acceleration: 17.92,
      energy: 280, recharge: 4.2, roll: 1.512,
      pitch: 1.333, yaw: 1.243, shield: 240,
      shieldRecharge: 1.9, fuel: 130, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 10, price: 335000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh141: OriginalFleetR3Contract = .init(
    id: "SH141", name: "Salamander Station", family: "salamander-station",
    classification: "station", objectKind: .station,
    origin: .human,
    environment: .init(
      playerCrewRequired: false, purchasePolicy: .never,
      physicalService: .stationServices),
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "968c0e6f99c1076f5d675e40d407e92383a4af5f45e8de05fecde80a8e4d4728",
    referencedGeometrySHA256: "0736d6096f947792ec7464703a51a98f6eb556551a4aeb0960dfadc03e928a16",
    performance: nil,
    accommodation: nil,
    fitting: nil,
    acquisition: nil)


  private static let sh142: OriginalFleetR3Contract = .init(
    id: "SH142", name: "Buzzard Mk II", family: "buzzard",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "bd417e5a856c7bd473e401bb8a72df3e07a4dfe49d8086efa1093644186a6fd1",
    referencedGeometrySHA256: "8c2947c09d24d7990ff0cbe901220def8e5b52b1bd5b1f1990076167be9bd053",
    performance: .init(
      cargo: 30, speed: 46.5, acceleration: 15.0,
      energy: 460, recharge: 6.5, roll: 1.28,
      pitch: 1.13, yaw: 1.05, shield: 270,
      shieldRecharge: 1.99, fuel: 130, jump: 9.0,
      spool: 12, missiles: 6, facings: 15,
      cargoExpansion: 10, price: 412000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 4,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["salvageBeam", "salvageCutter", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh143: OriginalFleetR3Contract = .init(
    id: "SH143", name: "Aardvark Miner", family: "aardvark",
    classification: "miner", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "84c025f31ce75221465e6b3c2ea9b3d65f259c18bef1b7a82e8efa362972daea",
    referencedGeometrySHA256: "68f8b505e2c51ad34b2ff4a1fc7bb49c55903b58694e2ad353ddbc4728359341",
    performance: .init(
      cargo: 104, speed: 26.0, acceleration: 8.5,
      energy: 500, recharge: 6.8, roll: 0.65,
      pitch: 0.57, yaw: 0.53, shield: 340,
      shieldRecharge: 1.8, fuel: 120, jump: 10.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 35, price: 409000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 4, intrinsicCrewPlaces: 4,
      nativeAutonomous: false, nativeCrew: 4,
      conversionCrew: 4, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 20),
    fitting: .init(
      equipmentUnits: 34, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh144: OriginalFleetR3Contract = .init(
    id: "SH144", name: "Razorback", family: "razorback",
    classification: "trader", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0d4c7423d819f109418ba2883edeff8f08290277f039148c70878b4e187e41cd",
    referencedGeometrySHA256: "e30c1a84cb44852ddfbe6d397aa27f637a4387160af448859423e85437c04ac5",
    performance: .init(
      cargo: 66, speed: 38.4, acceleration: 10.4,
      energy: 250, recharge: 3.2, roll: 0.92,
      pitch: 0.81, yaw: 0.75, shield: 210,
      shieldRecharge: 1.5, fuel: 130, jump: 9.0,
      spool: 12, missiles: 6, facings: 3,
      cargoExpansion: 25, price: 295000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 13),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh145: OriginalFleetR3Contract = .init(
    id: "SH145", name: "Kestrel", family: "kestrel",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f9ea829a445cd5915bd02c53bb3b8c1d85324fa091ecd736a9ce14931478d89f",
    referencedGeometrySHA256: "0c7e5f7ba56a5904fb8df1d76e750142e814ff5600b93fb0455ad616bc5e8e51",
    performance: .init(
      cargo: 14, speed: 48.0, acceleration: 14.0,
      energy: 320, recharge: 5.0, roll: 1.15,
      pitch: 1.01, yaw: 0.94, shield: 290,
      shieldRecharge: 2.0, fuel: 120, jump: 9.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 5, price: 331000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh146: OriginalFleetR3Contract = .init(
    id: "SH146", name: "Merlin", family: "merlin",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "234f480466bc7a1bc549622073919a661034e511199ff4f9b8236015cf898b3b",
    referencedGeometrySHA256: "893c7cfaa90cc7afc58efc6f061f02c73cd5a2dae1db0af896f53ae2f70e6566",
    performance: .init(
      cargo: 12, speed: 50.0, acceleration: 15.68,
      energy: 290, recharge: 5.6, roll: 1.288,
      pitch: 1.131, yaw: 1.053, shield: 290,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 5, facings: 1,
      cargoExpansion: 5, price: 339000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 16, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh147: OriginalFleetR3Contract = .init(
    id: "SH147", name: "Hawk", family: "hawk",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f868fb1ab5eb44df24e1db6d427bd95e793e390799fabf64d4195b70be3994e1",
    referencedGeometrySHA256: "1f07968c2fbda290d73618a1d7039de2c8576d8879cfc8f8fa96a5a029288d40",
    performance: .init(
      cargo: 18, speed: 43.2, acceleration: 13.4,
      energy: 410, recharge: 6.4, roll: 1.13,
      pitch: 0.99, yaw: 0.93, shield: 300,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 6, facings: 7,
      cargoExpansion: 5, price: 380000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh148: OriginalFleetR3Contract = .init(
    id: "SH148", name: "Morepork", family: "morepork",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "2912c2fce8d5640f03b3847d8cdbe8f3bbcaff8981790a65ba9637160728bc57",
    referencedGeometrySHA256: "c662ad791478a0709e2e136bcb70e3292665d48ac52d06c67e13a20d07879ecc",
    performance: .init(
      cargo: 16, speed: 45.0, acceleration: 15.4,
      energy: 380, recharge: 6.5, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 130, jump: 11.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 5, price: 379000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh149: OriginalFleetR3Contract = .init(
    id: "SH149", name: "Owlet Mk II", family: "owlet",
    classification: "bountyHunter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0000721bfa356c4bf251e1cc8ef5569595f3ac5628190fdb9789e21d7c73f4f2",
    referencedGeometrySHA256: "4759ef063f9c3ad2b1f733a2eb975744b3e6c34b8531a6a03bad8b1aed5fb595",
    performance: .init(
      cargo: 22, speed: 50.5, acceleration: 15.6,
      energy: 340, recharge: 5.0, roll: 1.3,
      pitch: 1.14, yaw: 1.07, shield: 260,
      shieldRecharge: 1.99, fuel: 150, jump: 12.0,
      spool: 12, missiles: 6, facings: 3,
      cargoExpansion: 10, price: 374000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["salvageCutter", "cargoScoop", "surveyArray", "rescueReceiver", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh150: OriginalFleetR3Contract = .init(
    id: "SH150", name: "Reindeer Freighter", family: "reindeer",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "fcaab7daecf342a8dd67725565ed8f7fcf6460eab8c0357de5041b314fe8cbe4",
    referencedGeometrySHA256: "06cbe5e88f8d62e9f65b09c5cb74ba85b7d84ee183ceed0f40f6a8f3a1542f34",
    performance: .init(
      cargo: 528, speed: 20.8, acceleration: 5.2,
      energy: 740, recharge: 5.2, roll: 0.41,
      pitch: 0.36, yaw: 0.34, shield: 480,
      shieldRecharge: 1.7, fuel: 130, jump: 8.0,
      spool: 14, missiles: 6, facings: 7,
      cargoExpansion: 210, price: 556000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 8, intrinsicCrewPlaces: 8,
      nativeAutonomous: false, nativeCrew: 8,
      conversionCrew: 8, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 105),
    fitting: .init(
      equipmentUnits: 40, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh151: OriginalFleetR3Contract = .init(
    id: "SH151", name: "Lynx Escort", family: "lynx",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "60b92ff51c768bb94a5ab22a8014c5fe7cac85ad7e2f7c78617da403d3697927",
    referencedGeometrySHA256: "a568ebe3e5acd9833c743c5c325581ddfaa436a6e4be491887779b22b814681e",
    performance: .init(
      cargo: 24, speed: 43.0, acceleration: 12.9,
      energy: 400, recharge: 6.0, roll: 1.1,
      pitch: 0.97, yaw: 0.9, shield: 300,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 6, facings: 7,
      cargoExpansion: 10, price: 379000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh152: OriginalFleetR3Contract = .init(
    id: "SH152", name: "Osprey Scout", family: "osprey",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "0ac6d029f0fd74af9ea5567b2f047ffa011a9902c97a2ea2639d26b0c6dc4026",
    referencedGeometrySHA256: "72139a9ccf2ee7df38ffafce1f17bb823f639e7fdefbc4e027e815edb263e02c",
    performance: .init(
      cargo: 12, speed: 49.0, acceleration: 14.0,
      energy: 300, recharge: 4.8, roll: 1.15,
      pitch: 1.01, yaw: 0.94, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 1,
      cargoExpansion: 5, price: 345000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh153: OriginalFleetR3Contract = .init(
    id: "SH153", name: "Osprey Strike", family: "osprey",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "427aa1f5f2f0a41dc45834002c9efcb2e918a1942aa156f4f1000ca470b3f1b6",
    referencedGeometrySHA256: "9ccb8ce4115e6f93a7fa06618e6ca2c001761b6d3135fbca477e7d1acb6be085",
    performance: .init(
      cargo: 14, speed: 46.0, acceleration: 15.4,
      energy: 440, recharge: 6.2, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 8.0,
      spool: 12, missiles: 9, facings: 7,
      cargoExpansion: 5, price: 387000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 2),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 1,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: true),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh154: OriginalFleetR3Contract = .init(
    id: "SH154", name: "Osprey Patrol", family: "osprey",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "9b7c879723fd2b465f06efe8d06c5a6516ba7758485200f583930461ec773472",
    referencedGeometrySHA256: "e629276d66b367e05424ec84ab029be99558b41b76f6670e775c031030f6d790",
    performance: .init(
      cargo: 24, speed: 42.0, acceleration: 12.9,
      energy: 410, recharge: 6.4, roll: 1.1,
      pitch: 0.97, yaw: 0.9, shield: 300,
      shieldRecharge: 2.0, fuel: 130, jump: 11.0,
      spool: 12, missiles: 6, facings: 3,
      cargoExpansion: 10, price: 389000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh155: OriginalFleetR3Contract = .init(
    id: "SH155", name: "Osprey Support", family: "osprey",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "c01b5c1545db7cd07860f71f43158bfde32b4eab4fd147aa96f73d63bedaf992",
    referencedGeometrySHA256: "63ddbc6a3f6e21dbd1641b8fd703297bfac0403e724b4926be46f2e57346fddb",
    performance: .init(
      cargo: 64, speed: 35.0, acceleration: 12.9,
      energy: 500, recharge: 7.4, roll: 1.1,
      pitch: 0.97, yaw: 0.9, shield: 300,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 5, facings: 15,
      cargoExpansion: 10, price: 426000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 6, intrinsicCrewPlaces: 6,
      nativeAutonomous: false, nativeCrew: 6,
      conversionCrew: 6, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 12),
    fitting: .init(
      equipmentUnits: 34, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "salvageCutter", "rescueReceiver", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh156: OriginalFleetR3Contract = .init(
    id: "SH156", name: "Lion Bastion", family: "lion-bastion",
    classification: "platform", objectKind: .platform,
    origin: .human,
    environment: .init(
      playerCrewRequired: false, purchasePolicy: .never,
      physicalService: .weaponsPlatform),
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "9f023a5547867793485716c3a19a2ee73edc08988d6666ec6dadbdb8568b1bfc",
    referencedGeometrySHA256: "9a1147d23fa4a9e514afad7f5d9264746ff135f12729de23878750f4d7f1870d",
    performance: nil,
    accommodation: nil,
    fitting: nil,
    acquisition: nil)


  private static let sh157: OriginalFleetR3Contract = .init(
    id: "SH157", name: "Wolf Scout", family: "wolf",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "f0d74284c9d18ebf3116b8750fdc39f8aa1adefc36b73009230b879c4fd9d961",
    referencedGeometrySHA256: "065e52fa27d9d46ea52229e7a7135e5d6b49bb2d39edcb50a16fd1154cf30e0c",
    performance: .init(
      cargo: 16, speed: 46.2, acceleration: 13.2,
      energy: 350, recharge: 5.1, roll: 1.07,
      pitch: 0.94, yaw: 0.88, shield: 330,
      shieldRecharge: 2.0, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 5, price: 359000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 3,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh158: OriginalFleetR3Contract = .init(
    id: "SH158", name: "Wolf Mk I", family: "wolf",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "08748137eeec587b584f66faa9d6139c7a41b45d9ed8920aa1498eb2f50ae024",
    referencedGeometrySHA256: "2a4f09b965f5fcbb38105bb3a11a4fe9245a6cf6be93895bcf888b06a9219a3b",
    performance: .init(
      cargo: 18, speed: 48.2, acceleration: 14.8,
      energy: 360, recharge: 4.8, roll: 1.21,
      pitch: 1.06, yaw: 0.99, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 8.0,
      spool: 12, missiles: 7, facings: 7,
      cargoExpansion: 5, price: 350000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh159: OriginalFleetR3Contract = .init(
    id: "SH159", name: "Wolf Mk II", family: "wolf",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "3e9dace75fa8fea326ff95d4137a49dd3b6918a86bcb1daeaaa7a9605e06d55a",
    referencedGeometrySHA256: "6a683a22e7fb9238426da2f284d1eacb29bb008b4b3514208d18e666af0569eb",
    performance: .init(
      cargo: 22, speed: 45.7, acceleration: 12.47,
      energy: 440, recharge: 5.9, roll: 1.006,
      pitch: 0.886, yaw: 0.826, shield: 310,
      shieldRecharge: 2.1, fuel: 120, jump: 9.0,
      spool: 12, missiles: 8, facings: 15,
      cargoExpansion: 5, price: 393000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh160: OriginalFleetR3Contract = .init(
    id: "SH160", name: "Wolf Cutter", family: "wolf",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "59dd3fc84c4188f5b16873859cfab2eaafd28bba688e25d1cdb52b9b1ee9419e",
    referencedGeometrySHA256: "febeb15ca6ed5dc6b53b3c59f8405edec733ff85af13f923fab3122d14f73083",
    performance: .init(
      cargo: 30, speed: 40.0, acceleration: 14.0,
      energy: 460, recharge: 6.8, roll: 1.15,
      pitch: 1.01, yaw: 0.94, shield: 290,
      shieldRecharge: 2.0, fuel: 140, jump: 10.0,
      spool: 12, missiles: 5, facings: 3,
      cargoExpansion: 5, price: 404000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 6),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["salvageCutter", "cargoScoop", "rescueReceiver"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh161: OriginalFleetR3Contract = .init(
    id: "SH161", name: "Wolf Citadel", family: "wolf",
    classification: "station", objectKind: .station,
    origin: .human,
    environment: .init(
      playerCrewRequired: false, purchasePolicy: .never,
      physicalService: .stationServices),
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "354edb2f79b3b82e39dda176b9b68a6407172467547381e0a873665cb9d5e53b",
    referencedGeometrySHA256: "0335361ca8aac1cc868e380b3312e2ffb222318803329f5a10c70a21cdf89621",
    performance: nil,
    accommodation: nil,
    fitting: nil,
    acquisition: nil)


  private static let sh162: OriginalFleetR3Contract = .init(
    id: "SH162", name: "Larvaal Probe", family: "larvaal-probe",
    classification: "other", objectKind: .other,
    origin: .larvaal,
    environment: .init(
      playerCrewRequired: false, purchasePolicy: .never,
      physicalService: .missionProbe),
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "243c15f460f4c990a2e4d9573ab6ea4ae24168477c68d7345139e1fe6dc28e59",
    referencedGeometrySHA256: "14d4e261029ca1fcf61a2688c43c192e17c7e523a268ffb9c9b726b087b14151",
    performance: nil,
    accommodation: nil,
    fitting: nil,
    acquisition: nil)


  private static let sh163: OriginalFleetR3Contract = .init(
    id: "SH163", name: "Lammergeier", family: "lammergeier",
    classification: "pirate", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "305f10a91b6567072c62194bb67e4dafbc43b4d5bd6604696c05f2e43d278ba6",
    referencedGeometrySHA256: "35c56db12a269759f3c87d95be388022146d95bfa4f8b8e4e09a4214cc84c9cc",
    performance: .init(
      cargo: 36, speed: 44.0, acceleration: 14.0,
      energy: 410, recharge: 5.4, roll: 1.1,
      pitch: 1.0, yaw: 0.9, shield: 300,
      shieldRecharge: 1.8, fuel: 140, jump: 10.0,
      spool: 15, missiles: 6, facings: 7,
      cargoExpansion: 16, price: 389000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 7),
    fitting: .init(
      equipmentUnits: 28, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["salvageBeam", "salvageCutter", "cargoScoop"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh164: OriginalFleetR3Contract = .init(
    id: "SH164", name: "Toad Drug Factory", family: "toad-drug-factory",
    classification: "station", objectKind: .station,
    origin: .human,
    environment: .init(
      playerCrewRequired: false, purchasePolicy: .never,
      physicalService: .stationServices),
    playerFlyable: false, purchasePolicy: .never,
    sourceSHA256: "29b8cae2acf68eee7f05547c5c0487dceb866c4ba6d3280da5d20b68e55fa4cf",
    referencedGeometrySHA256: "b1563bbc135d0c6ec1ea44ccceabf8f3677363030bbf5af816a7a78d0c51c4e4",
    performance: nil,
    accommodation: nil,
    fitting: nil,
    acquisition: nil)


  private static let sh165: OriginalFleetR3Contract = .init(
    id: "SH165", name: "Secretarybird", family: "secretarybird",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "8d001a1a48b3e9976dec9cbf3ab793a204546e88003152252aaeb17145f800fb",
    referencedGeometrySHA256: "21eb911f38e847414ac0dfc1a66e52d506673859d030acfc6f67526c6ab3d332",
    performance: .init(
      cargo: 18, speed: 45.5, acceleration: 15.4,
      energy: 360, recharge: 5.6, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 10.0,
      spool: 12, missiles: 6, facings: 7,
      cargoExpansion: 5, price: 360000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 20, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh166: OriginalFleetR3Contract = .init(
    id: "SH166", name: "Camel Rescue", family: "camel",
    classification: "transporter", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "40cc092dc15ba1aa8a2b9bd67cd8c051663462df24374abaf46c798bbc147094",
    referencedGeometrySHA256: "5d782369e19a839d28bce557aa327701b0d9904e6381880fbabe9cf161f56db4",
    performance: .init(
      cargo: 280, speed: 25.0, acceleration: 5.9,
      energy: 820, recharge: 6.7, roll: 0.45,
      pitch: 0.4, yaw: 0.37, shield: 460,
      shieldRecharge: 1.7, fuel: 130, jump: 10.0,
      spool: 14, missiles: 4, facings: 3,
      cargoExpansion: 140, price: 555000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 8, intrinsicCrewPlaces: 8,
      nativeAutonomous: false, nativeCrew: 8,
      conversionCrew: 8, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 56),
    fitting: .init(
      equipmentUnits: 46, utilityMounts: 4,
      compatibleUtilities: ["cargoScoop", "salvageCutter", "rescueReceiver", "surveyArray", "auxiliaryFuelTank", "salvageBeam"],
      recommendedRoleKit: ["salvageCutter", "cargoScoop", "rescueReceiver"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh167: OriginalFleetR3Contract = .init(
    id: "SH167", name: "Secretarybird Survey", family: "secretarybird",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "6a7bf674867490fafaafe7b9b8b25d93c68aafd69ca81059db437de561c36696",
    referencedGeometrySHA256: "e3f38e953673b840106430b34385a1492e18c1bb2db3250619f380da6d4fdf4b",
    performance: .init(
      cargo: 28, speed: 42.0, acceleration: 13.4,
      energy: 350, recharge: 6.1, roll: 1.13,
      pitch: 0.99, yaw: 0.93, shield: 300,
      shieldRecharge: 2.0, fuel: 140, jump: 12.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 5, price: 372000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 3, intrinsicCrewPlaces: 3,
      nativeAutonomous: false, nativeCrew: 3,
      conversionCrew: 3, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 5),
    fitting: .init(
      equipmentUnits: 26, utilityMounts: 4,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop", "salvageBeam"],
      recommendedRoleKit: ["surveyArray", "flightRecorder"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh168: OriginalFleetR3Contract = .init(
    id: "SH168", name: "Armadillo Miner", family: "armadillo",
    classification: "miner", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "22b33bde70014ed2ef02dd07cf436a5dfc4ffb0c98887e614aae060d725c6087",
    referencedGeometrySHA256: "6b938c4b4879fa1e41b29fc1f1c81c5a950733937e8ad8337b5439854dca237f",
    performance: .init(
      cargo: 82, speed: 32.0, acceleration: 9.4,
      energy: 330, recharge: 4.6, roll: 0.71,
      pitch: 0.62, yaw: 0.58, shield: 280,
      shieldRecharge: 1.8, fuel: 120, jump: 10.0,
      spool: 12, missiles: 4, facings: 3,
      cargoExpansion: 30, price: 331000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 16),
    fitting: .init(
      equipmentUnits: 24, utilityMounts: 3,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "salvageBeam"],
      recommendedRoleKit: ["miningLaser", "cargoScoop", "surveyArray"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh169: OriginalFleetR3Contract = .init(
    id: "SH169", name: "Caracara Mk I", family: "caracara",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "45ee45d2ed594bf07c527138655844269d6c8987740d8f547cc8ef4818f0a2e1",
    referencedGeometrySHA256: "6257767fbb2cd35db071004b197f8f5655251f87ca3398e176343d12c0fb7b1c",
    performance: .init(
      cargo: 16, speed: 46.4, acceleration: 15.4,
      energy: 340, recharge: 5.0, roll: 1.32,
      pitch: 1.16, yaw: 1.08, shield: 280,
      shieldRecharge: 2.0, fuel: 120, jump: 9.0,
      spool: 12, missiles: 7, facings: 7,
      cargoExpansion: 5, price: 347000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 3),
    fitting: .init(
      equipmentUnits: 18, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh170: OriginalFleetR3Contract = .init(
    id: "SH170", name: "Caracara Mk II", family: "caracara",
    classification: "military", objectKind: .ship,
    origin: .human,
    environment: nil,
    playerFlyable: true, purchasePolicy: .blueprintFabrication,
    sourceSHA256: "5a9cafeee5de8e9c7d022fbd697a05c7205653e213f106fe5f09521a14a3b799",
    referencedGeometrySHA256: "db011887f67e1ae1c5f235fe2b7c4db4a65b29b37906a830433d69d9c8a5527b",
    performance: .init(
      cargo: 22, speed: 43.8, acceleration: 15.0,
      energy: 420, recharge: 6.2, roll: 1.28,
      pitch: 1.13, yaw: 1.05, shield: 300,
      shieldRecharge: 2.1, fuel: 120, jump: 10.0,
      spool: 12, missiles: 8, facings: 15,
      cargoExpansion: 5, price: 391000, workTools: [.salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 2, intrinsicCrewPlaces: 2,
      nativeAutonomous: false, nativeCrew: 2,
      conversionCrew: 2, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 22, utilityMounts: 2,
      compatibleUtilities: ["surveyArray", "salvageCutter", "rescueReceiver", "cargoScoop"],
      recommendedRoleKit: ["combatLaser", "ECM"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

  private static let sh171: OriginalFleetR3Contract = .init(
    id: "SH171", name: "Medusa", family: "medusa",
    classification: "alien", objectKind: .ship,
    origin: .larvaal,
    environment: nil,
    playerFlyable: true, purchasePolicy: .plughQuestFabrication,
    sourceSHA256: "f1e1365586a3723bed5a87f1041d086ab7a7dd3c4ce9d665c6fedce1b39eb48f",
    referencedGeometrySHA256: "d093d9fb10c2319b93f807cf2b02977fa6df91c37e6735df5da33df886216e5b",
    performance: .init(
      cargo: 22, speed: 50.3, acceleration: 18.0,
      energy: 410, recharge: 4.7, roll: 1.37,
      pitch: 1.21, yaw: 1.12, shield: 300,
      shieldRecharge: 2.1, fuel: 130, jump: 9,
      spool: 12, missiles: 5, facings: 15,
      cargoExpansion: 10, price: 288000, workTools: [.miningLaser, .salvageCutter]
    ),
    accommodation: .init(
      operatingCrew: 1, intrinsicCrewPlaces: 1,
      nativeAutonomous: false, nativeCrew: 1,
      conversionCrew: 1, initialPurchasedCabins: 0,
      cabinMassTonnes: 5, cabinEquipmentUnits: 1,
      maximumCabins: 4),
    fitting: .init(
      equipmentUnits: 13, utilityMounts: 4,
      compatibleUtilities: ["miningLaser", "cargoScoop", "salvageCutter", "surveyArray", "rescueReceiver", "salvageBeam", "auxiliaryFuelTank"],
      recommendedRoleKit: ["combatLaser", "ECM", "EMP"], roleKitIncluded: false,
      passengerCabinGrades: ["packedStasis", "economy", "standard", "luxury", "singleStateroom", "doubleStateroom"],
      externalMissilePylons: false),
    acquisition: .init(
      method: "commander-EMP-disable; lawful-empty-authorised-section; actual-cut-and-scoop",
      receivedSampleMassKg: 50.00,
      destructionGrantsBlueprint: false,
      disableAloneGrantsBlueprint: false))

}
