import Testing

@testable import L337Core

struct OriginalFleetR3ContractUnitTests {
  @Test func currentAcquisitionRequirementsNeverDeriveFromKillOrDisableFacts() throws {
    #expect(OriginalFleetR3Data.ids.count == 171 && Set(OriginalFleetR3Data.ids).count == 171)
    for id in OriginalFleetR3Data.ids {
      let contract = try #require(OriginalFleetR3Data.contract(for: id))
      #expect(contract.id == id)
      if contract.purchasePolicy == .blueprintFabrication {
        let intake = try #require(contract.acquisition)
        #expect(intake.requiresPhysicalIntake && intake.receivedSampleMassKg == 50)
        #expect(!intake.destructionGrantsBlueprint && !intake.disableAloneGrantsBlueprint)
        #expect(contract.fitting?.roleKitIncluded == false)
        #expect(contract.accommodation?.initialPurchasedCabins == 0)
      }
    }
    #expect(OriginalFleetR3Data.contract(for: "Cobra Mk III") == nil)
    #expect(OriginalFleetR3Data.contract(for: "SH5") == nil)
  }

  @Test func originalBisonUsesCurrentContractWhileResourceAuthenticationStaysSeparate() throws {
    let expected: [(String, String, Double, Int, Int, Int)] = [
      ("SH005", "abb18a2f94877670d18008dddde590a16a2322bdcc2311cd11b3f241fac43bcd", 6.4, 814000, 12, 48),
      ("SH006", "a01ab6d02762226d4dc194b3311c731e694af1e179b07791755e7a330ba86f6c", 7.1, 908000, 14, 54),
    ]
    for (id, sha, recharge, price, crew, units) in expected {
      let contract = try #require(OriginalFleetR3Data.contract(for: id))
      let source = try #require(OriginalBisonActivation.source(for: id))
      #expect(source.game == contract.performance)
      #expect(source.game.recharge == recharge && source.game.price == price)
      #expect(source.requiredCrewIncludingCommander == crew && source.equipmentUnits == units)
      #expect(contract.sourceSHA256 != source.sourceSHA256)
      #expect(contract.sourceSHA256 == sha)
    }
  }

  @Test func starterAndNonpurchasableObjectsKeepTheirOwnExactPolicies() throws {
    let starter = try #require(OriginalFleetR3Data.contract(for: "SH025"))
    #expect(starter.sourceSHA256 == "a305641b7be704a2af0129e146d4ef1d72d165a1cbc7b935458c4c35aea14cc0")
    #expect(starter.fitting?.utilityMounts == 3 && starter.fitting?.equipmentUnits == 24)
    #expect(starter.accommodation?.maximumCabins == 18)
    for id in ["SH028", "SH040", "SH141", "SH156", "SH162"] {
      let object = try #require(OriginalFleetR3Data.contract(for: id))
      #expect(object.purchasePolicy == .never && object.acquisition == nil)
    }
  }

