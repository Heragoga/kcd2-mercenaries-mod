# -*- coding: utf-8 -*-
"""The custom-companion roster. tools/gen_companions.py turns this into XML/Lua/loc.

Every entry clones a vanilla named character: its head/hair/beard, its skald_character
row (so the name and voice come from the base game for free) and its gear. Where the
character has no fightable kit in vanilla, cloth/weap build one instead - see
docs/companions.md.
"""

# Souls continue the existing run: the last group is c098c5b1 + a FOUR digit counter,
# 1801..1817 so far, so ccid N -> 1800 + (N - 1). Five digits makes a 13-character
# group and the engine gets something that is not a guid.
SOUL_PREFIX = "c2a51ce4-449f-4a2e-83b9-c098c5b1"

CATEGORIES = [
    ("lords",   "Lords and knights"),
    ("crowns",  "Crowns and courts"),
    ("zizka",   "Zizka's company"),
    ("skalitz", "Skalitz and old friends"),
    ("rogues",  "Rogues and freeriders"),
]

# Existing companions, ccid 1-18. Already wired everywhere; listed here only so the
# hire menu can be regenerated with all 44 sorted into categories. Their loc rows
# already exist under these keys and are left alone.
EXISTING = [
    (1,  "kubenka",   "zizka"),
    (2,  "vasko",     "skalitz"),
    (3,  "jasak",     "rogues"),
    (4,  "bartosch",  "skalitz"),
    (5,  "gnarly",    "rogues"),
    (6,  "jan_posy",  "rogues"),
    (7,  "miroslav",  "rogues"),
    (8,  "menhard",   "rogues"),
    (9,  "arne",      "skalitz"),
    (10, "janek",     "skalitz"),
    (11, "jaroslav",  "skalitz"),
    (12, "adder",     "zizka"),
    (13, "janosh",    "zizka"),
    (14, "mathew",    "rogues"),
    (15, "zizka",     "zizka"),
    (16, "devil",     "zizka"),
    (17, "godwin",    "zizka"),
    (18, "capon",     "crowns"),
]


def V(name):
    """Wear a preset that already exists in vanilla, unchanged."""
    return ("vanilla", name)


def B(base, drop, add):
    """Build a mod clothing preset: a vanilla one, minus drop, plus add.

    base may be None to build from nothing.
    """
    return ("build", base, drop, add)


def W(*items):
    """Build a mod weapon preset from bare item names."""
    return ("build", list(items))


