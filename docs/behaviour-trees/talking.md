# Talking with Behaviour Trees

This will be a short entry compared to the behemoths that are combat, movement and basic structure. Talking is a straightforward affair and falls into two categories: direct dialog (when you look at an NPC and press E to talk), and everything else (monologs, ambient comments, NPC-to-NPC conversations where they stand facing each other and jabber at one another).

---

## Direct Dialog

The dialog itself is defined in Skald — see [add-dialog](skald/add-dialog.md) for details. The short version: every NPC has a set of roles defined in Storm, each role has dialog attached to it, and when you press E every dialog option accessible to that role appears in the UI. The E prompt exists by default if there are dialogs attached to an NPC, but if you press it on an NPC with an empty behaviour tree, nothing happens. For that you need this:

```xml
<ProcessMessage Atomic="false" timeout="'0ms'" timeType="GameTime" variable="$dialogRequest" senderInfo="" inbox="'dialogMailbox'" condition="" answerVar="">
    <Function_switch_handleDialog dialogRequest="$dialogRequest" nodeLabel="68945293" />
</ProcessMessage>
```

That's all. Call it at least every second, though more frequently is better — otherwise the player may have to wait up to a full second after pressing E before the dialog actually starts, which feels broken even if it isn't. The appropriate mailbox also has to be defined in the subbrain.

---

## Monologs

Playing a line with a single participant — the NPC talking to themselves or at the player — is very straightforward.

```xml
<Function_speech_schedulerMonolog
    alias="'bark_test_dialog_drink_4'"
    animationApproach="$enum:animationApproach.dontPlayDialogAnimations"
    context=""
    lookAtId="$__player"
    metarole=""
    skipInLod="false"
    subtitlesDown="false"
/>
```

This plays a concrete dialog you've defined yourself. The dialog definition in Skald should look like this, with the `Alias` and the `Role` matching what you've set up:

```xml
<Decision Name="dec_drink_3" Priority="General" Alias="bark_test_dialog_drink_3">
    <Sequences>
        <Sequence EndType="EndDialogue" Name="seq_drink_3">
            <DesignName StringName="merc_dream_drink_3_1" Text="seq_drink_3" />
            <Elements>
                <Response Role="role_mercenary_test"><Text StringName="merc_dream_drink_3_1"/></Response>
                <Response Role="role_mercenary_test"><Text StringName="merc_dream_drink_3_2"/></Response>
                <Response Role="role_mercenary_test"><Text StringName="merc_dream_drink_3_3"/></Response>
                <Response Role="role_mercenary_test"><Text StringName="merc_dream_drink_3_4"/></Response>
            </Elements>
        </Sequence>
    </Sequences>
</Decision>
```

### Playing vanilla voice lines via metaroles

If you want to play a line from one of the game's built-in voice pools — combat barks, injured reactions, ambient comments — use the `metarole` parameter instead of `alias`:

```xml
<Function_speech_schedulerMonolog
    alias=""
    animationApproach="$enum:animationApproach.dontPlayDialogAnimations"
    context=""
    lookAtId="$__null"
    metarole="'ZAKAZNIK_CEKA_MUZ'"
    skipInLod="false"
    subtitlesDown="false"
/>
```

Metaroles are defined by the game. Each voice has lines recorded for each metarole, and if a particular voice doesn't have a line for a given metarole the engine falls back to a similar-sounding voice. Not all of them will play flawlessly on every NPC — experiment a bit to see what works with your chosen voice ID.

Here's an overview of the most useful ones:

---

### 🗡️ Idle / Self-Talk

Makes an NPC feel alive when standing around doing nothing.

| Metarole | Meaning |
|---|---|
| `SAMOMLUVA` | Generic idle muttering |
| `HORNIK_SAMOMLUVA` | Miner-type self-talk |
| `REMESLNIK_SAMOMLUVA` | Craftsman-type self-talk |
| `ROLNIK_SAMOMLUVA` | Farmer-type self-talk |
| `ZAKAZNIK_SAMOMLUVA` | Customer/civilian self-talk |
| `UHLIC_SAMOMLUVA` | Charcoal burner self-talk |
| `LEAN_BARK` | Bark played when the NPC is leaning or loitering |
| `BATTLE_IDLE_BARK` | Idle bark during a battle — taunts, muttering |

---

### 🧠 Reacting to the Player

Comments triggered by observing the player do something.

| Metarole | Meaning |
|---|---|
| `BFF_REAGUJE_NA_HRACE_TROPICIHO_HLOUPOSTI` | "Best friend" reacts to player doing something stupid |
| `NPC_JE_ZAMEREN_HRACEM` | NPC is being aimed at by the player |
| `NPC_REAGUJE_NA_HRACE_BEZ_POCHODNI` | Reacts to player wandering around without a torch |
| `NPC_REAGUJE_NA_PACH_HRAC` | Reacts to the player's scent |
| `NPC_VIDI_HRACE_V_CROUCHI` | Spots the player crouching suspiciously |
| `NPC_VITA_HRACE_V_OBCHODE` | Greets the player entering a shop |

---

### 🤝 Companion / Buddy Awareness

Metaroles for companion-type NPCs keeping track of each other and the player.

