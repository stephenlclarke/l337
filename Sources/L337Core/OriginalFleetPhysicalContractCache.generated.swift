// Immutable per-ID source models. A first lookup resolves only that ID; failures are retained.
// Read-only models do not release actor qualification, loaded mass, crew or purchase authority.
enum OriginalFleetPhysicalContractCache {
  static func result(for id: String) -> Result<OriginalHullPhysicalContract, any Error>? {
    guard let load = resultLoader(for: id) else { return nil }
    return load()
  }

  // Select a small loader before constructing the large physical contract result.
  @inline(never)
  private static func resultLoader(
    for id: String
  ) -> (@Sendable () -> Result<OriginalHullPhysicalContract, any Error>)? {
    switch id {
    case "SH001": return { sh001 }
    case "SH010": return { sh010 }
    case "SH011": return { sh011 }
    case "SH015": return { sh015 }
    case "SH016": return { sh016 }
    case "SH017": return { sh017 }
    case "SH020": return { sh020 }
    case "SH021": return { sh021 }
    case "SH022": return { sh022 }
    case "SH023": return { sh023 }
    case "SH024": return { sh024 }
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
    case "SH104": return { sh104 }
    case "SH105": return { sh105 }
    case "SH106": return { sh106 }
    case "SH107": return { sh107 }
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

  @inline(never)
  private static func load(_ id: String) -> Result<OriginalHullPhysicalContract, any Error> {
    do {
      let definition = try validatedDefinition(for: id)
      let model = try OriginalFleetShowroomModels.model(for: id)
      return .success(try OriginalHullPhysicalContract(definition: definition, model: model))
    } catch {
      return .failure(error)
    }
  }

  @inline(never)
  private static func validatedDefinition(for id: String) throws -> OriginalFleetDefinition {
      guard let current = OriginalFleetR3Data.contract(for: id),
        current.objectKind == .ship || (id == "SH040" && current.objectKind == .capsule),
        let definition = OriginalFleetDefinitionData.definition(for: id)
      else { throw OriginalHullPhysicalContract.Failure.unsupportedSource }
    return definition
  }

  private static let sh001 = load("SH001")
  private static let sh010 = load("SH010")
  private static let sh011 = load("SH011")
  private static let sh015 = load("SH015")
  private static let sh016 = load("SH016")
  private static let sh017 = load("SH017")
  private static let sh020 = load("SH020")
  private static let sh021 = load("SH021")
  private static let sh022 = load("SH022")
  private static let sh023 = load("SH023")
  private static let sh024 = load("SH024")
  private static let sh036 = load("SH036")
  private static let sh037 = load("SH037")
  private static let sh038 = load("SH038")
  private static let sh039 = load("SH039")
  private static let sh040 = load("SH040")
  private static let sh041 = load("SH041")
  private static let sh042 = load("SH042")
  private static let sh043 = load("SH043")
  private static let sh044 = load("SH044")
  private static let sh045 = load("SH045")
  private static let sh046 = load("SH046")
  private static let sh047 = load("SH047")
  private static let sh048 = load("SH048")
  private static let sh049 = load("SH049")
  private static let sh050 = load("SH050")
  private static let sh051 = load("SH051")
  private static let sh052 = load("SH052")
  private static let sh053 = load("SH053")
  private static let sh054 = load("SH054")
  private static let sh055 = load("SH055")
  private static let sh056 = load("SH056")
  private static let sh057 = load("SH057")
  private static let sh058 = load("SH058")
  private static let sh059 = load("SH059")
  private static let sh060 = load("SH060")
  private static let sh062 = load("SH062")
  private static let sh063 = load("SH063")
  private static let sh064 = load("SH064")
  private static let sh065 = load("SH065")
  private static let sh066 = load("SH066")
  private static let sh067 = load("SH067")
  private static let sh068 = load("SH068")
  private static let sh069 = load("SH069")
  private static let sh070 = load("SH070")
  private static let sh071 = load("SH071")
  private static let sh072 = load("SH072")
  private static let sh073 = load("SH073")
  private static let sh074 = load("SH074")
  private static let sh075 = load("SH075")
  private static let sh076 = load("SH076")
  private static let sh077 = load("SH077")
  private static let sh078 = load("SH078")
  private static let sh079 = load("SH079")
  private static let sh080 = load("SH080")
  private static let sh081 = load("SH081")
  private static let sh082 = load("SH082")
  private static let sh083 = load("SH083")
  private static let sh084 = load("SH084")
  private static let sh085 = load("SH085")
  private static let sh086 = load("SH086")
  private static let sh087 = load("SH087")
  private static let sh088 = load("SH088")
  private static let sh089 = load("SH089")
  private static let sh090 = load("SH090")
  private static let sh091 = load("SH091")
  private static let sh092 = load("SH092")
  private static let sh093 = load("SH093")
  private static let sh094 = load("SH094")
  private static let sh095 = load("SH095")
  private static let sh096 = load("SH096")
  private static let sh097 = load("SH097")
  private static let sh098 = load("SH098")
  private static let sh099 = load("SH099")
  private static let sh100 = load("SH100")
  private static let sh101 = load("SH101")
  private static let sh104 = load("SH104")
  private static let sh105 = load("SH105")
  private static let sh106 = load("SH106")
  private static let sh107 = load("SH107")
  private static let sh109 = load("SH109")
  private static let sh110 = load("SH110")
  private static let sh111 = load("SH111")
  private static let sh112 = load("SH112")
  private static let sh113 = load("SH113")
  private static let sh114 = load("SH114")
  private static let sh115 = load("SH115")
  private static let sh116 = load("SH116")
  private static let sh117 = load("SH117")
  private static let sh118 = load("SH118")
  private static let sh119 = load("SH119")
  private static let sh120 = load("SH120")
  private static let sh121 = load("SH121")
  private static let sh122 = load("SH122")
  private static let sh124 = load("SH124")
  private static let sh125 = load("SH125")
  private static let sh126 = load("SH126")
  private static let sh127 = load("SH127")
  private static let sh128 = load("SH128")
  private static let sh129 = load("SH129")
  private static let sh130 = load("SH130")
  private static let sh131 = load("SH131")
  private static let sh132 = load("SH132")
  private static let sh133 = load("SH133")
  private static let sh134 = load("SH134")
  private static let sh135 = load("SH135")
  private static let sh136 = load("SH136")
  private static let sh137 = load("SH137")
  private static let sh138 = load("SH138")
  private static let sh139 = load("SH139")
  private static let sh140 = load("SH140")
  private static let sh142 = load("SH142")
  private static let sh143 = load("SH143")
  private static let sh144 = load("SH144")
  private static let sh145 = load("SH145")
  private static let sh146 = load("SH146")
  private static let sh147 = load("SH147")
  private static let sh148 = load("SH148")
  private static let sh149 = load("SH149")
  private static let sh150 = load("SH150")
  private static let sh151 = load("SH151")
  private static let sh152 = load("SH152")
  private static let sh153 = load("SH153")
  private static let sh154 = load("SH154")
  private static let sh155 = load("SH155")
  private static let sh156 = load("SH156")
  private static let sh157 = load("SH157")
  private static let sh158 = load("SH158")
  private static let sh159 = load("SH159")
  private static let sh160 = load("SH160")
  private static let sh161 = load("SH161")
  private static let sh162 = load("SH162")
  private static let sh163 = load("SH163")
  private static let sh164 = load("SH164")
  private static let sh165 = load("SH165")
  private static let sh166 = load("SH166")
  private static let sh167 = load("SH167")
  private static let sh168 = load("SH168")
  private static let sh169 = load("SH169")
  private static let sh170 = load("SH170")
  private static let sh171 = load("SH171")
}
