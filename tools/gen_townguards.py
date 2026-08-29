"""Generates the town-watch group's XML assets: 10 clothing presets, 10 souls, a skald
character (+profession) and 10 appearance rules.

Idempotent - every block it writes is fenced by a marker comment and replaced wholesale on
a re-run, so this can be edited and run again without duplicating rows.

    python tools/gen_townguards.py

Kit is a municipal watch, not a field army: kettle hat, mail coif, short mail over a
gambeson, Kuttenberg livery over that, padded legs, hose, ankle boots, and brigandine arms
on the senior half. Budget lands ~1050-1250 (DefenseStab+Slash+Smash summed over the
outfit), which sits between the bandits (~700) and Sigismund's soldiers (~1500). See
docs/enemies.md for the budget method and the layering rules.
"""
import io, os, re

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")

PRESET_XML = "data/libs/tables/item/clothing_preset__mercenaries.xml"
SOUL_XML   = "data/libs/tables/rpg/soul__mercenaries.xml"
CHAR_XML   = "data/libs/tables/skald/skald_character__mercenaries.xml"
PROF_XML   = "data/libs/tables/skald/skald_character2profession__mercenaries.xml"
APPEAR_XML = "data/libs/Storm/appearance/enemiesappearance.xml"

BEGIN = "<!-- BEGIN generated townguard (tools/gen_townguards.py) -->"
END   = "<!-- END generated townguard -->"

# The mod's enemy brain (renegade_brain / enemy_melee_scheduler.xml), taken from the
# existing enemy souls so the watch runs the same combat stack as every other group.
BRAIN = "b3a1c7d2-4e9f-4a58-8b6d-1c3e7f9a2b40"

# Clothing preset ids continue the enemy block's own scheme: e0NN is the group index.
# The town watch is e00a.
PRESET_ID = "6d657263-e00a-4c00-9000-0000000000%02x"