  @Test func selectedLazyLoaderKeepsAll171ExactCurrentSourceBindings() throws {
    // Governing backlog contract SHA pins, independent of the runtime dispatch implementation.
    let expected = """
      SH001 27c960f32df859e67b969e2d9a25d9fb15f8a887a253cd20f7cd213a728bf14c
      SH002 c2319489558505ed3d4eb6a437e8870e4f6f20055912e337792e324200d0230f
      SH003 e4470633a66738c674f5e6cb61e1b464a89fd83c2f9b1c4b8a77b4b022788e0b
      SH004 9d5f40fbdb42fe6539e9cee6906a07aff1a6caa192f164cffda019e8b79e3d47
      SH005 abb18a2f94877670d18008dddde590a16a2322bdcc2311cd11b3f241fac43bcd
      SH006 a01ab6d02762226d4dc194b3311c731e694af1e179b07791755e7a330ba86f6c
      SH007 362f40c5d357d80c6559090d528a09f71858e09155b162996902c10aa4c7ff63
      SH008 6815e92d5480692d18576ab5ed5e98cd1f99b1bff622c3c7eb346ed59bcf8d42
      SH009 8487d3b24cff75389b9451eb6a3e9f041c907df16caf696a67cd31f46feec670
      SH010 755f776227dcb1d7816b5e426fbe239a98f0f9d1df46fc1ebdbd90c5b15e5983
      SH011 2d61d0afa8810dfec66208bee0b5b95555f64ddd9d2df76ce54b9a5c8a7c8ad1
      SH012 a59ed199acd7c681bc4e590076b0853d19db9724c777c0aee483878d30fcb0df
      SH013 84abd93c7ee81072ef52d70a95e7054bf30d778e988fd05452cb6bf959a37271
      SH014 17f2bcd6a0b854eb3c3f05714e6eca1fe2abb6935d79137dd4e222b78ec103e7
      SH015 9996fa6457ac946c7f01ed8dcab21275b17f260fd4f4cf106bd9d0fa1df71c66
      SH016 d1bf21e0ad41a1fab71976310b850c67c28de10666f331b9b09e99363967d366
      SH017 c31408f9cbf0e76af47c583fcf084080addb1d8e84970cc0168d7c065bae385a
      SH018 93ec89428324d31d6639ad069107c767d7c0129d1683d26f27475fc89a56cc38
      SH019 9eb70cd7503964f5613f86cd6ceec2cf34f64598e8018779380fc6eca5b08a04
      SH020 a4578fb4a6fc9bddd3bbda55fe802ed80e153c0389610e21bf98c5e5521062c5
      SH021 49908a275fb7e5af7c0715b384e8dcc0a9072e453c94c73826d177fccf3a20ea
      SH022 f8502a924dca78b9274ae9ad282cb3d9636ce094087a2ab4365aae7f733a736d
      SH023 ecdb62da81e8b87f802dd92f60374dc4375375575855971b0bb25fb3ba0a679f
      SH024 2117edc243ad7386d00555caa6c05bf155f0d91f32af288d04c5e67ee914844c
      SH025 a305641b7be704a2af0129e146d4ef1d72d165a1cbc7b935458c4c35aea14cc0
      SH026 f23d79dc0c1a0caf93d36a118fc33db7bc7289eac393f49d0c64795d6aa0972e
      SH027 7b038e5e6675b715d56d0ffbecf5ebaed4dd0216109c63aaf5c7dd990efa1aa8
      SH028 b053d76b1912881af248045b29cf29d31cb2f77214b4f1697b8d69a78afa8768
      SH029 229d27ea2c5213bd0993c99b9545997e065673e578b7120829e5c6bd06dafc59
      SH030 774d49d514d03dba198d09762d04d30e74d3ea07dad7f1c34167f0978defb36d
      SH031 cedbde09b76675e9fb3f6022d9c78330524be816ec3d3878f600c0b5244fc8b0
      SH032 9bbbecb8af20c7c20d0d95e0a1d82aeb27950d4a6243329af3a0e6848ecd3a6f
      SH033 f2e0376401c62989cac6f1faad27d484e53627008818dabe0e49ae2e3f194c76
      SH034 cfa885e19c022d6dfe201d03c009f9fad1859cd3ee1966eb9daf379f557622c1
      SH035 dff26cfb4027b272cb7e82c1fd967ec5aa8e27e4a74d2cdfd28a5a01a5836dae
      SH036 4fc25d2778c8e0ab927313a279ca31fcb68df46557223e2cb268a99e7e97dcc4
      SH037 1205c491e12819aaed94eff59ab4c8e22bc52cea61abbdbdb77834fa03301099
      SH038 55d9bb7a617e090e120ae639b19a6eb1f8fa91d220928bf58a498193c425ffd6
      SH039 a64233f42e9882bba36eaba7cb1d997bee73881dff3eb06e72cffc70d3ebba9e
      SH040 6dd8182abf9a00406132db7926c962d470ea7f6c112bb29fad8646aef9aec0ed
      SH041 7f7213ef84d6fc2e1895bf0097f9106c37df199b33d72bf6c78c975a9df197bb
      SH042 36a903484eb884b1774baf0c18270d99916c54cc1cfa55aad32253284faf4293
      SH043 be5d22e65550f8420a4f61ce6c784b1161fcc645d3e542c671dd864e9e736368
      SH044 4e52c59c8ea67c28ed0c85e6bc8d6bd2adc33ef268aac2b902a02a4860b94aab
      SH045 7328c686a42309644a8a413272ba723bd367422e2e7315f5f10cf107a82f54bb
      SH046 18403611eadeb9ccad245863016046fb2df9ef19041f428d52492fdda9574951
      SH047 9dfe04c0823e82541eb1cde7f54438b81b78ed3f6d94e21ab47fef7802879375
      SH048 f8ed0cb8dcbc123a34d9c6718041de1913b6c63c4958adfbe455f1500dcacaaf
      SH049 5259887cd03e65b86d4430361cbedfa2c6a1f6876d3e212540fa2c2c79c3f04a
      SH050 bbe9e3acc93bd75e24ee42500c8b836d1a4d7eecf765c9f34bd879a6c38eaa0a
      SH051 218b167b067e238569c619e73bd5f4ba08f941b115aaeec7a2466d2569061da6
      SH052 d68c0e8af3ba7c75ba30a23441b2adb2b380ccaf755c974c46c822a657c70cce
      SH053 d460619fc51986f13b5c54d08654755341da670df9ece4b755ff2cb35753aba0
      SH054 dafe7d8be715227740f0a7d3a05f106fa6f4bf7faa775955b456e8338f413848
      SH055 58333569187849df206f88e371a9102bda0d98eb2fdb922a317533ce5c3a4038
      SH056 95499ece85aad0bf86717d4f71101e5be9e9f23251c26b6a68a482395383288d
      SH057 ffe134c836380aa65bfa648403c6954daff113f4fef4dfc6467c03ef8e01410d
      SH058 fd5f2d8a64762ab74e1849985e6cf3bf25184968e5cf6f7d6d15213eadd3b11c
      SH059 682ea6695deaf59ec229599d0fbcea0b86b8f307de68f220e15e1201bc8dbd94
      SH060 7741929f5e69b590c7a0324963e1e45d3b298eb63b4ea4419c1f186fb1684677
      SH061 a5b9e65f897bebac9f94ab7ba88c5f38908bf13da7c85c5c3eff5b74ed96a4a4
      SH062 af7e5b06c322c002069f6c7ea99d3ba77a7c421a33231c983d49643572e84c42
      SH063 234fb257ba59abe14540cb18f87c9fbf62332f0d6172b91487b67bc355a81faa
      SH064 91172f72834f1078bb886c2bc8581fb880dc2641b7b5c92ab16eda4181d0f4ad
      SH065 9cf0eb3f8ec63b539dbb093734c1833f8cb95775c76d547580c99511b054fa83
      SH066 10fe257691fbe5ee08953837dd65002ec547c02362a1f09436ab97d78e515676
      SH067 18e33608d5ff332934812bfcf40b6f99cafdcc900727a0a5f2090ab183dd15af
      SH068 f715749177b8a3897f5af27b32f991205965847a1aa90da63ee37c5f11f74196
      SH069 d807c75dab09754cdf61f174014ed1714dc8c03002f8fb5e4848d37524f18aa6
      SH070 a93cfc8d733b3d667ec1f24cf877e2d689102913a42acc30cdb77078ade6c6fe
      SH071 aae0fbafceeb0adf78d050c184bdca3eb4b0a1f11240c83430aaa27e1a5c3519
      SH072 4be1bb6109ec00b2bb05dbba194562054f10d27ee8ff4a105a310b7aa3370498
      SH073 0b64d1c988e9863bf08810fd36047b50626182795da99f0e2df8f5b48ad85230
      SH074 0711a5d64904da6ecc41ecb46cf978dc5065321ce4757c7390c0172b6b4d6822
      SH075 3f6f6790a6ba48313118d7ab8cfc191b05c03f42a1d1c2596c3e1c007e1b991a
      SH076 799045a816586eff2fe721601e0d5a8ab46a3acc1d7e09351d423b5b39087b0c
      SH077 b47b47578defd762547b0f25c6c64697cc340eadb534b0543b3d0dd89325c9dc
      SH078 ec614af96ca542fc5ad47f512bd5d3a88aa04b46f86fa5a0cd7f72b7d00031b9
      SH079 f1e712171f85fce0e633fbff4dfe99e69eb77e07f52eaef46411cb7025e62024
      SH080 e03e647a7312e9caa8dd86cedffa6df274ed4c5ef76b03ff526b97d7eb135782
      SH081 57ea57735c368d832a43ed1bade04accf4bf71577dd3439a876a45f610f366f4
      SH082 ccbea073da64824196b980c1baeb2163869dc2f75ea780f19056b18cc520bf93
      SH083 bb7350c1b3035b058625a398139fc15df0146e1c760a640e5ee9bd552ea88095
      SH084 d80ac8f22ee304bb730d16d2206a660168cb0a762a668eec0775a32c45d21467
      SH085 fdf156b257cfa0ea113403c0b85b45d53ee87af25a56f5b891a06f448e92804f
      SH086 845645594b80228376299805b54e24044ddca1078a3bb573727de61f64fa2fdd
      SH087 ee415f26d288d66cbc448c51a5c15bcd362acd0e3e4220d085c5e2162a695b0e
      SH088 a68eca7fb52dba02989f82a1c23a1201ac4ce28b2125f9a6a357fd4eb785ee82
      SH089 92cdce3357540ac17a213a8f5f034d0fc58f7af6e3b541539c951d45e0439d65
      SH090 af105a6530de697eecb95e7efbc58b833aae9f3ee55d7a7c78f3ce4ca25842c3
      SH091 eda1e9dceb8b3594fa99bb2d8ed9f21e2e7fab320ee1ae3dc154b1b82aa52f81
      SH092 160a1fb62c14ac65098bf97be6ef956c7c791e93d1efe16869cf2368551ff78a
      SH093 763c3badc87a28e0d9c431d0ddc417297f0cc99066f83cf33e6bf9fe1fd96a8e
      SH094 0a2256276dbfcf8d5490c3dfaffb9446a00be5337e7b591d76f4d2c245e0c175
      SH095 4f14b1d022195ef57d3b35966b902b8afd2f192d8326e1f3ba9c97cc1dcf09b4
      SH096 f487b23ff82c66f2dc67f018e81e6c2afdd78176c796ff92565892b1737fa6d4
      SH097 e669e500f1fa5a3ff5ee65470d2095c3d550ff75233c019f275fcb66c60baca4
      SH098 ed1addd7a35c62ff86bfb2af5fe3c4b83f826b8f98d36b003f48e050c0e48f5a
      SH099 4576979bb379ce9e5560be83fbe2085973136518104c7f144ed9fe1aaaa869cc
      SH100 51052443fd83b5480ab4b35a91cda57dc820284ed4b128430a567a1063d48ea3
      SH101 1b9d47d25ced3e9ecdde52fe636747d3e456b959fa76be89d97b8de0af316019
      SH102 71c01d62bbb79cc605c6be8ef8f3cbf3e48e788969ecd7b4b3b0ddcac02e2071
      SH103 a867f71cdc9693f245c54a8c63d15a657a00c6ba7db782cfa384b6f6ee41ccdf
      SH104 771cf33fa828f8a6d26daec429a61baf705393c9ad9c5651198a9d8f144603e9
      SH105 c3e044e23e9f4c87d9d9f06318d5bda37e2a5d79d2c69a4e727a99039701c489
      SH106 3afaae56e461c018053ee63f4629b4ec9412fa0fa34d80e954d8dd315a5a3ff3
      SH107 0469be178a7140df3f8643b275580e9fee75d02a5843f07d8274c9747aaba905
      SH108 e6dd044e8985abfeb14b7a23296389c5acbb210e901bebe64aa4cbbdc49c4de8
      SH109 f5ddce9ce6d78f9000775b8dc12adae3d8ccfb183618418e43babd944315913f
      SH110 5673b36946ecb6cdcfeea77976e2bad35483c8124e761ab4374a778e6696b651
      SH111 e4e13abef63d92f973cd41c2b15ce806754ddd1442cd34e65cc5e0e61bab4eef
      SH112 cbcdc5e45436d78d490b00f76b8e3f430e963fb5204cd6162f51fc802ad8674b
      SH113 1a86eadf7eae395da5bf6f1329cc56d4bf24e14f97bfa34a39b598ed6ff3062f
      SH114 52fa731ac2d363006a35c0dd4a7318b5e94cf51892f0e6abae6f70bb01c94143
      SH115 6ed36170e9691f0f12aaf19b49eb0eeee314135c1931af965806c823dac7bf45
      SH116 0ac287f26c28101ac8999e38dc9a7b26a145370ccdaa248ba6d7eed04afe1fb2
      SH117 d3bd98bd547c59cf62b6c1891f1fe3554754a140796f1dbb2060b89369ac6442
      SH118 960a541ea826d2cb8634794e52772874570d4d9e7dc5dc949527ec1db41d80f7
      SH119 f44ea27d0015ea2fdc28491277d4d5fc2625f66a597670db8351c68211dd91f3
      SH120 b510e195c30517d6ad5cd4a04277612fdb4800198dffc8f01c695a95573f2eaf
      SH121 48146ed3f79c033f8b3b6342c9642cfaaf62c949ec6a479e28a22e0a88a6d270
      SH122 65f2ecb53a56251a6b3e38f5d459f636732bfdb017ae341a32aef0361d32d6f3
      SH123 113645d823bf6ad3e81a10fad4e854a0e64363cc6454fc23332cded47a203d6a
      SH124 851502c15a6922797e9c650e8a126fd73ce7ccc76f5e1419a870625c72abe21e
      SH125 66671c43983362d99fa0ecbc361fe224db0a7ac50799fd7d35cedb4d3fa4506e
      SH126 eb30d59059901c0273749a8abfb7aeff688f47136bb976099644a7919d5e0304
      SH127 ec3704708a19b702c148805bc1bb94dea7eeae14617bf89d6948697bdf011993
      SH128 28b46e525d66545d6c34367574714913126558c765cef6d54d16764774563487
      SH129 5a6e261a1f2c5224062c05bb35a24cd5d19f1cef920f565bd81bffc4d3797db9
      SH130 83ce030b30b99f053df1a789a8f0656210cb01ec729b5db30c9166b8599951af
      SH131 9f4d98e8805dc047394b1bbdc4faa339dedd387da734e1345a16445f8639cc8d
      SH132 93daa375d45a467981bb6992291302a43d32e4ef5e98e7dcee981b6ac9494863
      SH133 0680055333de4af0d353a5e7a3369ccff40ff4f60a73dd4c8cb47b3bb53affd3
      SH134 7ce96ac1716e50c1a53919b5e46d2b93110676b357e9ff286819bb59ce9be36a
      SH135 b825090136e4cdb090221ffc21de4eea157da71e2d06f15fed390b21332b6bdc
      SH136 7ab120fd7e6a97467bc5faf76d4bbb6f616d933219ea07e3845acf3ea5595625
      SH137 773713dedad2f1352d296b425a65ddeb2abebc3681c7201f6a9b42f78fd3012e
      SH138 7e1f9e93799c01e265397bc4737c99932c6f910142c68d06a0ba701711373814
      SH139 d033cfb048e5fb53bb9688bc4841b7bb9476431401c6a8e1f1c82c5d3945e19c
      SH140 bc0475aaef5cc400e321fc3322a4b56ef20317cc2652f0cc93710fa0ae01a3e1
      SH141 968c0e6f99c1076f5d675e40d407e92383a4af5f45e8de05fecde80a8e4d4728
      SH142 bd417e5a856c7bd473e401bb8a72df3e07a4dfe49d8086efa1093644186a6fd1
      SH143 84c025f31ce75221465e6b3c2ea9b3d65f259c18bef1b7a82e8efa362972daea
      SH144 0d4c7423d819f109418ba2883edeff8f08290277f039148c70878b4e187e41cd
      SH145 f9ea829a445cd5915bd02c53bb3b8c1d85324fa091ecd736a9ce14931478d89f
      SH146 234f480466bc7a1bc549622073919a661034e511199ff4f9b8236015cf898b3b
      SH147 f868fb1ab5eb44df24e1db6d427bd95e793e390799fabf64d4195b70be3994e1
      SH148 2912c2fce8d5640f03b3847d8cdbe8f3bbcaff8981790a65ba9637160728bc57
      SH149 0000721bfa356c4bf251e1cc8ef5569595f3ac5628190fdb9789e21d7c73f4f2
      SH150 fcaab7daecf342a8dd67725565ed8f7fcf6460eab8c0357de5041b314fe8cbe4
      SH151 60b92ff51c768bb94a5ab22a8014c5fe7cac85ad7e2f7c78617da403d3697927
      SH152 0ac6d029f0fd74af9ea5567b2f047ffa011a9902c97a2ea2639d26b0c6dc4026
      SH153 427aa1f5f2f0a41dc45834002c9efcb2e918a1942aa156f4f1000ca470b3f1b6
      SH154 9b7c879723fd2b465f06efe8d06c5a6516ba7758485200f583930461ec773472
      SH155 c01b5c1545db7cd07860f71f43158bfde32b4eab4fd147aa96f73d63bedaf992
      SH156 9f023a5547867793485716c3a19a2ee73edc08988d6666ec6dadbdb8568b1bfc
      SH157 f0d74284c9d18ebf3116b8750fdc39f8aa1adefc36b73009230b879c4fd9d961
      SH158 08748137eeec587b584f66faa9d6139c7a41b45d9ed8920aa1498eb2f50ae024
      SH159 3e9dace75fa8fea326ff95d4137a49dd3b6918a86bcb1daeaaa7a9605e06d55a
      SH160 59dd3fc84c4188f5b16873859cfab2eaafd28bba688e25d1cdb52b9b1ee9419e
      SH161 354edb2f79b3b82e39dda176b9b68a6407172467547381e0a873665cb9d5e53b
      SH162 243c15f460f4c990a2e4d9573ab6ea4ae24168477c68d7345139e1fe6dc28e59
      SH163 305f10a91b6567072c62194bb67e4dafbc43b4d5bd6604696c05f2e43d278ba6
      SH164 29b8cae2acf68eee7f05547c5c0487dceb866c4ba6d3280da5d20b68e55fa4cf
      SH165 8d001a1a48b3e9976dec9cbf3ab793a204546e88003152252aaeb17145f800fb
      SH166 40cc092dc15ba1aa8a2b9bd67cd8c051663462df24374abaf46c798bbc147094
      SH167 6a7bf674867490fafaafe7b9b8b25d93c68aafd69ca81059db437de561c36696
      SH168 22b33bde70014ed2ef02dd07cf436a5dfc4ffb0c98887e614aae060d725c6087
      SH169 45ee45d2ed594bf07c527138655844269d6c8987740d8f547cc8ef4818f0a2e1
      SH170 5a9cafeee5de8e9c7d022fbd697a05c7205653e213f106fe5f09521a14a3b799
      SH171 f1e1365586a3723bed5a87f1041d086ab7a7dd3c4ce9d665c6fedce1b39eb48f
      """
    var seen: Set<String> = []
    for row in expected.split(separator: "\n") {
      let fields = row.split(separator: " ")
      try #require(fields.count == 2)
      let id = String(fields[0])
      let contract = try #require(OriginalFleetR3Data.contract(for: id))
      #expect(contract.id == id)
      #expect(contract.sourceSHA256 == String(fields[1]))
      let inserted = seen.insert(id).inserted
      #expect(inserted)
    }
    #expect(seen.count == 171)
    #expect(seen.sorted() == OriginalFleetR3Data.ids)
  }

