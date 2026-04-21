# Adding Dialog

I will mostly cover this from the perspective of behaviour trees, as that is the part I am most interested in, but it extends to everything else as well. You can technically do this via the Skald writer GUI and whatnot, but I'd advise against it. The best approach I've found is giving a chatbot (Claude, Gemini, whatever you prefer) a few vanilla dialog examples, telling it what you want the dialog to say, and letting it cook. It's a far more reliable and less painful system than writing the XML yourself, so just feed this guide to your chatbot of choice and get writing.

---

## Player ↔ NPC Dialog

The basic structure of a dialog between the player and an NPC:

```xml
<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="yourmod">
    <Skald>
        <FaderDialog Name="dismissal_dialog">
            <Ports>
                <Port Name="mercenary_dismissed" Direction="Out" Type="trigger" />
            </Ports>
            <Text StringName="ui_mercenary_dismissal_root" />
            <Dialogue TechnicalStatus="Enabled" AllowFarewell="false" AllowGreeting="false">
                <Decision Name="dec_dismiss_mercenary" Priority="General">
                    <Sequences>
                        <Sequence EndType="EndDialogue" Name="seq_dismiss_action">
                            <UiPrompt StringName="ui_mercenary_dismiss_action" />
                            <Elements>
                                <Response Role="HENRY">
                                    <Text StringName="merc_henry_dismiss_action" />
                                    <Commands><CameraCommand /></Commands>
                                </Response>
                                <Response Role="role_mercenary_test">
                                    <Text StringName="merc_test_dismiss_action" />
                                    <Commands><CameraCommand /></Commands>
                                </Response>
                            </Elements>
                            <Triggers><Port Name="mercenary_dismissed" /></Triggers>
                        </Sequence>
                        <Sequence EndType="Decision" Name="seq_change_equipment_hub">
                            <UiPrompt StringName="ui_mercenary_change_equipment" />
                            <Elements>
                                <Response Role="HENRY">
                                    <Text StringName="merc_henry_equip_hub_prompt" />
                                    <Commands><CameraCommand /></Commands>
                                </Response>
                                <Response Role="role_mercenary_test">
                                    <Text StringName="merc_test_equip_hub_prompt" />
                                    <Commands><CameraCommand /></Commands>
                                </Response>
                            </Elements>
                            <Decision Name="dec_equipment_choices">
                                <Sequences>
                                    <Sequence EndType="EndDialogue" Name="seq_equip_generic">
                                        <UiPrompt StringName="ui_merc_equip_gen" />
                                        <Elements>
                                            <Response Role="HENRY">
                                                <Text StringName="merc_henry_equip_gen" />
                                            </Response>
                                            <Response Role="role_mercenary_test">
                                                <Text StringName="merc_test_equip_gen" />
                                            </Response>
                                        </Elements>
                                        <Triggers><Port Name="equip_generic_mercenaries" /></Triggers>
                                    </Sequence>
                                </Sequences>
                            </Decision>
                        </Sequence>
                    </Sequences>
                </Decision>
            </Dialogue>
        </FaderDialog>
    </Skald>
</Database>
```

It's all fairly straightforward. Here's what everything does:

### Ports — talking to the rest of Skald

`Direction="Out"` ports fire when a sequence ends. They're your way to communicate with regular Skald nodes — for example, the `mercenary_dismissed` trigger above is hooked up to a node that gives the player a token item, which triggers the actual Lua action. See [general/lua-skald-communication.md](general/lua-skald-communication.md) for details on that pattern.

`Direction="In"` ports work the other way — they allow you to conditionally show or hide sequences based on external state. For example, to only show a sequence before a certain condition is met:

```xml
<Port Name="riddles_solved" Direction="In" Type="int">
    <DesignName Text="Riddles solved" />
</Port>

<Sequence EndType="Decision" EntryCondition="Port('riddles_solved') == 0" Name="seq_intro">
```

### Decisions and Sequences

The sequences at the root of a `Decision` are the options the player sees after pressing E. Each `Sequence` is one option.

**`<UiPrompt StringName="..." />`** — The text displayed on that option in the UI. The string is defined in your localization file.

**`EndType`** — What happens when a sequence finishes. `EndDialogue` closes the dialog, `Decision` drops into a nested decision tree for branching conversations.

### Elements — the actual lines