# --- the wardrobe -----------------------------------------------------------------
# One tuple per man: helmet, coif, mail, gambeson, livery, arms (or None), gloves, legs,
# hose, boots. Ordered worst-first along a mild ramp, the way DiffWardrobe expects.
HELMETS = [
    "6eda54cb-f9e9-4291-a497-e183a53d259e",  # KettleHat09_m01_D2        252
    "81e27f41-709f-47c8-96b3-8f8c9619d2fa",  # KettleHat02_m01_D2        252
    "81bfb39f-d6da-4299-9776-98a93360dcff",  # KettleHat02_m02_D2        252
    "2dc6bb39-979e-462d-9f65-0c9376c6426c",  # KettleHat02_m03_D2        252
    "0a46c96b-11fa-4627-8a89-786a4577a441",  # KettleHat05_m01_D3        271
    "cc672cc6-b8a8-4604-bf1d-6f42716fab59",  # KettleHat05_m02_D3        266
    "21269950-9319-4e8e-ad07-4ef68c15a006",  # KettleHat06_m05_A4        272
    "3e63ce59-84b0-4220-870e-0c185892d1d4",  # KettleHat06_m02_A4        272
    "3437c616-a14c-4ba2-a382-f4898765eeff",  # KettleHat04_m01_B4        277
    "ac551bf3-6d8a-4531-983e-1ca104b523e6",  # KettleHat07_m01_A5        279
]
COIFS = [
    "cd17455c-b023-4977-8205-4f2685370b5e",  # CoifMail01_m04_C2         157
    "c15d6593-c1eb-470b-a2e8-823c21336b04",  # CoifMail02_mKuttenberg_B3 191  (livery)
]
MAILS = [
    "38102e92-9a28-4d57-85c4-716b97a0ecb8",  # MailShort02_m01_C1        104
    "b80a30ee-43d9-4d73-b064-b7c366320070",  # MailShort02_m02_C1        104
    "b1b9a304-4f2c-4e43-8f2c-166abf25243c",  # MailShort01_m01_C4        167
    "a5aeba9c-2e4b-4710-a6cb-5233aadab516",  # MailShort01_m02_C4        167
    "0364c89d-ac13-44ef-94d5-22b4047e7a26",  # MailShort01_m03_C4        167
]
GAMBESONS = [
    "100b9146-1c41-4136-9991-ff80983f1955",  # GambesonLong01_m01_C3      86
    "d2440b7a-a40b-4a2c-bf7d-61febcf5cfda",  # GambesonLong01_m02_C3      86
    "46b051c4-d4e2-4f3a-8b88-e3f64dae4618",  # GambesonLong01_m03_C3      86
    "a6f4fcf5-9d0a-45c4-8641-b9689415983b",  # GambesonLong01_m04_C3      86
    "e1c454dd-9834-4da0-940e-da2a27b0b795",  # GambesonLong01_m05_C3      86
]
# The livery, and the whole point of the group reading as Kuttenberg's watch.
LIVERY = [
    "343b563d-95f0-4ec2-9247-ebbde648d7ec",  # Waffenrock02_mKuttenberg01_D
    "2bac4905-4946-4a17-b728-8f059b588eb6",  # Waffenrock02_mKuttenberg02_D
    "4cbd42bc-9953-4c98-a778-f310ad909d72",  # Waffenrock02_mKuttenberg03_D
    "c8a799c5-3fda-45d0-9bde-2cbf92d83914",  # Waffenrock02_mKuttenberg_D
    "cbf60764-576b-4102-b0d1-d196e1b87fd6",  # Waffenrock09_mKuttenberg01_B
    "359700c7-14ec-413d-924d-b0a682ecb22b",  # Waffenrock09_mKuttenberg02_B
    "cb3e9e80-7a1e-4021-8dc9-46defbdcd069",  # Waffenrock09_mKuttenberg03_B
    "88c42663-ca9b-4fea-8f62-84488ba8cb1d",  # Waffenrock09_mKuttenberg04_B
    "dd0d1adc-8bb0-4352-b9c9-6b46eac72533",  # Waffenrock09_mKuttenberg05_B
    "217b1ae7-3ac5-447c-8b48-05c99ceb4cea",  # Coat04_mKuttenberg_C
]
ARMS_LIGHT = None
ARMS_HEAVY = "86055ea8-0e06-47f2-a976-e5453bdf84d1"   # BrigandineArm01_m01_D1   240
GLOVES = [
    "b128bc50-58da-494a-ba3d-c47d2d044e7c",  # Gloves01_m01_C1            19
    "51d9a001-eb09-4db8-98f0-d23b794c530d",  # Gloves01_m02_C1            19
]
LEGS = [
    "be916959-2459-4a31-81fc-4b00090c3f42",  # LegsPadded02_m01_E1        93
    "cf672182-1c7a-404a-9af9-1b08e20d81e3",  # LegsPadded02_m02_E1        93
    "cde6db6c-302f-4484-a774-bc5d2264a0df",  # LegsPadded02_m03_E1        93
    "8a8e914e-d384-4e7b-ae5e-534f48679c85",  # LegsPadded02_m04_E1        93
    "b5bfc0d3-b4e2-421c-ae14-4bce9f1f54be",  # LegsPadded02_m05_E1        93
]
HOSE = [
    "8aae6517-dd6d-4ed1-88d0-eccff5273846", "8db59cbb-55da-437d-894f-865dd281677d",
    "be92b571-d8ec-4bee-a62e-6259fa88446c", "1b735ceb-6884-4d3f-a785-d0fddbd31653",
    "fbea7771-4176-4faf-808e-05777a946fa0",
]
BOOTS = [
    "a67fc79d-fe99-4ea7-bd60-f619d229c5cd", "4d6a1362-6bd2-4827-bdb1-33cfece59fec",
    "dcbc377e-ce87-45d6-8bd1-f7e21d84fd7c", "dea34002-3f44-4a25-891e-8674b075fed6",
    "66cc653b-8dd6-48ad-93d2-b0918fe74ae8",
]

# Faces. Pale Czech townsmen and a couple of tanned ones - the same pool the Prague
# regiment draws from, since these are the same stock of men.
FACES = [
    ("m_body_pale_01", "m_head_005", "m_hair_008_dark_brown",  "m_beard_08"),
    ("m_body_pale_02", "m_head_016", "m_hair_011_light_brown", "m_beard_02"),
    ("m_body_tan_02",  "m_head_019", "m_hair_009_dark_brown",  "m_beard_10"),
    ("m_body_pale_03", "m_head_024", "m_hair_004_dark_grey",   "m_beard_17"),
    ("m_body_pale_01", "m_head_033", "m_hair_008_dark_brown",  "m_beard_09"),
    ("m_body_tan_03",  "m_head_037", "m_hair_002_black",       "m_beard_01"),
    ("m_body_pale_02", "m_head_044", "m_hair_009_black",       "m_beard_11"),
    ("m_body_tan_04",  "m_head_059", "m_hair_008_dark_brown",  "m_beard_04"),
    ("m_body_pale_01", "m_head_063", "m_hair_004_dark_grey",   "m_beard_19"),
    ("m_body_pale_03", "m_head_069", "m_hair_009_dark_brown",  "m_beard_00"),
]

# Deterministic soul ids. Hand-authored rather than hashed so they can be grepped, and
# in the same 5-group shape as every other enemy soul in the table.
SOUL_IDS = [
    "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0001", "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0002",
    "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0003", "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0004",
    "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0005", "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0006",
    "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0007", "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0008",
    "7c9a1e50-0b21-5a01-9e10-4d1f0a7b0009", "7c9a1e50-0b21-5a01-9e10-4d1f0a7b000a",
]
# Five of the watch are seasoned (0.9), five are ordinary (0.7). No weak tier: a town
# does not put its worst men on the gate when the alarm goes up.
TIERS = [0.7] * 5 + [0.9] * 5