| Metarole | Meaning |
|---|---|
| `BUDDY_SI_VSIML_ZMIZENI_NPC_A_JDE_HO_HLEDAT` | Buddy noticed an NPC disappear and goes looking |
| `NPC_REAGUJE_NA_STAV_II_(INFORMUJE_BUDDYHO)` | NPC informs their buddy of a raised alert state |
| `NPC_SI_VSIMLO_ZMIZENI_NPC_A_JDE_HO_HLEDAT` | Generic NPC noticed someone disappear and goes searching |

---

### ⚔️ Combat Reactions & Post-Fight

Lines around fighting, winning, fleeing, and the awkward aftermath.

| Metarole | Meaning |
|---|---|
| `NPC_VYHRALO_SKIRMISH` | NPC won a skirmish |
| `PO_SOUBOJI_MUZ1` | Male NPC post-fight reaction |
| `SKIRMISH_SOULFLEE` | NPC flees mid-skirmish |
| `NPC_UTIKA_Z_COMBATU` | NPC flees from combat |
| `NPC_SE_CITI_OHROZENE` | NPC feels threatened |
| `NPC_SE_CITI_OHROZENE_ZBABELEC` | Cowardly NPC feels threatened |
| `NPC_BARKUJE_V_DEFENCE_MODU_MUZ_ARMED` | Armed male defensive stance bark |
| `NPC_BARKUJE_V_DEFENCE_MODU_MUZ_UNARMED` | Unarmed male defensive stance bark |
| `NPC_JE_V_COMBATU_UNARMED_A_ROZHODLO_SE_TASIT_(HRAC_TASI)` | Unarmed NPC draws weapon because the player drew theirs |
| `NPC_JE_V_COMBATU_UNARMED_A_ROZHODLO_SE_TASIT_(NPC_LOW_HP)` | Unarmed NPC draws weapon when low on health |
| `TRAININGGROUNDS_SURRENDER` | Surrender bark at a training ground |
| `TRENINKOVY_SOUBOJ_DIVAK` | Spectator at a training fight |

---

### 🏳️ Surrender & Yielding

| Metarole | Meaning |
|---|---|
| `NPC_AKCEPTUJE_HRACOVO_VZDAVANI` | NPC accepts the player's surrender |
| `NPC_NEAKCEPTUJE_HRACOVO_VZDAVANI` | NPC refuses the player's surrender |
| `NPC_NEAKCEPTUJE_HRACOVO_VZDAVANI_NEVZDAVACI_KONTEXT` | Refuses surrender — surrendering isn't an option in this context |
| `NPC_NEAKCEPTUJE_HRACOVO_VZDAVANI_TRETI_STRANA` | Refuses surrender because a third party is present |
| `NPC_NEAKCEPTUJE_HRACOVO_VZDAVANI_VRAZDA` | Refuses surrender because a murder was committed |
| `NPC_SE_VZDAVA_PO_COMBATU` | NPC surrenders after combat |
| `NPC_PRIJIMA_VZDAVANI_Z_KOMBATU_(BARK)` | NPC accepts surrender bark |
| `NPC_PROPUSTENE_PO_VZDAVANI` | NPC is released after surrendering |
| `NPC_ZTRATILO_CIL_PRI_PRONASLEDOVANI_BEHEM_COMBATU` | NPC lost sight of target during a combat chase |

---

### 💀 Reacting to Death and Bodies

| Metarole | Meaning |
|---|---|
| `NPC_VIDI_LEZICI_TELO_Z_DALKY` | NPC spots a body lying on the ground from a distance |
| `NPC_VIDI_HRACE_JAK_HANOBI_MRTVOLU_(PRITEL)` | NPC sees the player desecrating a friend's corpse |
| `NPC_TRUCHLI_NAD_ZMIZENIM_BLIZKÉHO` | NPC mourns the disappearance of someone close |
| `NPC_HLASI_SPOLUBYDLICIMU` | NPC reports something to a bunkmate |
| `NPC_BUDI_CLOVEKA_Z_BEZVEDOMI_(BEZVEDOMI__PRITEL)` | NPC tries to wake an unconscious friend |
| `NPC_VIDI_CLOVEKA_V_BEZVEDOMI_(BEZVEDOMI__PRITEL)` | NPC sees a friend lying unconscious |
| `NPC_SE_PROBOUZI_(BEZVEDOMI__NEVI_O_HRACI)` | NPC wakes from unconsciousness, unaware of the player |
| `NPC_SE_PROBOUZI_(BEZVEDOMI__VI_O_HRACI)` | NPC wakes from unconsciousness, aware of the player |

---

### 💬 Social / Chatter

| Metarole | Meaning |
|---|---|
| `GOSSIP` | Generic gossip between NPCs |
| `FALLBACK_GOSSIP` | Fallback gossip pool |
| `ZIZKA_VYPRAVI_SEDM_STATECNYCH` | Žižka tells the story of the Seven Brave Men — very specific, probably not what you need |
| `CAMP_TRESPASS_CHAT` | Chat bark in a trespass camp zone |
| `RANENY_POVZDÉCHY` | Wounded sighs and moans |
| `OSAMOTOCNE_NPC_NASLO_HRACE_U_ZDROJE_ZVUKU` | Lone NPC found the player near a sound source |

---

That is genuinely all there is to it for talking. Compared to everything else in this guide series, dialog is mercifully simple — define the line, call the node, pick a metarole if you want vanilla flavour. The hard part is just knowing which metaroles exist and what they actually do, which is what the tables above are for.