Elements are the individual lines spoken by each participant, dictated by the `Role` property on each `Response`. If the player is supposed to be in the conversation but has no `HENRY` response, that sequence won't appear as an option. The NPC's role must match a role they've been assigned in Storm — see [adding-an-npc.md](adding-an-npc.md) if you need a refresher.

**`<Text StringName="..." />`** — References the concrete subtitle string shown on screen. If that string has a voice line attached to it that matches the voice ID of the NPC's soul, that line will play. The duration a line is displayed for is either the length of the audio clip, or automatically calculated from the character count — which works well enough for English, but reportedly runs too fast for Chinese.

### Commands — animations and expressions

`<Commands><CameraCommand /></Commands>` handles expressions, animations, and camera position. Left as a bare `<CameraCommand />` it will just point the camera at the correct NPC, which is usually all you need. If you want to add some life to your dialogs, you can go further:

```xml
<!-- Facial expressions -->
<FacialMoodCommand FacialMood="arrogant1" />
<FacialMoodCommand Role="MALIR" FacialMood="nervous2" />
<FacialMoodCommand FacialMood="thinking1" />

<!-- Animations with timing -->
<AnimationCommand Delay="0.06" FragmentId="ADLG_Nod"       Guid="2ddda320-2a14-4160-b352-ad7c194f57b3" Variant="0" />
<AnimationCommand Delay="4.27" FragmentId="ADLG_Easy_man"  Guid="c3c363cf-f483-4b85-af81-e9b44c02d8a8" Variant="1" />
<AnimationCommand Delay="0.41" FragmentId="ADLG_Surprised" Guid="37ccf959-1452-4346-bc56-6c477a30e707" Variant="1" />
<AnimationCommand Delay="4.81" FragmentId="ADLG_Gesture"   Guid="5d70018a-2501-4f38-bd2e-e946f1527032" Variant="9" />
<AnimationCommand Delay="0.04" FragmentId="ADLG_Think"     Guid="4dde70bf-c5b4-4341-b109-098b5d8e9343" Variant="0" DesiredDuration="3.05" />

<!-- Camera positioning -->
<CameraCommand CameraType="CloseUp" />
<CameraCommand CameraType="CloseShot" />
```

`Delay` is in seconds from the start of that response. `Variant` selects between different animations within the same fragment. For a full catalogue of what's available, browse the vanilla dialog files — with enough creativity there's a considerable amount you can do to liven things up.

**One important caveat:** I have no idea how to make lips move. KCD2 appears to use a proprietary pipeline for lip sync that we don't have access to. My advice is to avoid direct player-NPC dialogs as much as possible, and lean on short NPC-to-NPC exchanges or open-world monologs for the majority of your communication. The lips just sit there, and it's a little unsettling.

---

## Monolog via Alias

Simpler — no player involvement, just an NPC speaking. This is the format referenced when you call `Function_speech_schedulerMonolog` with an `alias` from a behaviour tree.

```xml
<?xml version="1.0" encoding="utf-8"?>
<Database xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" Name="yourmod">
    <Skald>
        <Dialog Name="drink_3_monolog">
            <Text StringName="merc_test_bark_title" Text="Mercenary Custom Test Bark" />
            <Dialogue Type="ingame monolog" TechnicalStatus="Enabled" Initiator="NonPlayer" ForceMood="noScope" ClashPriority="OpenWorld" GesturesNotNeeded="true">

                <SelectedSouls>
                    <SelectedSoul Role="role_mercenary_test" Voice="jstra" Type="Wave" Language="ENG" />
                </SelectedSouls>

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

            </Dialogue>
        </Dialog>
    </Skald>
</Database>
```

The key differences from a player dialog:

- **`Type="ingame monolog"`** — Tells the engine this is a one-sided ambient line, not a conversation
- **`Initiator="NonPlayer"`** — The NPC starts it, not the player
- **`ClashPriority="OpenWorld"`** — How this line competes with other dialog events firing at the same time
- **`GesturesNotNeeded="true"`** — The NPC doesn't need to perform gestures for this to play
- **`<SelectedSouls>`** — Explicitly defines which role and voice actor to use. `Voice` is the voice actor abbreviation — it must match the abbreviation for the `voice_id` on your NPC's soul, otherwise nothing plays
- **`Alias`** on the `Decision` — This is what you reference in the `alias` parameter of `Function_speech_schedulerMonolog` in your behaviour tree. Get this wrong and the line silently does nothing

Multiple `Response` elements within a single sequence play back-to-back, so you can give an NPC a short monolog of several lines all under one alias call.
