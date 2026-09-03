-- GENERATED FILE - DO NOT EDIT BY HAND.
-- Source: data/libs/tables/rpg/buff__mercenaries.xml
-- Regenerate: python tools/gen_buff_ids.py
--
-- Every buff this mod defines. merc_purge_buffs takes the lot off Henry, because
-- a buff id on a soul is a dangling table reference once the mod is gone. The
-- persistent flag is the one that matters for a SAVE: a non-persistent buff dies
-- with the session anyway, so it is recorded but cannot be the load-time cost.

mercenaries.ModBuffIds = {
    { id = "b8f4a2c1-3d7e-4f90-8b5a-6c2d9e1f0a3b", name = "mercenary_speed_boost", persistent = false },
    { id = "c1d2e3f4-a5b6-47c8-9d0e-1f2a3b4c5d6e", name = "merc_hungry_debuff", persistent = false },
    { id = "d2e3f4a5-b6c7-48d9-8e0f-2a3b4c5d6e7f", name = "merc_drink_buff", persistent = false },
    { id = "e5a10001-2c4b-4e6a-9f01-000000000001", name = "merc_cbt_dn2", persistent = false },
    { id = "e5a10002-2c4b-4e6a-9f01-000000000002", name = "merc_cbt_dn1", persistent = false },
    { id = "e5a10003-2c4b-4e6a-9f01-000000000003", name = "merc_cbt_up1", persistent = false },
    { id = "e5a10004-2c4b-4e6a-9f01-000000000004", name = "merc_cbt_up2", persistent = false },
    { id = "e5a10005-2c4b-4e6a-9f01-000000000005", name = "merc_cbt_up3", persistent = false },
    { id = "e5a10006-2c4b-4e6a-9f01-000000000006", name = "merc_cbt_up4", persistent = false },
    { id = "e5a10007-2c4b-4e6a-9f01-000000000007", name = "merc_alchemy_buff", persistent = false },
    { id = "e5a10011-2c4b-4e6a-9f01-000000000011", name = "merc_keepup_buff", persistent = false },
    { id = "e5a10013-2c4b-4e6a-9f01-000000000013", name = "merc_horse_keepup_buff", persistent = false },
    { id = "e5a10012-2c4b-4e6a-9f01-000000000012", name = "merc_raborsch_defender", persistent = false },
    { id = "e5a10008-2c4b-4e6a-9f01-000000000008", name = "merc_static_archer_buff", persistent = false },
    { id = "e5a10009-2c4b-4e6a-9f01-000000000009", name = "heinrich_imba_buff", persistent = false },
    { id = "e5a10010-2c4b-4e6a-9f01-000000000010", name = "merc_low_morale", persistent = false },
    { id = "e5a10020-2c4b-4e6a-9f01-000000000020", name = "merc_exhausted", persistent = false },
    { id = "e5a10021-2c4b-4e6a-9f01-000000000021", name = "merc_injured", persistent = false },
    { id = "e5a10022-2c4b-4e6a-9f01-000000000022", name = "merc_no_drink", persistent = false },
    { id = "e5a10023-2c4b-4e6a-9f01-000000000023", name = "merc_starvation_mild", persistent = false },
    { id = "e5a10024-2c4b-4e6a-9f01-000000000024", name = "merc_starvation_strong", persistent = false },
    { id = "f123ee45-aade-4a13-a776-597c97d34bab", name = "merc_decreaseddamageintake", persistent = false },
}
