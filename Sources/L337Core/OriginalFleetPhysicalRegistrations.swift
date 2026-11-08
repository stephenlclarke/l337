// Frozen per-ID source budgets. No actor or geometry activation is implied.
extension OriginalFleetPhysicalData {
  static let registrations = declaredMetreRegistrations.merging(relativeRegistrations) { _, _ in
    preconditionFailure("Physical source registration IDs must be unique")
  }.merging(larvaalMetreRegistrations) { _, _ in
    preconditionFailure("Physical source registration IDs must be unique")
  }.merging(baselineRegistrations) { _, _ in
    preconditionFailure("Physical source registration IDs must be unique")
  }

  private static let declaredMetreRegistrations: [String: Registration] = [
    "SH036": .init(
      id: "SH036", sha256: "c32a65aaa57bf82dc3a47e3e54820fe6c0d6fe9fd3da7c772da889d5ecf372b1", bytes: 32044,
      detailedSHA256: "0329307ac621426e5f71715000fb5b47f2578d575439598b08ca0ced56b2c77e",
      componentsSHA256: "acd1971914642a49f945f755b5d7f55003589d113330ca5476621c7214f8f910",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH036-design.toml",
      nativeSourceSHA256: "3dd03d7688ee39b0009b257bb5cb0b65f20f5c4ac4580549396b07a48fceb1de"),
    "SH041": .init(
      id: "SH041", sha256: "fc24f453e5fa80317db52c61ffff755f1f7cd503196bd34b8a71f019edd14575", bytes: 30640,
      detailedSHA256: "2a9111ed38c8f023e5b4846bba62a74aeeb302d4300f687abdd19ed900a490ee",
      componentsSHA256: "0d264ed0607940b4f94eae68776664f2f6f7f849d650274faa6e95192b229bfd",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH041-design.toml",
      nativeSourceSHA256: "5d3e7b5da7bee8f62a47aeac58f13064e185d6dc49c842863da82e2a97679fa6"),
    "SH042": .init(
      id: "SH042", sha256: "f113d1c0b723760cb7755ae51204d89e125bb5c3f8d1cf1f0070eaf96d54fa75", bytes: 36452,
      detailedSHA256: "1bb0ed2db6f14323e84a5073f57f75aef7aea86049fcd608b195146611780547",
      componentsSHA256: "024c1607aa4677fda333352aec994d33cfb73fc0f80b1e7a789f76de26a7fe58",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH042-design.toml",
      nativeSourceSHA256: "8b64ebb1529abe86018b7b2553c45f961c06f0e0a9182321ec1b528cb0a716c8"),
    "SH043": .init(
      id: "SH043", sha256: "8cf7dc3345f41175856ef1a571e7aebc709901fd9f186b4e454b0e81e7ce90a5", bytes: 34351,
      detailedSHA256: "3452b1e2aec7c1a469baa68295f2925802b328b52c4420e49211f7993816e052",
      componentsSHA256: "46b502a0062771db70b13f108ca68c4dbc106b46af6da267f54b4367f4c5d336",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH043-design.toml",
      nativeSourceSHA256: "1c7a31a989c833da95651924fa5f44ce9d7fbb56be68b4b6cffe710b1c393216"),
    "SH044": .init(
      id: "SH044", sha256: "ced88e65a0c1d24d861578bb924de0998aba0d03d696afbd5b3f8224d2f11a4d", bytes: 35403,
      detailedSHA256: "057b38312494f17250f32aa60936ec400947ee161ad9dd32f390517339550a63",
      componentsSHA256: "645b6cba3dfceb64d047fc7dc5965660b8472b9eed35dacb8b027b2fc3b66886",
      nativeSourcePath: "fleet-completion-20261019/batch-01-native-lod/SH044-design.toml",
      nativeSourceSHA256: "6221e902c9893e7c3e9b9557e7f3331dc95da26282b76c1edfdbeba8f9f94f25"),
    "SH045": .init(
      id: "SH045", sha256: "cc3c79b8e83df2db5d3fff549ebefbe5a751ec7f6a6cdb0ff7605050abd1420c", bytes: 30821,
      detailedSHA256: "8954950c29b4616f2e41c20d39ef185abf8348ceb7004acfc20efa2087953cd7",
      componentsSHA256: "cc5928b8d759a83a9b7e92ad2c2ea047995607aaf0155de5fb1049477439b576",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH045-design.toml",
      nativeSourceSHA256: "af9e790882ec54bdc368ba1adc7edd757a032c3557d381a50a109bff5abc1ca9"),
    "SH046": .init(
      id: "SH046", sha256: "ceedb96a59a0c93e86658dff9f3e5e92720eb9fc256c6f481f820cf917397ffb", bytes: 34316,
      detailedSHA256: "c2c51d6dd573391d33a0b94216f8cdd2e1c5b9e5cbeab524b2038676a786cd56",
      componentsSHA256: "6e3374d6dcb3787929e030d4cff12d61b8edeb05908c5d20befe9806dd8c98b9",
      nativeSourcePath: "fleet-completion-20261019/batch-01-native-lod/SH046-design.toml",
      nativeSourceSHA256: "2619b8ca62cad610226c8f3862882d17de9b6b83186c192eb0e099dc66eb1c4f"),
    "SH047": .init(
      id: "SH047", sha256: "9fdc76b3008800424a93fea132abcc725884437a826ba027f7d5dfbb2529b043", bytes: 35400,
      detailedSHA256: "8a0dc3f33e4c88e2301c0c00c05d3c5708ee25db4b96f06e6cc919ec634e54b4",
      componentsSHA256: "b019caaa0e254790e526372e94ba3ad285e457388ad3fe4e994f890d27e7a88f",
      nativeSourcePath: "fleet-completion-20261019/batch-01-native-lod/SH047-design.toml",
      nativeSourceSHA256: "7cb0dad60b3f677c8710677403cba2213ffd5bfb1a7ee1a2d2b012cacc381dd7"),
    "SH054": .init(
      id: "SH054", sha256: "c2a250a9eaaffe6776ef3bfa8447ab9e9c96ddf83cdeb1f1b9098ff2e65208ef", bytes: 36356,
      detailedSHA256: "10c4f78ca8cc703cb835d261ab470c09ac86b9173ffe872c5a51eb9292187353",
      componentsSHA256: "10494ebb8f7816a93b08ce6937c7cb91d3b53f01341a734afee78555e598bae7",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH054-design.toml",
      nativeSourceSHA256: "1a933aff0cb9f12bfb23ef4d8a834350e33021f5d7942934db94401ce350ab54"),
    "SH055": .init(
      id: "SH055", sha256: "aee0c5493ba99898321e3c883f1db848c145728cedfa7a142149ecf485aca723", bytes: 31258,
      detailedSHA256: "623613355d58dbe4bf7058237c041ba29c7f9aaa5ffba5891402e8ee4e7c0e5e",
      componentsSHA256: "944712c5c5f62edeacb7a514650e855396fbd29dfa31df3750c6846cc71826c3",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH055-design.toml",
      nativeSourceSHA256: "770a05d0e3faacffb915e1bc5ccfc3bb0e5142d940132843e182ca0b71d9752f"),
    "SH056": .init(
      id: "SH056", sha256: "46dfd0fdf73694925122c7b4f13da5c98efdd698e3df4e3ae17358ba65e406d9", bytes: 30685,
      detailedSHA256: "b2f871fe7e55beb82bbf91ca688187081edc0264219df04d35489d3f541abb1e",
      componentsSHA256: "3ff0f90e932565cae2fa24176eec66a27951253d313937ef6773a06852507de1",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH056-design.toml",
      nativeSourceSHA256: "625559c0932f56b8971d90606d0c861811dca3353318b632a300bdb5fbfcf11f"),
    "SH057": .init(
      id: "SH057", sha256: "60235d52f24576f85bb3eedb17e63af6d23659d29566d34dfed4cd3f7e5d06dd", bytes: 32520,
      detailedSHA256: "7a06dd10db79d5bf57e69067cb3f40daa0def49273ff0b853d629c2c2cd95576",
      componentsSHA256: "19dc985272668c0f1902c1368ec2a8ed08332c8a11b0d75589fc5dfb94a6bfb1",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH057-design.toml",
      nativeSourceSHA256: "08f2a4ceeb05e5ba652c2691301d17a285ec99de0c4f79d9fcdcdaec18bb5fa9"),
    "SH058": .init(
      id: "SH058", sha256: "b05c4d29534783889ee898d28057f23fa64d8c385c78754aa8abf603e76f03a8", bytes: 32841,
      detailedSHA256: "1b743ac0d3fcc1bd5f0d94626cd942d3cbfa3066d28254cdd7e8435621ae0103",
      componentsSHA256: "91a25bfd582d642824269b490635e2747daac7c1cd9e50e0d576172f355e5c78",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH058-design.toml",
      nativeSourceSHA256: "13ef038a1ab17ffb777bd43f6a63b0a973bbea8bfd6076248cc14f8f1d49b2b8"),
    "SH059": .init(
      id: "SH059", sha256: "942af82dc68ac189928080fcaf582569cc5f44661be1b629a2db53a0737e55ec", bytes: 29836,
      detailedSHA256: "2856679ad20446fd76ac6b28d4dbc67e04c819992ebd08cb75aba39e34953cb1",
      componentsSHA256: "445f08f69b078eeced9511c2458bf30225134bf4eed5454e2507e73bd7c437c2",
      nativeSourcePath: "fleet-completion-20261019/batch-02-native-lod/SH059-design.toml",
      nativeSourceSHA256: "1c642950f8d6c5ef773cc36b9c73c249e87e582de19d412e62e4e76e8f7b8b14"),
    "SH062": .init(
      id: "SH062", sha256: "229b7639fa35a6612d84ebd7571be582c89f742ba18fc16d85887e6ebb73adba", bytes: 31921,
      detailedSHA256: "ec91173e7ff65ed64271fabdae0c237519774c07d5ef6a97a2e21c36287324f0",
      componentsSHA256: "3face6ddcbb7ed2c6e3b4b317e445dc912b9ff367f615d09185aa900e991811f",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH062-design.toml",
      nativeSourceSHA256: "ec91173e7ff65ed64271fabdae0c237519774c07d5ef6a97a2e21c36287324f0"),
    "SH064": .init(
      id: "SH064", sha256: "60e354044e7fcbba7c340868f4d4977da4c777798a7eee0dd6d5b7e07b228349", bytes: 34231,
      detailedSHA256: "470c4f3530d75eb55cd74e896922e26b26df6771b65af04112639db4209d5c80",
      componentsSHA256: "01a44ecf7e0e919bdbf0cb1489bda78b085e70772b24ef2fc616d20d7a6d1db3",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH064-design.toml",
      nativeSourceSHA256: "470c4f3530d75eb55cd74e896922e26b26df6771b65af04112639db4209d5c80"),
    "SH065": .init(
      id: "SH065", sha256: "3cbe06321892ef549e7664c4ab66bd91deca4562eb2d936d22163c9be36cd591", bytes: 34301,
      detailedSHA256: "b29e5447be715c56e804b43d4ef5b71ecad354d18c48cf7e6e16d2aac78771af",
      componentsSHA256: "6ddfd023d1e16ce143b20e0c124cb268f57690d4e11a70d7054c0421069dd649",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH065-design.toml",
      nativeSourceSHA256: "b29e5447be715c56e804b43d4ef5b71ecad354d18c48cf7e6e16d2aac78771af"),
    "SH068": .init(
      id: "SH068", sha256: "3281be54b432227dcdb00159dd93ec099f80a52a193d6c35e942683189925b36", bytes: 33855,
      detailedSHA256: "9a793c007844bbb9fe72ebc51cfe0e5d671739ac087b63628a3d91857e868fe5",
      componentsSHA256: "af3fb267655aee4a1c7470131e486330d86e6f62e454c35d7acf1fe257e0802b",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH068-design.toml",
      nativeSourceSHA256: "9a793c007844bbb9fe72ebc51cfe0e5d671739ac087b63628a3d91857e868fe5"),
    "SH069": .init(
      id: "SH069", sha256: "44bf5ec89e29744029ce18bcc72ccd0b031e835c392a3f2371f9442126220506", bytes: 30657,
      detailedSHA256: "02c42c3c40b2a4542db58570f3b689c31dcaa49503c9b8d930f3aae52e1a6bb4",
      componentsSHA256: "375d9586bdb481fb7d3b367638d5296d7c1fb2c8fb57506af84ec415ddd357a2",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH069-design.toml",
      nativeSourceSHA256: "02c42c3c40b2a4542db58570f3b689c31dcaa49503c9b8d930f3aae52e1a6bb4"),
    "SH070": .init(
      id: "SH070", sha256: "ce10a7f8f5d16dfa700ec3890f4667010306683d3bdf38d066c261140b9ba345", bytes: 32453,
      detailedSHA256: "25c56839704deba785e7c381a9db70ddc7e225d94ca37d144a4becb150f7c4fd",
      componentsSHA256: "6901f902eb3d737e5b761bb61256487878b4f5a8a2eab76177d142229e368a8a",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH070-design.toml",
      nativeSourceSHA256: "25c56839704deba785e7c381a9db70ddc7e225d94ca37d144a4becb150f7c4fd"),
    "SH074": .init(
      id: "SH074", sha256: "c3956342ca0d080df0c32fa0ea24c56f5ada70985cc4e82c3adee6dc32fc9aa7", bytes: 34859,
      detailedSHA256: "85d5ac77d76ea8543428b015aca6c8a0025e332ca69f5f6900f83092cda40459",
      componentsSHA256: "b0761fd0571dba551612b75be1aeef7d34cd44fcfbecd97760c1b3273cfdfbd3",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH074-design.toml",
      nativeSourceSHA256: "85d5ac77d76ea8543428b015aca6c8a0025e332ca69f5f6900f83092cda40459"),
    "SH075": .init(
      id: "SH075", sha256: "02d0e3a9747649377067b94b0282933a9af16f78f918d8567cd94cbe9ec8b282", bytes: 35728,
      detailedSHA256: "6f88aa80d06f3d269d925fde3ad1add3eaa655a64df229e30c0af37bff39397d",
      componentsSHA256: "dc310d0a2e27f55c89fb1c7eda63e6920d03ea610cc639e01bbd827cfc353feb",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH075-design.toml",
      nativeSourceSHA256: "6f88aa80d06f3d269d925fde3ad1add3eaa655a64df229e30c0af37bff39397d"),
    "SH077": .init(
      id: "SH077", sha256: "c6b490088d15e9bf3bc4d3700b9f7fe97e6cf366efed74ff27bb868ae9d1b04f", bytes: 33299,
      detailedSHA256: "9d21c021df62f73a9f15b11455f88439fd178cca60ac72d99e1253f0339ac441",
      componentsSHA256: "0a1be49586baa8aaff7de3696bb4b7799e0847a611d77cf72bd4bb6bc7ab4582",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH077-design.toml",
      nativeSourceSHA256: "9d21c021df62f73a9f15b11455f88439fd178cca60ac72d99e1253f0339ac441"),
    "SH078": .init(
      id: "SH078", sha256: "7c1d1b23584d79f839880e4786fe92274709a2be6c097201adf9dc5592107009", bytes: 31963,
      detailedSHA256: "ca5f64a1c396f81cc062345f1659e36113ee6c81a127ac7d7dad872452184e6c",
      componentsSHA256: "c04e2bd4590ce69899be2426592efce85b84370f6d201056ddc6ebd318db83f5",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH078-design.toml",
      nativeSourceSHA256: "ca5f64a1c396f81cc062345f1659e36113ee6c81a127ac7d7dad872452184e6c"),
    "SH079": .init(
      id: "SH079", sha256: "9e8e535d93ddcdfd5e4d9b2f31b0a099de7bccf7452c0903915c49245dac02c8", bytes: 36778,
      detailedSHA256: "5c3b5974e095cfe792ce8b518267cd5d848b4a36ec9ef37e04dabaacddea6c79",
      componentsSHA256: "fd58474ab7bdffdc597898d0b718e4289f3ba2918966a652c54dd81c61db4e65",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH079-design.toml",
      nativeSourceSHA256: "5c3b5974e095cfe792ce8b518267cd5d848b4a36ec9ef37e04dabaacddea6c79"),
    "SH080": .init(
      id: "SH080", sha256: "37058a684deb956d934b69605485bc20f269e26aa850d99b9d8362f7e0f34d70", bytes: 39547,
      detailedSHA256: "e853662580668e4a89c37f46ffd6a49c69aee98b3f324dd0bc77acce960ea009",
      componentsSHA256: "3d976eeefde36ebcecdb405e96e38c5de37e1cd38c68e8a11cd25fe6031ae13e",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH080-design.toml",
      nativeSourceSHA256: "e853662580668e4a89c37f46ffd6a49c69aee98b3f324dd0bc77acce960ea009"),
    "SH081": .init(
      id: "SH081", sha256: "2dbd5e4563126ab862778bb98930932001a4096d503e00459931dfcb7ffcd2f4", bytes: 46121,
      detailedSHA256: "22f8667772b9461bdd59bb7f6d9ef26bf49303cf174ab1ef5415f34277d72b0d",
      componentsSHA256: "abef9217fecb08a56e3dcbba9195d41121817be31f37da6bca671fda3149a996",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH081-design.toml",
      nativeSourceSHA256: "22f8667772b9461bdd59bb7f6d9ef26bf49303cf174ab1ef5415f34277d72b0d"),
    "SH083": .init(
      id: "SH083", sha256: "76ae3537e9050a292aca093b9e3cdbeecac96d5cebc77456383a3cec5f2cb660", bytes: 32236,
      detailedSHA256: "aa694d328600f03ee21f7f9c8496b229347e2e6c1c4d0f5d1da250aa9392ac0e",
      componentsSHA256: "76ecf65a9147f711aed50e869c522e14bcaf61d1a37fff3e76ae647dcf28a126",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH083-design.toml",
      nativeSourceSHA256: "aa694d328600f03ee21f7f9c8496b229347e2e6c1c4d0f5d1da250aa9392ac0e"),
    "SH084": .init(
      id: "SH084", sha256: "d2bd879d2b924f85e87f5d1e37fc524ab57001ce4cb8ab433057258225f48e36", bytes: 31048,
      detailedSHA256: "63e88e1098ea8b59080a254675819a1330bf1ce9a274e2df28be4ca48d2a716d",
      componentsSHA256: "7bf41b811d810805dcc5e74904b479d5b869d397e66eda5b47d55efa451a3f34",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH084-design.toml",
      nativeSourceSHA256: "63e88e1098ea8b59080a254675819a1330bf1ce9a274e2df28be4ca48d2a716d"),
    "SH085": .init(
      id: "SH085", sha256: "9245c92c5e28b89c121da28a16619cc09ba2d4a7d45ce9e793efa2d488d11eb4", bytes: 32653,
      detailedSHA256: "1e1fad73a50483702f87fcbb64839d8954604b0751dcf4cede6283bb6197a85c",
      componentsSHA256: "03555d0e235b3851e9e183b021281c825439718e47e3d8ef1d4cf2e204001a98",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH085-design.toml",
      nativeSourceSHA256: "1e1fad73a50483702f87fcbb64839d8954604b0751dcf4cede6283bb6197a85c"),
    "SH091": .init(
      id: "SH091", sha256: "70e788982a0c7fb468ee835a913a122f5c7dec607e2bd3aef897e963fa0200e1", bytes: 32124,
      detailedSHA256: "fd2fe452563dc9641dd4e48d5bf2beebec411ab225041c4da8c2ff97d36366e3",
      componentsSHA256: "60cd2f339ffeee629a929f40c1c29a1ea938a3c21733a3995ba1d49335a3d29f",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH091-design.toml",
      nativeSourceSHA256: "fd2fe452563dc9641dd4e48d5bf2beebec411ab225041c4da8c2ff97d36366e3"),
    "SH093": .init(
      id: "SH093", sha256: "3a8575e843ab3ea8bf7e792c26852c247469ced469dc40cbc5017a75aaf17351", bytes: 33413,
      detailedSHA256: "a19630347a9a31555430539402ad797754f16a30d51eceba6b27f7214e1ceab7",
      componentsSHA256: "d6e0c592060ab0c7f13114ac2cf1f82211918985339c6552d981c1646fd4ef03",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH093-design.toml",
      nativeSourceSHA256: "a19630347a9a31555430539402ad797754f16a30d51eceba6b27f7214e1ceab7"),
    "SH101": .init(
      id: "SH101", sha256: "f56345014e3f31bfdc506ee3f0f7001489a66a2125761538f8ff9597cd37b46d", bytes: 31272,
      detailedSHA256: "82a26071a46ad1fc2cd4827ee8387e8cfa7d824c738cf29afbde35df740a042b",
      componentsSHA256: "f65f013213016668d2b120b0388269bc349d5594e58ff2a6610359781d8af7ed",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH101-design.toml",
      nativeSourceSHA256: "82a26071a46ad1fc2cd4827ee8387e8cfa7d824c738cf29afbde35df740a042b"),
    "SH109": .init(
      id: "SH109", sha256: "6813d411feb87d14e228400fcc254dd269cf07f284733a4998bb53b34acc6b4a", bytes: 30162,
      detailedSHA256: "4f403f4d2f7e675428b853a67069778a3e501890b4444901a671e19dc130f02e",
      componentsSHA256: "1c960ba98d4abfdb0337a533ec9fbc07c1774574872668938f190239acd25450",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH109-design.toml",
      nativeSourceSHA256: "4f403f4d2f7e675428b853a67069778a3e501890b4444901a671e19dc130f02e"),
    "SH110": .init(
      id: "SH110", sha256: "6233fa1dd2f6d046b74db0aac1c19fac3e3531d7fedbe7dd20419f5a4fb67a39", bytes: 29346,
      detailedSHA256: "844723bc0ce222cfa70ebb6ec53d25130b9bd39a14cda2548b5c806ca1255318",
      componentsSHA256: "b2a93a42fb8cc2521ec71a8fe2ac514bdc2e1694b75c2abab899f68f414dbcdc",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH110-design.toml",
      nativeSourceSHA256: "844723bc0ce222cfa70ebb6ec53d25130b9bd39a14cda2548b5c806ca1255318"),
    "SH111": .init(
      id: "SH111", sha256: "b11780ed56d800d266072a453d015ae4005de7d7e23895aebda58fb13ded1a51", bytes: 32063,
      detailedSHA256: "8eef0062ca13fac1a993ab12c71a536dd25a0569d94cf14981dbd33afa308dad",
      componentsSHA256: "cc3f0c51f3d3088c3b0090053dfe38c687c24c9bc32895145132cf16b07a18b5",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH111-design.toml",
      nativeSourceSHA256: "8eef0062ca13fac1a993ab12c71a536dd25a0569d94cf14981dbd33afa308dad"),
    "SH126": .init(
      id: "SH126", sha256: "957768f955490aa724a2862951e2ebcaa86b279b7c56db9ff0dfd0e3971bb6ae", bytes: 30160,
      detailedSHA256: "e99e3eec8c2898bb44ae37dce41a5c253068760ba438d9efbad0bdea0c2f698d",
      componentsSHA256: "e1e3e93ebc25d509b41a6d8a50110b542199d17398e1f0eeccbc4570be253969",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH126-design.toml",
      nativeSourceSHA256: "e99e3eec8c2898bb44ae37dce41a5c253068760ba438d9efbad0bdea0c2f698d"),
    "SH129": .init(
      id: "SH129", sha256: "503c854b0b4081561b590778d70e71e129d9dc950e73a4e702527996fe52ed2a", bytes: 34758,
      detailedSHA256: "1e1a84f58ecc47dceacffcaf0b3cbbffd9fdb1e4f55a596137ee30a3e1da5f19",
      componentsSHA256: "0dbdc25575bc137728e80460138b75fd6b63cfaa6ab674fda70999471a8be947",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH129-design.toml",
      nativeSourceSHA256: "1e1a84f58ecc47dceacffcaf0b3cbbffd9fdb1e4f55a596137ee30a3e1da5f19"),
    "SH130": .init(
      id: "SH130", sha256: "f1669515728857220c23bcec4de82303e0971040fc65dfa74855e0c0f3ef87a6", bytes: 38040,
      detailedSHA256: "585648ea93bf0d9cbd081057b5bc18b15f9de4e06323bb1895fad054ce3086bb",
      componentsSHA256: "2182e60749988a1c77d6e0a5ce8bcc094d71903e1dd800fd076456f5df10631a",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH130-design.toml",
      nativeSourceSHA256: "585648ea93bf0d9cbd081057b5bc18b15f9de4e06323bb1895fad054ce3086bb"),
    "SH131": .init(
      id: "SH131", sha256: "18574c138817aeac621940b4de018bf3811f721889b4b2fc4f8d2f91e24f7b79", bytes: 31571,
      detailedSHA256: "082cca85c6f5b3c2ca65818099ec43983507d85952d2085d8d8d262e6e9ecab3",
      componentsSHA256: "c6544fc616f98d3a2236c7ae1c4b2dc49ff260dba4ef8a85bd93d82550b8a2f6",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH131-design.toml",
      nativeSourceSHA256: "082cca85c6f5b3c2ca65818099ec43983507d85952d2085d8d8d262e6e9ecab3"),
    "SH132": .init(
      id: "SH132", sha256: "490c02746613c885472063a9b903b8a8305300b5628a7dcb46d79e0b04c48354", bytes: 32126,
      detailedSHA256: "821d3467382c0b672a115f2c7d3ccc48d4a09a7e41fa0d872fd1cb5e517f438b",
      componentsSHA256: "61dc2e694dc9a65c84311a7cf59492aa290caa7d52cdb878d988db3f749367bd",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH132-design.toml",
      nativeSourceSHA256: "821d3467382c0b672a115f2c7d3ccc48d4a09a7e41fa0d872fd1cb5e517f438b"),
    "SH133": .init(
      id: "SH133", sha256: "cafdaef61aacaa28d58ac5e0cb229762d65ecd8a7bfd7835c7bec5d305066d33", bytes: 32444,
      detailedSHA256: "a98398a837b69114e29784381918de0f1d2ded6fa7ad782b032d63247eed6aa1",
      componentsSHA256: "3bb956f9332839284bed0f5a211085d7e815c37a292f033cb8d32f82dfdd284b",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH133-design.toml",
      nativeSourceSHA256: "a98398a837b69114e29784381918de0f1d2ded6fa7ad782b032d63247eed6aa1"),
    "SH134": .init(
      id: "SH134", sha256: "2c5695791c0c708946e9f05ab03c2050cb7842b63b9dcad9793151de4c7690b7", bytes: 32001,
      detailedSHA256: "405632ced74ba51a1a9c76ecedad1cc42488dff8b9a1dc4f582212a9472c0de6",
      componentsSHA256: "3bb956f9332839284bed0f5a211085d7e815c37a292f033cb8d32f82dfdd284b",
      nativeSourcePath: "fleet-completion-20261019/batch-03/SH134-design.toml",
      nativeSourceSHA256: "405632ced74ba51a1a9c76ecedad1cc42488dff8b9a1dc4f582212a9472c0de6"),
    "SH135": .init(
      id: "SH135", sha256: "051ce66f1250342d1a796d7bcd2c491f935fdeb76dc0aa7c00c5bbaa2e014025", bytes: 30478,
      detailedSHA256: "639883bc947fce13fbc77203825a9a705c51f224d558f0f47c393fc882097b25",
      componentsSHA256: "df9228fba5c8a584c2290be0322bb93c0df9393a37bb37fe7f9471541552b2de",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH135-design.toml",
      nativeSourceSHA256: "639883bc947fce13fbc77203825a9a705c51f224d558f0f47c393fc882097b25"),
    "SH140": .init(
      id: "SH140", sha256: "864b42d09ba3ce364ff0e83ba14ca0b06e7fd6611041554d46e9fb8b446b381e", bytes: 30783,
      detailedSHA256: "eb4503a63f35300965be5c0f892894e7d727dfd19a4d238bdd1a691ca812a8d7",
      componentsSHA256: "e173ebc086b8ed738bc93b64675f4250fa58cee83ffedc4e4a5bb33b50dc8365",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH140-design.toml",
      nativeSourceSHA256: "eb4503a63f35300965be5c0f892894e7d727dfd19a4d238bdd1a691ca812a8d7"),
    "SH144": .init(
      id: "SH144", sha256: "6bdde2f0777e44ed0600fc0e89145ef46eff9db20413a1eb06e04e4517454f4f", bytes: 31544,
      detailedSHA256: "e30c1a84cb44852ddfbe6d397aa27f637a4387160af448859423e85437c04ac5",
      componentsSHA256: "0da309f88673c31dbf89b03209ec0188cad663d435a084654b5ede72772ba03e",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH144-design.toml",
      nativeSourceSHA256: "e30c1a84cb44852ddfbe6d397aa27f637a4387160af448859423e85437c04ac5"),
    "SH145": .init(
      id: "SH145", sha256: "ed850d5989ee8e231e7f057cc4b2b99e78ece28fb3f7485b18de56a5b16a918e", bytes: 28649,
      detailedSHA256: "0c7e5f7ba56a5904fb8df1d76e750142e814ff5600b93fb0455ad616bc5e8e51",
      componentsSHA256: "913ee2d54e12d947481d0a39c3324de7727ad0811e7a84ac5c85d393fe259f4e",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH145-design.toml",
      nativeSourceSHA256: "0c7e5f7ba56a5904fb8df1d76e750142e814ff5600b93fb0455ad616bc5e8e51"),
    "SH146": .init(
      id: "SH146", sha256: "f5e954f9a6063449dcb8d2c31955876ef3e3ab78756619f67134aa3638da102e", bytes: 31110,
      detailedSHA256: "893c7cfaa90cc7afc58efc6f061f02c73cd5a2dae1db0af896f53ae2f70e6566",
      componentsSHA256: "85a4cf80c192d6bdc12548a9e8af41e83ab3c3cfddf0ee01eda0375a00920df6",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH146-design.toml",
      nativeSourceSHA256: "893c7cfaa90cc7afc58efc6f061f02c73cd5a2dae1db0af896f53ae2f70e6566"),
    "SH147": .init(
      id: "SH147", sha256: "f392487ad2c5d5d6c9907bf3122823e0569eaa5b1c6fb842de7825696215c728", bytes: 29544,
      detailedSHA256: "1f07968c2fbda290d73618a1d7039de2c8576d8879cfc8f8fa96a5a029288d40",
      componentsSHA256: "e9a3cde791c8a9cc5d1cd9e2dbf9c55a74e2aa10bab71c48ee17341fa26d4eea",
      nativeSourcePath: "fleet-completion-20261019/batch-04/SH147-design.toml",
      nativeSourceSHA256: "1f07968c2fbda290d73618a1d7039de2c8576d8879cfc8f8fa96a5a029288d40"),
  ]
}