  @Test func loaderSelectionKeepsUnknownIDsNilAndRepeatedRequirementsUnchanged() throws {
    for id in ["", "SH000", "SH172", "SH5", "sh001", " SH001", "SH001 ", "SH001-extra", "Cobra Mk III"] {
      #expect(OriginalFleetR3Data.contract(for: id) == nil)
    }
    for id in ["SH002", "SH025", "SH061", "SH112", "SH156", "SH162", "SH171"] {
      let first = try #require(OriginalFleetR3Data.contract(for: id))
      let again = try #require(OriginalFleetR3Data.contract(for: id))
      #expect(first.id == again.id && first.name == again.name && first.family == again.family)
      #expect(first.sourceSHA256 == again.sourceSHA256)
      #expect(first.referencedGeometrySHA256 == again.referencedGeometrySHA256)
      #expect(first.performance == again.performance)
      #expect(first.objectKind == again.objectKind && first.origin == again.origin)
      #expect(first.playerFlyable == again.playerFlyable && first.purchasePolicy == again.purchasePolicy)
      #expect(first.accommodation?.nativeCrew == again.accommodation?.nativeCrew)
      #expect(first.accommodation?.conversionCrew == again.accommodation?.conversionCrew)
      #expect(first.environment?.physicalService == again.environment?.physicalService)
      #expect(first.acquisition?.method == again.acquisition?.method)
    }
  }
}
