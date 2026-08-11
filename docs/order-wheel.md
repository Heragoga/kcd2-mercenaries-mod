# The silent order wheel (chat menus)

Hold the chat key while looking at a mercenary and a small list of orders appears — no dialog camera, no spoken line, you keep walking. This is the same mechanism the game uses for Mutt's command menu, and it is not a bespoke UI: it is a **Skald dialogue of `Type="chat"` with `Initiator="Player"`**.

Ours lives in [`order_wheel_chat.xml`](../data/quests/mercenaries/kutnohorsko/mercenaries_background_quest/order_wheel_chat.xml) (mirrored under `trosecko/`).

---

## What makes a menu a wheel

```xml
<Dialogue Type="chat" TechnicalStatus="Enabled" Hearing="10" DefaultMaxDistance="10" DefaultChatTimeLimit="0"
          Initiator="Player" ForceMood="noScope" ClashPriority="OpenWorld" GesturesNotNeeded="true">
```

| Attribute | Why |
|---|---|
| `Type="chat"` | Chat instead of a full dialogue — compact option list, player keeps control |
| `Initiator="Player"` | Player opens it. `NonPlayer` is the NPC-hails-you flavour and works completely differently |
| `ForceMood="noScope"` | No dialog camera, no zoom |
| `GesturesNotNeeded="true"` | No talking animations |
| `DefaultChatTimeLimit="0"` / `TimeLimit="0"` | The menu waits instead of timing out |
| `DefaultMaxDistance` | How far away the option stays available |

Silence comes from responses that carry **no `<Text>` child**:

```xml
<Elements><Response Role="role_mercenary_test" /></Elements>
```

The dog's own menu does have short Henry lines; ours has none.

---

## Structure

Options are `Sequence`s with a `<UiPrompt>` and a `ChatPosition`. **Four positions plus a refusal per level** — `First`, `Second`, `Third`, `Fourth`, `Refusal` (also `RefusalTimeout`, `RefusalDistance`). Anything wider needs a submenu: give the sequence `EndType="Decision"` and nest another `<Decision>` inside it. `Refusal` always **closes the whole wheel** here (matches vanilla Mutt) — it does not step back one level, so don't treat it as "back".

Our layout (top level fits exactly in the four slots):

```
Squad orders   (First)   -> Follow me    (First)
                             Wait here    (Second)
Camp           (Second)  -> Make camp    (First)
                             Break camp   (Second)
Report         (Third)
Equipment      (Fourth)  -> Change equipment (First) -> 6 outfits, paginated 3+3
                             Change gear      (Second) -> 9 loadouts, paginated 3+3+3
                             Archer weapon    (Third)  -> 3 options, fits directly
```

Equipment and weapon loadouts have more than four choices, so each list is split across pages behind a "More options..." leaf rather than crammed onto one screen — the same trick vanilla uses anywhere a chat menu needs to expose more than four things.

Every option below the top level reuses **dismissal_dialog's own labels** (`ui_merc_equip_*`, `ui_merc_weapon_*`, `ui_archer_weapon_*`, `ui_mercenary_wait_action`, `ui_mercenary_camp_make`, …) — only the wheel's own hub labels (`ui_merc_wheel_root`, `ui_merc_wheel_report`, `ui_merc_wheel_equipment`, `ui_merc_wheel_more`) are new strings. This keeps wording consistent between the wheel and the E-dialog and means no extra translation work.

The root `Decision` is `Autoselect="true"` with a single silent sequence whose `Elements` list **both HENRY and the merc role**. That opening beat is what makes the merc a participant in the dialogue — without a merc-role response the chat has no NPC to attach to. The real menu is the `Decision` nested inside it. This mirrors vanilla's `open_world/dog/chat/ovladani_chatem.xml`.

Selecting a leaf fires its `<Triggers><Port .../></Triggers>`.

There is no general combat-stance option in the wheel (attack-anyone / only-my-target / defend / passive) — those tokens (`679a655e-…-be51d` through `-be54d`) were never wired to any Lua handler in `MonitorInventory`, so the feature was dead on arrival. It has since been stripped from `dismissal_dialog.xml` (the E-dialog) too: the ports, the `dec_stance_choices` submenu, its `execute_stance_*` EventFunctions, and the four now-unused item-class rows in `item__mercenaries.xml` are all gone. Archer stance (skirmish/melee/hold) is unrelated and unaffected — it's a real, Lua-backed feature, and its hub (`seq_archer_orders_hub`) was promoted to a direct top-level entry in the E-dialog now that the "Combat" wrapper it used to sit under has no other children.

---

## Wiring

Same route as every other menu in this mod (see [lua-skald-communication](general/lua-skald-communication.md)): Out port → `CreatePlayerReward` in the quest → token item in the player's inventory → `mercenaries:MonitorInventory` deletes it and calls the handler.

The wheel deliberately fires the **same token GUIDs the E-dialog already uses**, so it needed no new item classes and no new Lua — only extra `<Edge>` entries on the existing `execute_*` nodes:

```xml
<EventFunction Name="execute_follow" ... >
    <Constant Name="ItemClass" Value="679a655e-189d-4519-b437-ccc4b92be46d" />
    <Edge From="dismissal_dialog.mercenary_follow" To="Exec" />
    <Edge From="order_wheel_chat.order_follow" To="Exec" />
</EventFunction>
```

An `EventFunction` accepts any number of `Exec` edges; vanilla does the same thing in the dog's `chat.xml`.

---

## Requirements on the NPC

* The entity class needs `IsChatUsable = 1`. Mercs spawn as `class = "NPC"`, and vanilla `NPC.lua` already sets it.
* No behaviour-tree node is needed. E-dialog requires `Function_switch_handleDialog` on `dialogMailbox` (see [talking](behaviour-trees/talking.md)); player-initiated chat goes straight through `actor:DoChat` from the interactor, and the dog's BT has no dialog handler at all.
* The mailbox for `dialog:chatRequest` (`eb69e9da-…`) is mapped for the merc, archer and quartermaster brains anyway.
* Vanilla's `switch_handleChat` errors on anything that isn't the `NPC_ZDRAVI_HRACE` greeting — that is the **NPC-initiated** path and does not apply here.

---

## Gotchas

* The chat key is shared with follow-with-focus. In `BasicAIActions:GetChatActions`, if `user.actor:CanFollow(npc)` is true the follow hint takes the slot and the chat hint never appears.
* A `Refusal` sequence with no `UiPrompt` ends the whole chat — it does not step back one level. Use `EndType="GoTo"` with a `GoToDecision` if you want a real "back".
* Keep the quest copies in sync: `kutnohorsko/` and `trosecko/` are hand-mirrored.

---

## Vanilla reference

* `Quests/Final/Barbora/open_world/dog/chat/ovladani_chatem.xml` — Mutt's menu
* `Quests/Final/Barbora/open_world/dog/chat.xml` — its port consumers
* `Quests/Testing/tv/light/chat_broken/playerchat.xml` — the minimum viable player chat
* `Scripts/Entities/AI/Shared/BasicAIActions.lua` — `GetChatActions`, `CanChat`, `DoChat`