N = 10


def preset_items(i):
    """The ten (or nine) item guids for watchman i, worst-first."""
    out = [
        HELMETS[i],
        COIFS[i % len(COIFS)],
        MAILS[i % len(MAILS)],
        GAMBESONS[i % len(GAMBESONS)],
        LIVERY[i],
    ]
    # Brigandine arms on the senior half only, which is what separates the two tiers
    # visually as well as statistically.
    if i >= 5:
        out.append(ARMS_HEAVY)
    out += [
        GLOVES[i % len(GLOVES)],
        LEGS[i % len(LEGS)],
        HOSE[i % len(HOSE)],
        BOOTS[i % len(BOOTS)],
    ]
    return out


def build_presets():
    rows = []
    for i in range(N):
        pid = PRESET_ID % (i + 1)
        cond = 0.58 + i * 0.022          # a mild ramp: worn boots up to a good kit
        rows.append(
            '        <clothing_preset clothing_preset_id="%s" clothing_preset_name="enemy_townguard_%02d"'
            ' gender="Male" prefers_hood_on="false" social_class_id="3" Quality="2"'
            ' Condition="%.2f" ConditionVariation="0.08">\n            <Items>\n'
            % (pid, i + 1, cond)
            + "".join("                <Guid>%s</Guid>\n" % g for g in preset_items(i))
            + "            </Items>\n        </clothing_preset>"
        )
    return "\n".join(rows)


def build_souls():
    rows = []
    for i in range(N):
        rows.append(
            '       <soul brain_id="%s" combat_level="%s" digestion_multiplier="0"'
            ' factionName="enemiesFaction" initial_clothing_dirt="0"'
            ' skald_character_name="char_enemy_townguard_1" social_class_id="3"'
            ' soul_archetype_id="0" soul_id="%s" soul_name="soul_enemy_townguard_%d"'
            ' soul_vip_class_id="0" xp_multiplier="1" />'
            % (BRAIN, TIERS[i], SOUL_IDS[i], i + 1)
        )
    return "\n".join(rows)


def build_appearance():
    rows = []
    for i in range(N):
        body, head, hair, beard = FACES[i]
        rows.append(
            '        <rule name="appearance_soul_enemy_townguard_%d">\n'
            "            <selectors>\n"
            '                <hasName Name="soul_enemy_townguard_%d" />\n'
            "            </selectors>\n"
            "            <operations>\n"
            '                <setBody name="%s" />\n'
            '                <setHead name="%s" />\n'
            '                <setHair name="%s" />\n'
            '                <setBeard name="%s" />\n'
            "            </operations>\n"
            "        </rule>" % (i + 1, i + 1, body, head, hair, beard)
        )
    return "\n".join(rows)


def build_char():
    return (
        '<skald_character age="2" body_type="4"'
        ' description_string_name="char_enemy_townguard_description" gender="0"'
        ' image1="false" image2="false" image3="false" image4="false" mortality_id="0"'
        ' owner="Alex" script_owner="Alex"'
        ' skald_character_full_name_string_name="char_enemy_townguard_fullName"'
        ' skald_character_name="char_enemy_townguard_1"'
        ' ui_name_string_name="char_enemy_townguard_uiName" unique_assets=""'
        ' voice_categories="generic christian" voice_id="106" />'
    )


def build_prof():
    return ('<skald_character2profession profession_name="pocestny"'
            ' skald_character_name="char_enemy_townguard_1" />')


def splice(path, block, closing_tag):
    """Insert or replace the fenced block just before `closing_tag`."""
    full = os.path.join(ROOT, path)
    s = io.open(full, encoding="utf-8").read()
    fenced = "%s\n%s\n%s" % (BEGIN, block, END)
    if BEGIN in s:
        s = re.sub(re.escape(BEGIN) + r".*?" + re.escape(END), lambda _m: fenced, s,
                   flags=re.S)
        action = "replaced"
    else:
        i = s.rindex(closing_tag)
        s = s[:i] + fenced + "\n    " + s[i:]
        action = "inserted"
    io.open(full, "w", encoding="utf-8").write(s)
    print("  %-9s %s" % (action, path))


if __name__ == "__main__":
    print("town watch: %d men" % N)
    splice(PRESET_XML, build_presets(), "</clothing_presets>")
    splice(SOUL_XML,   build_souls(),   "</souls>")
    splice(APPEAR_XML, build_appearance(), "</rules>")
    splice(CHAR_XML,   "        " + build_char(), "</skald_characters>")
    splice(PROF_XML,   "        " + build_prof(),
           "</skald_character2professions>")
    print("done")
