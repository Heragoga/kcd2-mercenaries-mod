-- Weapon-preset audit. Spawns one NPC per weapon preset in a numbered grid and
-- reports, per NPC, whether the preset's items actually reached his inventory -
-- so a preset that arms nobody can be spotted by eye and by log at once.
-- Debug only; see docs/weapon-audit.md.

mercenaries.WeaponAuditPrefix  = "MercWpnAudit_"
mercenaries.WeaponAuditRowSize = 12
mercenaries.WeaponAuditSpacing = 2.2
mercenaries.WeaponAuditRankGap = 3.5
mercenaries.WeaponAuditSpawned = {}   -- [entityName] = { idx, preset, ent }

-- Every weapon preset in weapon_preset__mercenaries.xml, in file order, with the
-- vanilla item name behind each item_class_id. nm = "UNKNOWN_ITEM" means the id is
-- in no item table under references/ - which says the dump is older than the build,
-- not that the id is bad: the two that show up here resolve fine in game.
mercenaries.WeaponAuditPresets = {
    { g = "a1e50100-1c4b-4e6a-9f01-3b8c5d2e7d02", n = "weapon_preset_alx_jezek", items = {
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
        { id = "d8f1a893-0e67-4f29-b897-1a831a3ab923", nm = "ztracenaCest_lordsOfHolohlavShield", shield = true },
    } },
    { g = "2c28935e-103c-4f0a-b154-36890bac73f2", n = "merc_weapon_shortsword_weak_1", items = {
        { id = "652db434-b7d6-448f-8671-10ca787ba1e2", nm = "shortswordCleaver", shield = false },
    } },
    { g = "11bd007a-0312-4e4d-968d-2c4cb9fe6286", n = "merc_weapon_shortsword_weak_2", items = {
        { id = "efa237c7-3905-4813-b9c3-a32b449c17ad", nm = "shortswordCommon", shield = false },
    } },
    { g = "8c38d157-2403-41fb-a573-c2a396a29235", n = "merc_weapon_shortsword_medium_1", items = {
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
    } },
    { g = "e4266b99-79fb-40ef-84fa-0b721a6ba3c2", n = "merc_weapon_shortsword_medium_2", items = {
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
    } },
    { g = "0d4fc137-2b83-4d2d-970e-cf09871f29d6", n = "merc_weapon_shortsword_strong_1", items = {
        { id = "e37bdf86-4cc8-4805-b04c-3b05964b9484", nm = "shortSwordBasilard", shield = false },
    } },
    { g = "8d7d2c25-874e-41f8-a169-c3e731b23249", n = "merc_weapon_shortsword_strong_2", items = {
        { id = "b3f7a363-5526-45b1-a32b-422a0a8e4da4", nm = "shortswordHeavy", shield = false },
    } },
    { g = "38118d03-1fed-4b1b-a8ba-7e195ea7ebc7", n = "merc_weapon_longsword_weak_1", items = {
        { id = "bdb6fc2a-43e4-40b8-93c8-f2d9162c1e45", nm = "longswordOld", shield = false },
    } },
    { g = "fc3dd411-ca51-49cd-bc1b-480caf1f2f20", n = "merc_weapon_longsword_weak_2", items = {
        { id = "76009b72-1e65-4a78-98c7-6ada2f172c1f", nm = "longSwordDuel_empty", shield = false },
    } },
    { g = "54e2ff1a-cd9c-4558-9533-ded96a3f0603", n = "merc_weapon_longsword_weak_3", items = {
        { id = "d284732b-32d1-40e6-be9b-0c89e18f969f", nm = "longswordZizka_duel", shield = false },
    } },
    { g = "e84ebb37-bf5c-45ea-abe9-a416a5ad38e2", n = "merc_weapon_longsword_weak_4", items = {
        { id = "2d466cad-74df-4337-ae97-4c7433a54b6d", nm = "longSwordDuel_khTournament", shield = false },
    } },
    { g = "b53518cb-e7d6-4eb6-9d6e-211a14adcaa1", n = "merc_weapon_longsword_weak_5", items = {
        { id = "9e31a288-7de0-4c0d-81cd-5cf00548d2d5", nm = "longswordCommon", shield = false },
    } },
    { g = "5539c7d7-15e5-49a0-8db7-aeff9f3ce550", n = "merc_weapon_longsword_medium_1", items = {
        { id = "9e31a288-7de0-4c0d-81cd-5cf00548d2d5", nm = "longswordCommon", shield = false },
    } },
    { g = "73fbc897-2756-4d34-9e7a-57959de342b2", n = "merc_weapon_longsword_medium_2", items = {
        { id = "23855649-1783-4e0d-95ad-d3478797b642", nm = "longswordSturdy", shield = false },
    } },
    { g = "b3072196-f572-401b-a213-5c023d8d1a92", n = "merc_weapon_longsword_medium_3", items = {
        { id = "23855649-1783-4e0d-95ad-d3478797b642", nm = "longswordSturdy", shield = false },
    } },
    { g = "eb316792-4ebd-43c7-b554-d0cbdef360f8", n = "merc_weapon_longsword_medium_4", items = {
        { id = "23855649-1783-4e0d-95ad-d3478797b642", nm = "longswordSturdy", shield = false },
    } },
    { g = "c0638095-60c3-40d0-b93d-3f42f237a20e", n = "merc_weapon_longsword_medium_5", items = {
        { id = "08f5ee0a-ac03-423e-bc00-c388303cf0c9", nm = "kovaniKopie_longSwordAbsolver", shield = false },
    } },
    { g = "890cca0b-6489-47f0-9331-706a015ff21e", n = "merc_weapon_longsword_strong_1", items = {
        { id = "3858560f-cf48-436f-8815-4426003288fb", nm = "longswordBroad", shield = false },
    } },
    { g = "d9c83f05-f0d7-4304-9dee-c3106d6ab3fe", n = "merc_weapon_longsword_strong_2", items = {
        { id = "3858560f-cf48-436f-8815-4426003288fb", nm = "longswordBroad", shield = false },
    } },
    { g = "94be3211-a101-4de7-b29d-a5dfde474f57", n = "merc_weapon_longsword_strong_3", items = {
        { id = "5bda7534-6439-4424-bb9c-fe9737b79484", nm = "tournament_kuttenbergSword", shield = false },
    } },
    { g = "31a30fb0-4d4e-4ed8-925d-fc481bd1063b", n = "merc_weapon_longsword_strong_4", items = {
        { id = "00cca9e3-8ef2-46db-8cbf-86ec51930919", nm = "longSwordDuel", shield = false },
    } },
    { g = "720fcde5-15b8-4f3b-b0c9-489a99e7043e", n = "merc_weapon_mace_weak_1", items = {
        { id = "cff7ae16-d134-41bd-9394-89e8c3970f94", nm = "maceClub", shield = false },
    } },
    { g = "533bd7b4-d70a-4af2-abaa-fe09b5c8fb28", n = "merc_weapon_mace_weak_2", items = {
        { id = "007907cf-aeb9-4dfa-ad3f-e0262893e423", nm = "maceClubSpiked", shield = false },
    } },
    { g = "122e7230-d72f-4d84-a1a0-59f9f0f7d235", n = "merc_weapon_mace_weak_3", items = {
        { id = "9cc07405-4195-46ab-bf17-fd0fd99721bd", nm = "mace01", shield = false },
    } },
    { g = "0d951547-9012-48cd-8e43-9d502e01e9a7", n = "merc_weapon_mace_weak_4", items = {
        { id = "9cc07405-4195-46ab-bf17-fd0fd99721bd", nm = "mace01", shield = false },
    } },
    { g = "c66f0c6e-c281-4024-a1c5-3ebb1fc69cc0", n = "merc_weapon_mace_medium_1", items = {
        { id = "00b0039b-daa4-4f32-ac7f-69a6a2e0add8", nm = "maceDagger", shield = false },
    } },
    { g = "10e96c57-99a6-43ee-9279-fd7bc7132972", n = "merc_weapon_mace_medium_2", items = {
        { id = "f65df177-966b-48e5-8cc6-26a4f95e41b0", nm = "maceBailiff", shield = false },
    } },
    { g = "439fe662-b7ec-4605-9729-e8f3e8df4bc7", n = "merc_weapon_mace_medium_3", items = {
        { id = "af6a6142-c6f7-4ae7-94a9-bb5be41ebecc", nm = "maceHeavy", shield = false },
    } },
    { g = "83142d88-9463-4930-9d6e-aa86dae6d35a", n = "merc_weapon_mace_medium_4", items = {
        { id = "c67de991-e22a-4a19-8b68-9369919c41dd", nm = "mace02", shield = false },
    } },
    { g = "2ae255da-ed23-46b6-aec7-0deeac7d5e2e", n = "merc_weapon_mace_strong_1", items = {
        { id = "839992c8-657b-4d5e-97c9-96ff94430d72", nm = "mace03", shield = false },
    } },
    { g = "97c91389-882c-4387-9cb4-9abfee9ded51", n = "merc_weapon_mace_strong_2", items = {
        { id = "f2e86f22-8932-4751-8f62-fb1b8b846ddf", nm = "maceHetman", shield = false },
    } },
    { g = "9367c4d6-2897-42dd-9697-8adfa4356ecb", n = "merc_weapon_mace_strong_3", items = {
        { id = "65a211bd-2c7e-40a8-984f-66c8730444e4", nm = "mace04", shield = false },
    } },
    { g = "1fd54037-8eb6-4ce4-9f02-63acce98183d", n = "merc_weapon_axe_weak_1", items = {
        { id = "1fc42528-2bef-4dde-bf8a-04febeef41c8", nm = "axeWork01", shield = false },
    } },
    { g = "67cb04b2-2a7c-40dc-9f93-4b1ef6fd58c4", n = "merc_weapon_axe_weak_2", items = {
        { id = "1fc42528-2bef-4dde-bf8a-04febeef41c8", nm = "axeWork01", shield = false },
    } },
    { g = "5076de8f-f9f2-4c4b-a1bd-e23034219359", n = "merc_weapon_axe_weak_3", items = {
        { id = "81494400-b654-4aa7-8f31-c95c689db5f6", nm = "axeWork02", shield = false },
    } },
    { g = "6aba5df6-a2cf-4a2e-8ec4-e69de02dcab4", n = "merc_weapon_axe_weak_4", items = {
        { id = "53612e76-76fd-4dca-84b6-7905b986dc3b", nm = "axeBattle01", shield = false },
    } },
    { g = "986244d4-e276-40f4-a6b4-649a934cc450", n = "merc_weapon_axe_medium_1", items = {
        { id = "c25fc705-c957-4c9a-a831-0f112e3b148d", nm = "kovaniPoklad_adornedAxe", shield = false },
    } },
    { g = "d5f3e8de-5abf-4bea-be19-9a9d3c756f00", n = "merc_weapon_axe_medium_2", items = {
        { id = "e2cf3e8b-b411-43a0-a7ed-2674ae8ac4d2", nm = "poi_ratborschButcherAxe", shield = false },
    } },
    { g = "81787f5f-80a0-42fc-a742-46f0f3a8015e", n = "merc_weapon_axe_medium_3", items = {
        { id = "eeeb5a48-9a97-41a6-aee0-3e1b64fc2405", nm = "axeCuman", shield = false },
    } },
    { g = "7803affa-1a74-42c6-9fcf-ed6c1d3289b0", n = "merc_weapon_axe_medium_4", items = {
        { id = "bd74ce18-2623-48ba-a1a1-c9b09bbb2827", nm = "axeBattle02", shield = false },
    } },
    { g = "9d139c04-b054-4e98-b4d3-8054a639f485", n = "merc_weapon_axe_strong_1", items = {
        { id = "0802c111-75aa-4b9c-9a3f-f30bac55fbc7", nm = "axeWork02_kunesh", shield = false },
    } },
    { g = "d834a864-7b9a-4557-93ad-024555604735", n = "merc_weapon_axe_strong_2", items = {
        { id = "50a9ac1e-dbb5-480b-8b5e-2ba3a1ff8d82", nm = "axeFancy", shield = false },
    } },
    { g = "59418607-6a33-45cc-9903-582a07f22a5c", n = "merc_weapon_axe_strong_3", items = {
        { id = "214ffcdd-a7a7-4b7a-b484-f60c8d00b39b", nm = "axeBattle04", shield = false },
    } },
    { g = "a1554b5a-a4b8-4541-8706-c97b8657672c", n = "merc_weapon_axe_strong_4", items = {
        { id = "0f0164d5-3746-4d07-a1ed-0f138225a6d9", nm = "axeBattle03", shield = false },
    } },
    { g = "5d4c7a48-c95c-4e59-96c4-54851e75160b", n = "merc_weapon_polearm_weak_1", items = {
        { id = "85beaf9d-e351-45b1-8144-0bec039e2803", nm = "polearmPitchforkSedlakaMateje", shield = false },
    } },
    { g = "ad5922d0-0614-4912-b98c-adb2241602b4", n = "merc_weapon_polearm_weak_2", items = {
        { id = "08250d1c-c62e-43b5-967c-17ccb4adf1b5", nm = "polearmPitchfork", shield = false },
    } },
    { g = "482d2d35-87d2-47e1-8edd-4ed85d28912e", n = "merc_weapon_polearm_weak_3", items = {
        { id = "f4324daf-fe09-495e-b954-16f23226cf58", nm = "polearmSpear", shield = false },
    } },
    { g = "8baedacf-d744-451a-8acd-332c32165120", n = "merc_weapon_polearm_weak_4", items = {
        { id = "e5f25908-a843-456a-b095-c31db34aa577", nm = "polearmGlaive", shield = false },
    } },
    { g = "d72d9727-43ab-4e85-a0fa-bd6664fff2e7", n = "merc_weapon_polearm_medium_1", items = {
        { id = "aa11269e-ee54-46e0-b7c7-1efc50d7bcb8", nm = "polearmBruncvik", shield = false },
    } },
    { g = "1b086963-8c38-41c9-867e-b79174b6206d", n = "merc_weapon_polearm_medium_2", items = {
        { id = "4bda3dd1-871c-452a-87fe-b783946435c2", nm = "polearmBardiche", shield = false },
    } },
    { g = "3deb122d-a168-4bfb-9ae0-143d24ae029d", n = "merc_weapon_polearm_medium_3", items = {
        { id = "03b6321d-4151-46cd-bdec-451ea7bfaabc", nm = "polearmVoulge", shield = false },
    } },
    { g = "9a8dccf1-9948-49d1-81f9-8b50d62cd373", n = "merc_weapon_polearm_strong_1", items = {
        { id = "7cac0c1a-ad34-4fd7-a1e6-4d45edcf307f", nm = "polearmMorgenstern", shield = false },
    } },
    { g = "2cd35a00-09e3-4b76-b2c5-f13e2251cb65", n = "merc_weapon_polearm_strong_2", items = {
        { id = "0f41ad99-3307-47c8-a110-a7d9b4af75e8", nm = "polearmGuisarm", shield = false },
    } },
    { g = "b1b35d6f-3daa-46df-b3bf-96eda006833c", n = "merc_weapon_polearm_strong_3", items = {
        { id = "51bb7893-2054-40d3-a355-d278f416c482", nm = "polearmPoleaxe", shield = false },
    } },
    { g = "e3e35ccf-4eac-47d6-93ed-9dd343540998", n = "merc_weapon_archer_weak_1", items = {
        { id = "0fffb172-2183-4545-bbdb-01e04a3ff32f", nm = "bow_b", shield = false },
    } },
    { g = "4a2525e0-0787-4eb9-a56a-9ac9c105a8f4", n = "merc_weapon_archer_weak_2", items = {
        { id = "db354284-2cf9-40a4-bcfc-e78d020204af", nm = "bow_b_a", shield = false },
    } },
    { g = "104b4d63-519f-4d76-8826-e8ffdc3b520f", n = "merc_weapon_archer_medium_1", items = {
        { id = "7b77a0e9-91cd-403f-be3e-6be6bac8e589", nm = "cuman_bow_b", shield = false },
    } },
    { g = "4797ce5f-954d-4df4-ad4b-115b4004850c", n = "merc_weapon_archer_medium_2", items = {
        { id = "f54e6116-6c6c-4712-99a9-8a11e3416e2b", nm = "bow_c_b", shield = false },
    } },
    { g = "832e27a6-f6a9-4f86-aa99-bf42066cd7ad", n = "merc_weapon_archer_strong_1", items = {
        { id = "b4a0b9c9-bf92-4cce-ad43-f20f57c892b9", nm = "bow_d", shield = false },
    } },
    { g = "d582651e-129b-4230-b6c1-b1c783a0566d", n = "merc_weapon_archer_strong_2", items = {
        { id = "77262956-daee-4a0e-9035-517569f18ef4", nm = "bow_d_a", shield = false },
    } },
    { g = "8e256398-37a8-4c16-81eb-4535296a2c9c", n = "merc_weapon_crossbow_weak_1", items = {
        { id = "7673efc2-0566-4dde-9e18-f96c7790ce2e", nm = "crossbowLightCheap01", shield = false },
    } },
    { g = "3b297403-b517-441e-b219-d58fa7e078fc", n = "merc_weapon_crossbow_weak_2", items = {
        { id = "cb6ee20b-6eee-434c-af4c-8031502e2bec", nm = "crossbowLightNormal01", shield = false },
    } },
    { g = "6b0e8574-0486-4990-8dcc-8aef99aeee85", n = "merc_weapon_crossbow_medium_1", items = {
        { id = "b77f912a-042b-47ca-8f42-5fddbcad3763", nm = "crossbowMediumCheap01", shield = false },
    } },
    { g = "947a178c-5a0b-4040-9d71-534544c0e3b3", n = "merc_weapon_crossbow_medium_2", items = {
        { id = "48f25a62-e787-490e-83e9-9335bf303ef9", nm = "crossbowMediumNormal01", shield = false },
    } },
    { g = "7b026220-fd56-48fa-9f9c-7b8e33294118", n = "merc_weapon_crossbow_strong_1", items = {
        { id = "f0fb0494-6ebd-4c6a-bb9e-ef396db3c5d4", nm = "crossbowHeavyNormal01", shield = false },
    } },
    { g = "9f8743e4-6a5a-4a86-a74c-6ee33b2d1f45", n = "merc_weapon_crossbow_strong_2", items = {
        { id = "588c12c6-f0fb-4b3e-847d-ce1df2739e73", nm = "crossbowHeavyCheap01", shield = false },
    } },
    { g = "b785e210-1881-4c93-aa76-52d87dad0620", n = "merc_weapon_handcannon_weak_1", items = {
        { id = "ea78735d-b371-46d4-a039-bef0ebbb088e", nm = "handgonneNormal01", shield = false },
    } },
    { g = "4e80ca93-ebca-4397-9ed8-353c4fab2fec", n = "merc_weapon_handcannon_weak_2", items = {
        { id = "d9ccf323-7ca7-4d05-b8fb-213c748bb23e", nm = "hookgunNormal01", shield = false },
    } },
    { g = "53c9970d-531a-4c72-af42-867f20549fd8", n = "merc_weapon_handcannon_medium_1", items = {
        { id = "2694bfef-be40-4fb2-901b-e010eaede3ec", nm = "handgunFancy01", shield = false },
    } },
    { g = "01aaaac4-be90-45cf-9f66-9392783f2c84", n = "merc_weapon_handcannon_strong_1", items = {
        { id = "842c178a-54b8-4c2b-8255-77d430165320", nm = "hookgunFancy01", shield = false },
    } },
    { g = "aef0bb38-59a8-46cb-99bd-f4447e849a04", n = "merc_weapon_swordshield_weak_1", items = {
        { id = "652db434-b7d6-448f-8671-10ca787ba1e2", nm = "shortswordCleaver", shield = false },
        { id = "292ea6c3-92b9-40a1-890c-d558ab00a8f2", nm = "shieldPavise_GY_A", shield = true },
    } },
    { g = "4c06c342-1f4e-4259-ae48-94c636ae3d3e", n = "merc_weapon_swordshield_weak_2", items = {
        { id = "efa237c7-3905-4813-b9c3-a32b449c17ad", nm = "shortswordCommon", shield = false },
        { id = "66760529-5a60-4bc3-861b-6694d571f5a1", nm = "shieldPavise_RW_A", shield = true },
    } },
    { g = "e6b2dd31-5e6f-4ba9-a221-dfa8ec993d8e", n = "merc_weapon_swordshield_medium_1", items = {
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
        { id = "8baa70c0-222a-42dc-a289-035c83a33d5e", nm = "shieldHeater_whole_K", shield = true },
    } },
    { g = "cb12a1ab-b658-45bc-abdd-7e7d9e632bd6", n = "merc_weapon_swordshield_medium_2", items = {
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
        { id = "4bfa707e-2a7b-4091-8230-0b7d83da716a", nm = "shieldHeater_chevronny_gw", shield = true },
    } },
    { g = "85741a9f-1e35-45b8-879e-cfa17fc87dc0", n = "merc_weapon_swordshield_strong_1", items = {
        { id = "e37bdf86-4cc8-4805-b04c-3b05964b9484", nm = "shortSwordBasilard", shield = false },
        { id = "e4e1b22a-428a-4e20-aa92-ce216b324c0a", nm = "shieldKite_whole_K", shield = true },
    } },
    { g = "f21f88f7-d0d7-4b72-8c6d-abebe945f071", n = "merc_weapon_swordshield_strong_2", items = {
        { id = "b3f7a363-5526-45b1-a32b-422a0a8e4da4", nm = "shortswordHeavy", shield = false },
        { id = "2fd517a8-e990-45a1-8fbc-e4b3636cf30a", nm = "shieldKite_whole_T", shield = true },
    } },
    { g = "b6e1c2a4-3f8d-4c11-9a2e-7d5f8b3c1a90", n = "merc_weapon_swordshield_weak_3", items = {
        { id = "652db434-b7d6-448f-8671-10ca787ba1e2", nm = "shortswordCleaver", shield = false },
        { id = "310faab5-8502-47b2-adf8-22149d97d8b6", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "a17f9d2b-6c4e-4a83-8b1f-3e9c7d2a5b64", n = "merc_weapon_swordshield_weak_4", items = {
        { id = "efa237c7-3905-4813-b9c3-a32b449c17ad", nm = "shortswordCommon", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "c3d8a1f5-2b7e-4f96-8c3a-1d6e9b4f7c22", n = "merc_weapon_swordshield_medium_3", items = {
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
        { id = "310faab5-8502-47b2-adf8-22149d97d8b6", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "d4e9b2a6-3c8f-4a09-9d4b-2e7f0a5c8d33", n = "merc_weapon_swordshield_medium_4", items = {
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "e5fa3b7c-4d9a-4b12-8e5c-3f8a1b6d9e44", n = "merc_weapon_swordshield_strong_3", items = {
        { id = "e37bdf86-4cc8-4805-b04c-3b05964b9484", nm = "shortSwordBasilard", shield = false },
        { id = "310faab5-8502-47b2-adf8-22149d97d8b6", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "f60b4c8d-5eab-4c23-9f6d-4a9b2c7e0f55", n = "merc_weapon_swordshield_strong_4", items = {
        { id = "b3f7a363-5526-45b1-a32b-422a0a8e4da4", nm = "shortswordHeavy", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "1231bf2d-a4a2-4afe-bc46-e90a89aeb693", n = "merc_weapon_axeshield_weak_1", items = {
        { id = "1fc42528-2bef-4dde-bf8a-04febeef41c8", nm = "axeWork01", shield = false },
        { id = "292ea6c3-92b9-40a1-890c-d558ab00a8f2", nm = "shieldPavise_GY_A", shield = true },
    } },
    { g = "3730631f-7bf6-42b0-9141-34a32ac3e0a0", n = "merc_weapon_axeshield_weak_2", items = {
        { id = "1fc42528-2bef-4dde-bf8a-04febeef41c8", nm = "axeWork01", shield = false },
        { id = "66760529-5a60-4bc3-861b-6694d571f5a1", nm = "shieldPavise_RW_A", shield = true },
    } },
    { g = "04cdf545-216f-40a9-8bbe-e3df62c6c9c4", n = "merc_weapon_axeshield_weak_3", items = {
        { id = "81494400-b654-4aa7-8f31-c95c689db5f6", nm = "axeWork02", shield = false },
        { id = "310faab5-8502-47b2-adf8-22149d97d8b6", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "8cadc064-2b10-4c83-b623-baa48ed00887", n = "merc_weapon_axeshield_weak_4", items = {
        { id = "53612e76-76fd-4dca-84b6-7905b986dc3b", nm = "axeBattle01", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "75619084-5ad1-4b57-9367-3cf4b5564d4c", n = "merc_weapon_axeshield_medium_1", items = {
        { id = "c25fc705-c957-4c9a-a831-0f112e3b148d", nm = "kovaniPoklad_adornedAxe", shield = false },
        { id = "8baa70c0-222a-42dc-a289-035c83a33d5e", nm = "shieldHeater_whole_K", shield = true },
    } },
    { g = "841b2ea4-fc4a-4b9c-8bda-7e982f90945d", n = "merc_weapon_axeshield_medium_2", items = {
        { id = "e2cf3e8b-b411-43a0-a7ed-2674ae8ac4d2", nm = "poi_ratborschButcherAxe", shield = false },
        { id = "4bfa707e-2a7b-4091-8230-0b7d83da716a", nm = "shieldHeater_chevronny_gw", shield = true },
    } },
    { g = "67b28c22-75ae-46c1-9fbb-74c4e5404bc8", n = "merc_weapon_axeshield_medium_3", items = {
        { id = "eeeb5a48-9a97-41a6-aee0-3e1b64fc2405", nm = "axeCuman", shield = false },
        { id = "310faab5-8502-47b2-adf8-22149d97d8b6", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "d5320f5a-4b3f-4b24-a396-642e82ede04e", n = "merc_weapon_axeshield_medium_4", items = {
        { id = "bd74ce18-2623-48ba-a1a1-c9b09bbb2827", nm = "axeBattle02", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "a1bdde2f-5c26-4cc8-8f97-97e7e5120832", n = "merc_weapon_axeshield_strong_1", items = {
        { id = "0802c111-75aa-4b9c-9a3f-f30bac55fbc7", nm = "axeWork02_kunesh", shield = false },
        { id = "e4e1b22a-428a-4e20-aa92-ce216b324c0a", nm = "shieldKite_whole_K", shield = true },
    } },
    { g = "4f4e5cd2-fea7-486d-86c1-b0636631ff54", n = "merc_weapon_axeshield_strong_2", items = {
        { id = "50a9ac1e-dbb5-480b-8b5e-2ba3a1ff8d82", nm = "axeFancy", shield = false },
        { id = "2fd517a8-e990-45a1-8fbc-e4b3636cf30a", nm = "shieldKite_whole_T", shield = true },
    } },
    { g = "4da2558e-7c3b-4e71-9a0f-4e0fb96e31f7", n = "merc_weapon_axeshield_strong_3", items = {
        { id = "214ffcdd-a7a7-4b7a-b484-f60c8d00b39b", nm = "axeBattle04", shield = false },
        { id = "310faab5-8502-47b2-adf8-22149d97d8b6", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "a03246b9-5795-4b88-8a09-2558cd3f2b21", n = "merc_weapon_axeshield_strong_4", items = {
        { id = "0f0164d5-3746-4d07-a1ed-0f138225a6d9", nm = "axeBattle03", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "e9304794-d205-41a9-bc2c-4b91ef966d81", n = "merc_weapon_maceshield_weak_1", items = {
        { id = "cff7ae16-d134-41bd-9394-89e8c3970f94", nm = "maceClub", shield = false },
        { id = "292ea6c3-92b9-40a1-890c-d558ab00a8f2", nm = "shieldPavise_GY_A", shield = true },
    } },
    { g = "cb350569-6753-40c2-bca8-e9bd059dfe56", n = "merc_weapon_maceshield_weak_2", items = {
        { id = "007907cf-aeb9-4dfa-ad3f-e0262893e423", nm = "maceClubSpiked", shield = false },
        { id = "66760529-5a60-4bc3-861b-6694d571f5a1", nm = "shieldPavise_RW_A", shield = true },
    } },
    { g = "8cd52efe-5c75-4ca4-a73e-d742856de6ad", n = "merc_weapon_maceshield_weak_3", items = {
        { id = "9cc07405-4195-46ab-bf17-fd0fd99721bd", nm = "mace01", shield = false },
        { id = "310faab5-8502-47b2-adf8-22149d97d8b6", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "05de7ab9-82dd-44db-8dcf-c065a3f88f4f", n = "merc_weapon_maceshield_weak_4", items = {
        { id = "c64dcd8b-df93-4cb5-a80a-c71eb84ac6b0", nm = "maceZizka", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "65804416-c27f-4a7b-bae2-40cc77d3bbec", n = "merc_weapon_maceshield_medium_1", items = {
        { id = "00b0039b-daa4-4f32-ac7f-69a6a2e0add8", nm = "maceDagger", shield = false },
        { id = "8baa70c0-222a-42dc-a289-035c83a33d5e", nm = "shieldHeater_whole_K", shield = true },
    } },
    { g = "946bd250-054d-49c7-a773-de35475c7f1a", n = "merc_weapon_maceshield_medium_2", items = {
        { id = "f65df177-966b-48e5-8cc6-26a4f95e41b0", nm = "maceBailiff", shield = false },
        { id = "4bfa707e-2a7b-4091-8230-0b7d83da716a", nm = "shieldHeater_chevronny_gw", shield = true },
    } },
    { g = "e72434c6-0ce9-4a03-a9a1-a34586b5f141", n = "merc_weapon_maceshield_medium_3", items = {
        { id = "af6a6142-c6f7-4ae7-94a9-bb5be41ebecc", nm = "maceHeavy", shield = false },
        { id = "310faab5-8502-47b2-adf8-22149d97d8b6", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "b5a967b8-4ed8-4814-b233-a7b4125375d2", n = "merc_weapon_maceshield_medium_4", items = {
        { id = "c67de991-e22a-4a19-8b68-9369919c41dd", nm = "mace02", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "45ca9e2a-16a1-445c-8b25-040f60987283", n = "merc_weapon_maceshield_strong_1", items = {
        { id = "839992c8-657b-4d5e-97c9-96ff94430d72", nm = "mace03", shield = false },
        { id = "e4e1b22a-428a-4e20-aa92-ce216b324c0a", nm = "shieldKite_whole_K", shield = true },
    } },
    { g = "56035f56-6a73-4ed7-87bf-8896f24ec33f", n = "merc_weapon_maceshield_strong_2", items = {
        { id = "f2e86f22-8932-4751-8f62-fb1b8b846ddf", nm = "maceHetman", shield = false },
        { id = "2fd517a8-e990-45a1-8fbc-e4b3636cf30a", nm = "shieldKite_whole_T", shield = true },
    } },
    { g = "232574b9-4aef-42f2-8b78-8218d8702ddb", n = "merc_weapon_maceshield_strong_3", items = {
        { id = "65a211bd-2c7e-40a8-984f-66c8730444e4", nm = "mace04", shield = false },
        { id = "ff806e40-25fb-47de-934b-78c1bd97ef25", nm = "UNKNOWN_ITEM", shield = false },
    } },
    { g = "fca40a2e-4d33-4675-8dc2-a918c0998198", n = "merc_weapon_archerset_weak_1", items = {
        { id = "0fffb172-2183-4545-bbdb-01e04a3ff32f", nm = "bow_b", shield = false },
        { id = "ad6f0f01-aec4-44d1-982c-1210eb01b74a", nm = "arrow_normal", shield = false },
        { id = "652db434-b7d6-448f-8671-10ca787ba1e2", nm = "shortswordCleaver", shield = false },
    } },
    { g = "4838fefa-bd2f-433f-861a-6599e2182f5b", n = "merc_weapon_archerset_weak_2", items = {
        { id = "db354284-2cf9-40a4-bcfc-e78d020204af", nm = "bow_b_a", shield = false },
        { id = "ad6f0f01-aec4-44d1-982c-1210eb01b74a", nm = "arrow_normal", shield = false },
        { id = "efa237c7-3905-4813-b9c3-a32b449c17ad", nm = "shortswordCommon", shield = false },
    } },
    { g = "d6d73839-0334-4e24-adfe-3fa4b6cbdd2c", n = "merc_weapon_archerset_medium_1", items = {
        { id = "7b77a0e9-91cd-403f-be3e-6be6bac8e589", nm = "cuman_bow_b", shield = false },
        { id = "710e3706-8974-404b-b23a-6f51670ef1ed", nm = "arrow_hunting", shield = false },
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
    } },
    { g = "fe692cff-7236-4cfd-af19-bc44e3d20f19", n = "merc_weapon_archerset_medium_2", items = {
        { id = "f54e6116-6c6c-4712-99a9-8a11e3416e2b", nm = "bow_c_b", shield = false },
        { id = "710e3706-8974-404b-b23a-6f51670ef1ed", nm = "arrow_hunting", shield = false },
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
    } },
    { g = "561167b1-0775-4066-8110-8c390e21ff95", n = "merc_weapon_archerset_strong_1", items = {
        { id = "b4a0b9c9-bf92-4cce-ad43-f20f57c892b9", nm = "bow_d", shield = false },
        { id = "802507e9-d620-47b5-ae66-08fcc314e26a", nm = "arrow_enh_hunting", shield = false },
        { id = "e37bdf86-4cc8-4805-b04c-3b05964b9484", nm = "shortSwordBasilard", shield = false },
    } },
    { g = "94c8ab63-cf02-471d-a6eb-7807623c8265", n = "merc_weapon_archerset_strong_2", items = {
        { id = "77262956-daee-4a0e-9035-517569f18ef4", nm = "bow_d_a", shield = false },
        { id = "a5b31bbc-1e11-4831-835b-c06d5b13a7da", nm = "arrow_enh_piercing", shield = false },
        { id = "b3f7a363-5526-45b1-a32b-422a0a8e4da4", nm = "shortswordHeavy", shield = false },
    } },
    { g = "1a2b3c4d-5e6f-4a7b-8c9d-0e1f2a3b4c5d", n = "merc_weapon_archerset_crossbow_weak_1", items = {
        { id = "7673efc2-0566-4dde-9e18-f96c7790ce2e", nm = "crossbowLightCheap01", shield = false },
        { id = "8460003f-637f-4713-92c9-4954037c4b9c", nm = "bolt_normal", shield = false },
        { id = "652db434-b7d6-448f-8671-10ca787ba1e2", nm = "shortswordCleaver", shield = false },
    } },
    { g = "2b3c4d5e-6f7a-4b8c-9d0e-1f2a3b4c5d6e", n = "merc_weapon_archerset_crossbow_weak_2", items = {
        { id = "cb6ee20b-6eee-434c-af4c-8031502e2bec", nm = "crossbowLightNormal01", shield = false },
        { id = "8460003f-637f-4713-92c9-4954037c4b9c", nm = "bolt_normal", shield = false },
        { id = "efa237c7-3905-4813-b9c3-a32b449c17ad", nm = "shortswordCommon", shield = false },
    } },
    { g = "3c4d5e6f-7a8b-4c9d-0e1f-2a3b4c5d6e7f", n = "merc_weapon_archerset_crossbow_medium_1", items = {
        { id = "b77f912a-042b-47ca-8f42-5fddbcad3763", nm = "crossbowMediumCheap01", shield = false },
        { id = "40337bef-e965-4a60-abee-695e9a784fa4", nm = "bolt_hunting", shield = false },
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
    } },
    { g = "4d5e6f7a-8b9c-4d0e-1f2a-3b4c5d6e7f8a", n = "merc_weapon_archerset_crossbow_medium_2", items = {
        { id = "48f25a62-e787-490e-83e9-9335bf303ef9", nm = "crossbowMediumNormal01", shield = false },
        { id = "40337bef-e965-4a60-abee-695e9a784fa4", nm = "bolt_hunting", shield = false },
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
    } },
    { g = "5e6f7a8b-9c0d-4e1f-2a3b-4c5d6e7f8a9b", n = "merc_weapon_archerset_crossbow_strong_1", items = {
        { id = "f0fb0494-6ebd-4c6a-bb9e-ef396db3c5d4", nm = "crossbowHeavyNormal01", shield = false },
        { id = "b738d184-4ae1-4d74-8fac-b8db1943b1d4", nm = "bolt_enh_hunting", shield = false },
        { id = "e37bdf86-4cc8-4805-b04c-3b05964b9484", nm = "shortSwordBasilard", shield = false },
    } },
    { g = "6f7a8b9c-0d1e-4f2a-3b4c-5d6e7f8a9b0c", n = "merc_weapon_archerset_crossbow_strong_2", items = {
        { id = "588c12c6-f0fb-4b3e-847d-ce1df2739e73", nm = "crossbowHeavyCheap01", shield = false },
        { id = "b738d184-4ae1-4d74-8fac-b8db1943b1d4", nm = "bolt_enh_hunting", shield = false },
        { id = "b3f7a363-5526-45b1-a32b-422a0a8e4da4", nm = "shortswordHeavy", shield = false },
    } },
    { g = "7a8b9c0d-1e2f-4a3b-4c5d-6e7f8a9b0c1d", n = "merc_weapon_archerset_handcannon_weak_1", items = {
        { id = "ea78735d-b371-46d4-a039-bef0ebbb088e", nm = "handgonneNormal01", shield = false },
        { id = "f10ded12-a41c-40bf-a8ae-883d4e845059", nm = "shot_ball", shield = false },
        { id = "652db434-b7d6-448f-8671-10ca787ba1e2", nm = "shortswordCleaver", shield = false },
    } },
    { g = "8b9c0d1e-2f3a-4b4c-5d6e-7f8a9b0c1d2e", n = "merc_weapon_archerset_handcannon_weak_2", items = {
        { id = "d9ccf323-7ca7-4d05-b8fb-213c748bb23e", nm = "hookgunNormal01", shield = false },
        { id = "f10ded12-a41c-40bf-a8ae-883d4e845059", nm = "shot_ball", shield = false },
        { id = "efa237c7-3905-4813-b9c3-a32b449c17ad", nm = "shortswordCommon", shield = false },
    } },
    { g = "9c0d1e2f-3a4b-4c5d-6e7f-8a9b0c1d2e3f", n = "merc_weapon_archerset_handcannon_medium_1", items = {
        { id = "2694bfef-be40-4fb2-901b-e010eaede3ec", nm = "handgunFancy01", shield = false },
        { id = "f10ded12-a41c-40bf-a8ae-883d4e845059", nm = "shot_ball", shield = false },
        { id = "9aa773b1-ede0-4ff5-bbd8-2595b36c8a1a", nm = "shortswordBroad", shield = false },
    } },
    { g = "0d1e2f3a-4b5c-4d6e-7f8a-9b0c1d2e3f4a", n = "merc_weapon_archerset_handcannon_strong_1", items = {
        { id = "842c178a-54b8-4c2b-8255-77d430165320", nm = "hookgunFancy01", shield = false },
        { id = "f10ded12-a41c-40bf-a8ae-883d4e845059", nm = "shot_ball", shield = false },
        { id = "e37bdf86-4cc8-4805-b04c-3b05964b9484", nm = "shortSwordBasilard", shield = false },
    } },
}

local function auditLog(msg) System.LogAlways("[WpnAudit] " .. tostring(msg)) end

-- Souls to spawn the lineup on. The default is a merc soul, which gives a lineup
-- that just stands there; passing an EnemyGroups key reproduces the exact
-- character the missing-weapon reports come from (and they will be hostile).
function mercenaries:WeaponAuditSoul(source)
    if source and self.EnemyGroups and self.EnemyGroups[source] then
        local melee = self.EnemyGroups[source].melee
        if melee and melee[1] then return melee[1].guid end
    end
    local list = (self.Souls and (self.Souls.strong or self.Souls.weak)) or nil
    return list and list[1] or nil
end

-- Check one live NPC against the preset he was given. Returns missing, total and
-- a printable "item=ok item=MISSING" line. Shields are reported but never counted
-- as failures.
--
-- FindItem only proves the item reached the inventory, which is NOT the same as
-- the NPC visibly holding it - a polearm or a handcannon has no sheathed carry
-- pose, so it renders nowhere until it is drawn. hand=/drawn= come from
-- Human:GetItemInHand / IsWeaponDrawn and are what the eye is actually judging.
function mercenaries:WeaponAuditCheck(ent, preset)
    local missing, total, parts = 0, 0, {}
    if not (ent and ent.inventory and preset) then return 0, 0, "no inventory" end
    for _, it in ipairs(preset.items) do
        local id
        pcall(function() id = ent.inventory:FindItem(it.id) end)
        local have = (id ~= nil)
        if not it.shield then
            total = total + 1
            if not have then missing = missing + 1 end
        end
        parts[#parts + 1] = it.nm .. "=" .. (have and "ok" or "MISSING")
            .. (it.shield and "(shield)" or "")
    end

    local inHand, drawn
    pcall(function() inHand = ent.human:GetItemInHand(0) end)
    if inHand == nil then pcall(function() inHand = ent.human:GetItemInHand(1) end) end
    pcall(function() drawn = ent.human:IsWeaponDrawn() end)
    parts[#parts + 1] = "hand=" .. (inHand ~= nil and "ok" or "EMPTY")
        .. " drawn=" .. tostring(drawn == true)

    return missing, total, table.concat(parts, " ")
end

-- Spawn the lineup. startIdx/count slice mercenaries.WeaponAuditPresets;
-- soulSource is nil (merc soul) or an EnemyGroups key such as "bandit".
function mercenaries:WeaponAuditSpawn(startIdx, count, soulSource)
    startIdx = tonumber(startIdx) or 1
    count    = tonumber(count) or (#self.WeaponAuditPresets - startIdx + 1)
    local soulGuid = self:WeaponAuditSoul(soulSource)
    if not soulGuid then auditLog("no soul to spawn on") return end

    self:WeaponAuditClear()

    local ok, err = pcall(function()
        local spawnPos, playerRot = self:GetSafeSpawnPosition(player, 6)
        if not spawnPos then auditLog("no safe spawn position") return end

        local playerPos = player:GetWorldPos()
        local awayX, awayY = 0, 1
        if playerPos then
            awayX, awayY = spawnPos.x - playerPos.x, spawnPos.y - playerPos.y
            local len = math.sqrt(awayX * awayX + awayY * awayY)
            if len > 0.01 then awayX, awayY = awayX / len, awayY / len
            else awayX, awayY = 0, 1 end
        end
        local rightX, rightY = awayY, -awayX

        local rowSize = self.WeaponAuditRowSize
        local spawned, failed = 0, 0

        for n = 0, count - 1 do
            local idx = startIdx + n
            local preset = self.WeaponAuditPresets[idx]
            if preset then
                local col = n % rowSize
                local row = math.floor(n / rowSize)
                local colOffset = (col - (rowSize - 1) / 2) * self.WeaponAuditSpacing
                local rowOffset = row * self.WeaponAuditRankGap
                local pos = self:FindValidGround({
                    x = spawnPos.x + rightX * colOffset + awayX * rowOffset,
                    y = spawnPos.y + rightY * colOffset + awayY * rowOffset,
                    z = spawnPos.z
                }, spawnPos.z)

                local entityName = self.WeaponAuditPrefix .. string.format("%03d", idx)
                    .. "_" .. preset.n
                System.SpawnEntity({
                    class = "NPC",
                    name = entityName,
                    position = pos,
                    orientation = { x = 0, y = 0, z = (playerRot and playerRot.z) or 0 },
                    properties = { guidSharedSoulId = soulGuid }
                })

                local ent = System.GetEntityByName(entityName)
                if ent then
                    -- Clothes first: an NPC that has never worn a preset is a poor
                    -- subject for an equip test (see EquipEnemy's note).
                    pcall(function() self:EquipMercenary(ent, 1) end)
                    pcall(function() ent.actor:EquipWeaponPreset(preset.g) end)

                    local missing, total, detail = self:WeaponAuditCheck(ent, preset)
                    self.WeaponAuditSpawned[entityName] = { idx = idx, preset = preset, ent = ent }
                    spawned = spawned + 1
                    if missing > 0 or total == 0 then
                        failed = failed + 1
                        auditLog(string.format("FAIL  #%03d r%dc%-2d %-40s %s",
                            idx, row + 1, col + 1, preset.n, detail))
                    else
                        auditLog(string.format("ok    #%03d r%dc%-2d %-40s %s",
                            idx, row + 1, col + 1, preset.n, detail))
                    end
                else
                    auditLog(string.format("FAIL  #%03d %-40s entity did not spawn", idx, preset.n))
                end
            end
        end

        auditLog(string.format("lineup: %d spawned, %d with no weapon in inventory. "
            .. "Rows of %d, rank 1 nearest you, numbered left to right.",
            spawned, failed, rowSize))
    end)
    if not ok then auditLog("spawn error: " .. tostring(err)) end
end

-- Tell the whole lineup to draw. The draw is animated, so give it a few seconds
-- before merc_wpn_audit_report reads the hands back.
function mercenaries:WeaponAuditDraw()
    local n = 0
    for name, _ in pairs(self.WeaponAuditSpawned) do
        local ent = System.GetEntityByName(name)
        if ent then
            pcall(function() ent.human:DrawWeapon() end)
            n = n + 1
        end
    end
    auditLog("told " .. n .. " to draw; give it a few seconds, then merc_wpn_audit_report.")
end

-- Re-check everything currently standing and log the failures. After a
-- merc_wpn_audit_draw, an empty hand on a preset whose items are all "ok" is the
-- interesting case: the data is fine and the weapon still is not being held.
function mercenaries:WeaponAuditReport()
    local n, bad, empty = 0, 0, 0
    for name, rec in pairs(self.WeaponAuditSpawned) do
        local ent = System.GetEntityByName(name)
        if ent then
            n = n + 1
            local missing, total, detail = self:WeaponAuditCheck(ent, rec.preset)
            if missing > 0 or total == 0 then
                bad = bad + 1
                auditLog(string.format("FAIL  #%03d %-40s %s", rec.idx, rec.preset.n, detail))
            elseif string.find(detail, "hand=EMPTY", 1, true) then
                empty = empty + 1
                auditLog(string.format("HAND  #%03d %-40s %s", rec.idx, rec.preset.n, detail))
            end
        end
    end
    auditLog(string.format("re-check: %d standing, %d missing an item, %d holding nothing.",
        n, bad, empty))
end

-- Which one am I looking at: the nearest lineup NPC, his index, preset and result.
function mercenaries:WeaponAuditWho()
    local p = player and player:GetWorldPos()
    if not p then return end
    local bestName, bestRec, bestD = nil, nil, 1e9
    for name, rec in pairs(self.WeaponAuditSpawned) do
        local ent = System.GetEntityByName(name)
        if ent then
            local q = ent:GetWorldPos()
            if q then
                local dx, dy, dz = q.x - p.x, q.y - p.y, q.z - p.z
                local d = dx * dx + dy * dy + dz * dz
                if d < bestD then bestName, bestRec, bestD = name, rec, d end
            end
        end
    end
    if not bestRec then auditLog("no lineup NPC nearby - run merc_wpn_audit first.") return end
    local ent = System.GetEntityByName(bestName)
    local missing, total, detail = self:WeaponAuditCheck(ent, bestRec.preset)
    auditLog(string.format("nearest (%.1fm): #%03d %s [%s] -> %s%s",
        math.sqrt(bestD), bestRec.idx, bestRec.preset.n, bestRec.preset.g, detail,
        (missing > 0 or total == 0) and "  <<< UNARMED" or ""))
end

function mercenaries:WeaponAuditClear()
    local n = 0
    for name, _ in pairs(self.WeaponAuditSpawned) do
        local ent = System.GetEntityByName(name)
        if ent then
            pcall(function() System.RemoveEntity(ent.id) end)
            n = n + 1
        end
    end
    self.WeaponAuditSpawned = {}
    if n > 0 then auditLog("cleared " .. n .. " lineup NPCs.") end
end

-- No spawning: list the presets whose item ids are in no item table at all. A
-- preset the engine cannot resolve arms nobody, shield or not.
function mercenaries:WeaponAuditStatic()
    local bad = 0
    for i, preset in ipairs(self.WeaponAuditPresets) do
        for _, it in ipairs(preset.items) do
            if it.nm == "UNKNOWN_ITEM" then
                bad = bad + 1
                auditLog(string.format("#%03d %-40s unknown item_class_id %s", i, preset.n, it.id))
            end
        end
    end
    auditLog(string.format("%d presets total, %d bad item references.",
        #self.WeaponAuditPresets, bad))
end

mercenaries:DevCommand("merc_wpn_audit",        "mercenaries:WeaponAuditSpawn()",                 "Spawn one NPC per mod weapon preset in a numbered grid and log who ended up unarmed")
mercenaries:DevCommand("merc_wpn_audit_enemy",  "mercenaries:WeaponAuditSpawn(1, nil, 'bandit')", "Same lineup on a bandit enemy soul (hostile) so it matches the reported bug exactly")
mercenaries:DevCommand("merc_wpn_audit_p1",     "mercenaries:WeaponAuditSpawn(1, 24)",            "Lineup, presets 1-24 only")
mercenaries:DevCommand("merc_wpn_audit_p2",     "mercenaries:WeaponAuditSpawn(25, 24)",           "Lineup, presets 25-48 only")
mercenaries:DevCommand("merc_wpn_audit_p3",     "mercenaries:WeaponAuditSpawn(49, 24)",           "Lineup, presets 49-72 only")
mercenaries:DevCommand("merc_wpn_audit_p4",     "mercenaries:WeaponAuditSpawn(73, 24)",           "Lineup, presets 73-96 only")
mercenaries:DevCommand("merc_wpn_audit_p5",     "mercenaries:WeaponAuditSpawn(97, 25)",           "Lineup, presets 97-121 only")
mercenaries:DevCommand("merc_wpn_audit_draw",   "mercenaries:WeaponAuditDraw()",                  "Make the whole lineup draw, so an empty hand means something is really wrong")
mercenaries:DevCommand("merc_wpn_audit_who",    "mercenaries:WeaponAuditWho()",                   "Name the lineup NPC you are standing next to, and say whether his weapon landed")
mercenaries:DevCommand("merc_wpn_audit_report", "mercenaries:WeaponAuditReport()",                "Re-check the standing lineup and log only the unarmed ones")
mercenaries:DevCommand("merc_wpn_audit_clear",  "mercenaries:WeaponAuditClear()",                 "Despawn the lineup")
mercenaries:DevCommand("merc_wpn_audit_static", "mercenaries:WeaponAuditStatic()",                "No spawning: list presets referencing an item_class_id that is in no item table")