ROSTER = [
 dict(ccid=19, key="radzig", cat="lords", cost=3500, name="Racek Kobyla",
      char="char_RACEK_KOBYLA", pockets="pockets_noble",
      app=dict(Head="m_head_radzig", Hair="m_hair_radzig", Beard="UC_beard_radzig",
               Underwear="m_underwear01_m01"),
      # NOT longswordRadzig - that item is IsQuestItem, and a quest item in a weapon
      # preset arms nobody. UC_Radzig is his own preset and carries longswordBroad.
      cloth=V("UC_RadzigHelmet"), weap=V("UC_Radzig"),
      note="Cuirass, brigandine arms, plate legs, his own hood. His bascinet is "
           "already the no-visor variant, so it stays."),

 dict(ccid=20, key="hanush", cat="lords", cost=3500, name="Sir Hanush of Leipa",
      char="char_HANUS_Z_LIPE", pockets="pockets_noble",
      app=dict(Head="m_head_hanush", Hair="m_hair_hanush", Beard="UC_beard_hanush",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_HanushBattle", ["BascinetVisor03_m02_A4"], ["BascinetOpen03_m01_C4"]),
      weap=V("UC_Hanus"),
      note="His full white harness and mace, open bascinet."),

 dict(ccid=21, key="erik", cat="lords", cost=3500, name="Erik",
      char="char_ERIK", pockets="pockets_noble",
      app=dict(Head="m_head_erik", Hair="m_hair_erik", Beard="m_beard_00",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_Erik", ["BascinetVisor03_mErik"], ["BascinetOpen03_m01_C4"]),
      weap=V("UC_Erik"),
      note="His brigandine harness, mail coif and hauberk, open bascinet."),

 dict(ccid=22, key="aulitz", cat="lords", cost=3000, name="Sir Markvart von Aulitz",
      char="char_MARKVART", pockets="pockets_noble",
      app=dict(Head="m_head_aulitz", Hair="m_hair_aulitz", Beard="UC_beard_aulitz",
               Underwear="m_underwear01_m01"),
      cloth=V("UC_Aulitz"), weap=V("UC_Aulitz"),
      note="Brigandine, plate arms and legs, mail collar. Bare headed."),

 dict(ccid=23, key="jobst", cat="lords", cost=3000, name="Jobst of Moravia",
      char="char_JOST_LUCEMBURSKY", pockets="pockets_noble",
      app=dict(Head="m_head_jobst", Hair="m_hair_jobst", Beard="UC_beard_jobst",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_JobstBattle", ["BascinetVisor01_m02_C3"], ["BascinetOpen08_m01_B3"]),
      weap=V("UC_Jobst"),
      note="Cuirass, plate arms, brigandine legs, mail coif, open bascinet."),

 dict(ccid=24, key="bergov", cat="lords", cost=2500, name="Sir Otto von Bergov",
      char="char_BERGOV", pockets="pockets_noble",
      app=dict(Head="m_head_bergov", Hair="m_hair_bergov", Beard="UC_beard_bergov",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_Bergov_M44b_Helmet", ["BascinetVisor01_m03_C3"], ["BascinetOpen08_m01_B3"]),
      weap=V("UC_Bergov_M44b_battle"),
      note="His arm plates and plate legs under his coat, open bascinet."),

 dict(ccid=25, key="vavak", cat="lords", cost=2500, name="Oldrich Vavak",
      char="char_OLDRICH_VAVAK", pockets="pockets_noble",
      app=dict(Head="m_head_vavak", Beard="m_beard_00", Underwear="m_underwear01_m01"),
      cloth=V("UC_VavakArmorHelmet"), weap=V("UC_Vavak"),
      note="Cuirass, plate arms, brigandine legs, open bascinet, his coat."),

 dict(ccid=26, key="ruthard", cat="lords", cost=2500, name="Kunzlin Ruthard",
      char="char_KUNZLIN_RUTHARD", pockets="pockets_noble",
      app=dict(Head="m_head_ruthard", Hair="m_hair_ruthard", Beard="UC_beard_ruthard",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_RuthardArmor", ["BascinetVisorRuthard_m01_A5"], ["BascinetOpen03_m01_C4"]),
      weap=V("UC_Ruthard_battle"),
      note="His armoured coat, mail coif, brigandine legs, open bascinet."),

 dict(ccid=27, key="samuel", cat="lords", cost=2500, name="Samuel",
      char="char_SAMUEL", pockets="pockets_soldiers_all",
      app=dict(Head="m_head_samuel", Hair="m_hair_samuel", Beard="UC_beard_samuel",
               Underwear="m_underwear01_m01"),
      # M48c not M44b: the M44b loadout carries a polearm, and a sheathed polearm
      # does not render - he would read as unarmed until he drew it.
      cloth=V("UC_SamuelArmor"), weap=V("UC_Samuel_battleM48c"),
      note="Brigandine with brigandine arms and legs, long mail, kettle hat."),

 dict(ccid=28, key="oderin", cat="lords", cost=2000, name="Martin Oderin",
      char="char_MARTIN_ODERIN", pockets="pockets_noble",
      app=dict(Head="m_head_oderin", Beard="m_beard_00", Underwear="m_underwear01_m01"),
      cloth=B("UC_MartinOderinArmor", ["BascinetVisor03_mOderin_A3"],
              ["GambesonLong01_m18_B3", "Cuirass05_m01_B3", "ArmPlate04_m02_A5",
               "BascinetOpen03_m01_C4"]),
      weap=V("UC_Oderin_battle"),
      note="His harness had no torso at all - gambeson, cuirass and arm plates added."),

 dict(ccid=29, key="istvan", cat="lords", cost=3000, name="Sir Istvan Toth",
      char="char_ISTVAN_TOTH", pockets="pockets_noble",
      app=dict(Head="m_head_istvan", Body="m_body_tan_06", Beard="m_beard_00",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_IstvanNoble", [], ["Brigandine03_m01_A4"]),
      weap=V("UC_Istvan"),
      note="A brigandine over his own short gambeson. A plate cuirass and arm harness "
           "clipped through that gambeson and through his gauntleted gloves."),

 dict(ccid=30, key="chamberlain", cat="lords", cost=1500, name="The Chamberlain of Trosky",
      char="char_KOMORI_TROSKY", pockets="pockets_burgher",
      app=dict(Head="m_head_chamberlain", Beard="m_beard_00", Underwear="m_underwear01_m01"),
      # No helmet, so his own cap stays on: the cap-under-helmet layering rule only
      # bites when there is a helmet to put over it.
      cloth=B("UC_ChamberlainArmor", [], ["Cuirass01_m01_C2"]),
      weap=V("UC_Chamberlain_battleM09"),
      note="His arm plates and brigandine legs plus a cuirass. Bare headed but for his cap."),

 dict(ccid=31, key="sigismund", cat="crowns", cost=5000, name="King Sigismund",
      char="char_ZIKMUND_LUCEMBURSKY", pockets="pockets_noble",
      app=dict(Head="m_head_zikmund", Hair="m_hair_zikmund", Beard="UC_beard_zikmund",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_Sigismund", ["HairCapSigismund_m01", "Gloves06_mChamberlain_A"],
              ["GambesonLong01_m18_B3", "Cuirass03_m01_A5", "ArmPlate04_m02_A5",
               "Gauntlets05_m01_A5", "LegsPadded01_m01_C3", "LegsPlate03_m01_A5"]),
      weap=W("longSwordDuel", "daggerCommon"),
      note="Vanilla only ever dresses him for court. Full harness under his own coat, "
           "bare headed - a king who cannot be recognised is no use to anyone."),

 dict(ccid=32, key="lichtenstein", cat="crowns", cost=3000, name="Jan II of Lichtenstein",
      char="char_JAN_II_Z_LICHTENSTEJNA", pockets="pockets_noble",
      app=dict(Head="m_head_lichtenstejn", Beard="m_beard_00", Underwear="m_underwear01_m01"),
      cloth=B("UC_Lichtenstein", ["HairCapLichtenstein_m01"],
              ["CoifMail01_m01_C2", "Brigandine03_m01_A4", "ArmPlate05_m02_B4",
               "LegsPadded01_m01_C3", "LegsBrigandine03_m02_B4", "BascinetOpen08_m01_B3",
               "Gloves05_m01_B2"]),
      weap=W("longswordSturdy"),
      note="Brigandine harness over his own gambeson, open bascinet."),

 dict(ccid=33, key="brabant", cat="crowns", cost=2500, name="Baron Vaquelin Brabant",
      char="char_VAQUELIN_BRABANT", pockets="pockets_noble",
      app=dict(Head="m_head_drabant", Hair="m_hair_drabant", Beard="UC_beard_drabant",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_Brabant", [],
              ["GambesonLong01_m16_B3", "MailLong01_m03_C5", "LegsPadded03_m01_B2",
               "LegsPlate01_m01_C3", "Gauntlets04_m03_C2"]),
      weap=V("UC_Brabant"),
      note="Keeps the armoured coat and hair cap; mail and plate legs underneath."),

 dict(ccid=34, key="musa", cat="crowns", cost=2500, name="Musa of Mali",
      char="char_MUSA_Z_MALI", pockets="pockets_soldiers_all",
      app=dict(Head="m_head_musa", Hair="m_hair_musa", Beard="UC_beard_musa",
               Body="african", Underwear="m_underwear01_m01"),
      cloth=B("UC_Musa", [],
              ["GambesonShort03_m01_A4", "MailShort01_m04_C4", "Brigandine03_m01_A4",
               "LegsPadded01_m01_C3", "LegsBrigandine03_m02_B4", "BootsKnee01_m01_C",
               "Gauntlets04_m03_C2"]),
      weap=W("sabreLionHead"),
      note="Coat and cap kept over a brigandine harness - no helmet, so he reads as Musa."),

 dict(ccid=35, key="zacharias", cat="crowns", cost=2500, name="Zacharias",
      char="char_DLC3_ZACHARIAS", pockets="pockets_noble",
      app=dict(Head="m_head_zachary", Hair="m_hair_zachary", Beard="UC_beard_zachary",
               Body="m_body_pale_04", Underwear="m_underwear01_m01"),
      cloth=B("UC_Zachary", [],
              ["GambesonLong01_m18_B3", "Brigandine03_m01_A4", "LegsPadded01_m01_C3",
               "LegsBrigandine04_m01_A5", "Gauntlets01_m01_C3"]),
      weap=W("warhammer01", "daggerCommon"),
      note="Brigandine under his own heavy coat and cap."),

 dict(ccid=36, key="martin", cat="skalitz", cost=2000, name="Martin, Henry's father",
      char="char_MARTIN_OTEC_JINDRICHA", pockets="pockets_blacksmith",
      app=dict(Head="m_head_father", Hair="m_hair_father", Beard="UC_beard_father",
               Underwear="m_underwear01_m01"),
      # No armour at all - his own cap, tunic, hose and boots, exactly as vanilla
      # dresses him, and every piece of it is cosmetic-tier (30 total).
      cloth=V("UC_Father"),
      weap=W("longswordSturdy", "daggerCommon"),
      # ...which is why he is immortal. vip class 12 is
      # immortality_and_unconsciousness_protection, the same the quartermaster and
      # Aleksej use; 16 (loot protection, what every other companion gets) is moot on
      # a man who can never end up lootable.
      vip=12,
      note="His own clothes and nothing else - no armour anywhere. Immortal, because "
           "in a shirt he would not last a single fight."),

 dict(ccid=37, key="bocek", cat="rogues", cost=1000, name="Levej Bocek",
      char="char_LEVEJ_BOCEK", pockets="pockets_soldiers_all",
      app=dict(Head="m_head_bocek", Beard="m_beard_00", Underwear="m_underwear01_m01"),
      cloth=B("UC_Bocek", ["Cap07_m02_B"],
              ["GambesonShort03_m01_A4", "MailShort02_m01_C1", "Brigandine02_m01_E2",
               "LegsPadded03_m01_B2", "SkullCap03_m01_D2"]),
      weap=W("mace02"),
      note="Kuttenberg bruiser: light brigandine and a skullcap over his own coat."),

 dict(ccid=38, key="pisek", cat="rogues", cost=1200, name="Petr of Pisek",
      char="char_PETR_Z_PISKU", pockets="pockets_soldiers_all",
      app=dict(Head="m_head_pisek", Hair="m_hair_pisek", Beard="UC_beard_pisek",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_Pisek", ["Cap18_mPisek_A"],
              ["GambesonLong01_m04_C3", "MailShort01_m04_C4", "Cuirass04_m01_E2",
               "LegsPadded03_m01_B2", "Gauntlets04_m03_C2", "CoifMail01_m01_C2"]),
      weap=W("shortswordBroad"),
      note="Old munitions cuirass and mail under his own hood and coat."),

 dict(ccid=39, key="painter", cat="rogues", cost=800, name="The Painter",
      char="char_MALIR_DLC1", pockets="pockets_burgher",
      app=dict(Head="m_head_painter", Hair="m_hair_006_black", Beard="UC_beard_painter",
               Underwear="m_underwear01_m01"),
      cloth=B("UC_Painter", ["CapPainter_m01"],
              ["GambesonShort01_m01_D2", "MailShort02_m01_C1", "CoifSmall01_m01_C2",
               "SkullCap03_m01_D2", "Gloves05_m01_B2", "LegsPadded03_m01_B2"]),
      weap=W("huntingSwordBasic", "daggerCommon"),
      note="Invented kit: a town levy's mail and skullcap over his paint-stained tunic."),

 dict(ccid=40, key="hertl", cat="zizka", cost=1200, name="Hertl",
      char="char_HERTL_ZIZKA_BAND", pockets="pockets_soldiers_all",
      app=dict(Head="m_head_044_b00", Hair="m_hair_009_dark_brown", Beard="m_beard_15"),
      cloth=V("tneb_hertl_M07"), weap=V("tneb_Hertl_M07"),
      note="His Nebakov kit as-is: kettle hat, mail, brigandine legs, gauntlets."),

 dict(ccid=41, key="pelcl", cat="zizka", cost=1000, name="Pelcl",
      char="char_PELCL_ZIZKA_BAND", pockets="pockets_soldiers_all",
      app=dict(Head="m_head_045_b00", Hair="m_hair_001_black", Beard="m_beard_04"),
      cloth=B("tneb_Pelcl_M07", ["Cap03_m05_E", "CoifCap01_m01_C"],
              ["MailShort02_m01_C1", "Brigandine02_m01_E2", "LegsPadded03_m01_B2",
               "CoifSmall01_m01_C2", "KettleHat05_m01_D3"]),
      weap=V("tneb_Pecl_M07"),
      note="Vanilla has him in a gambeson and a cloth cap - brought up to a soldier's kit."),

 dict(ccid=42, key="marek", cat="zizka", cost=1200, name="Marek",
      char="char_MAREK_ZIZKA_BAND", pockets="pockets_villager",
      app=dict(Head="m_head_046", Hair="m_hair_008_blonde", Beard="m_beard_04"),
      cloth=V("tneb_Marek_M07"), weap=V("tneb_Marek_M07"),
      note="His Nebakov kit as-is: skullcap, mail, brigandine arms, crossbow."),

 dict(ccid=43, key="cverk", cat="zizka", cost=1000, name="Cverk",
      char="char_CVERK_ZIZKA_BAND", pockets="pockets_soldiers_all",
      app=dict(Head="m_head_060", Hair="m_hair_003_dark_grey", Beard="m_beard_17"),
      cloth=B("tneb_Cverk_M07", ["Cap19_m04_C", "CoifCap01_m01_C"],
              ["Brigandine02_m01_E2", "LegsPadded01_m01_C3", "LegsPlate07_m03_E1",
               "CoifSmall01_m01_C2", "KettleHat03_m01_B3", "Gloves05_m01_B2"]),
      weap=V("tneb_Cverk_M07"),
      note="Vanilla leaves him in a short gambeson - brigandine and kettle hat added."),

 dict(ccid=44, key="volek", cat="zizka", cost=1000, name="Volek",
      char="char_TOVARYS_VOLEK", pockets="pockets_blacksmith",
      app=dict(Head="m_head_001", Hair="m_hair_001_dark_brown", Beard="m_beard_13"),
      # No clothing preset of his own in vanilla at all - his inventory borrows the
      # shared blacksmith clothes ref, so the kit is built from scratch.
      cloth=B(None, [],
              ["GambesonShort01_m01_D2", "MailShort02_m01_C1", "HoseSeparate01_m10_D",
               "BootsAnkle05_m01_C", "Gloves05_m01_B2", "CoifSmall01_m01_C2",
               "SkullCap03_m01_D2", "LegsPadded03_m01_B2"]),
      weap=V("tneb_Volek_M07"),
      note="The smith's apprentice, kitted from scratch: mail, skullcap, padded legs."),
]
