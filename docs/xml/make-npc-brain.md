# Making an NPC Brain

This is the second part of creating a new NPC. If you have followed [add-new-npc.md](add-new-npc.md) correctly, this is your next step — if you want them to have a brain. If you want a brainless punching bag, go ahead and skip this, although the default brain in add-new-npc.md is capable of defending the NPC.

This guide ties a behaviour tree to an NPC soul. It isn't the most complex part of creating an NPC, but it is honestly the most annoying. The correct way to do this took me a considerable amount of time to figure out, as the base game system is more complicated than necessary. All of this happens in `data\libs\tables\ai`. The only touching point between the brain and the soul is the soul definition itself — the `brain_id` attribute — which has to match the ID of your new brain. Let's dive in.

---

## The Brain

Our brains may be wet and squishy, but KCD2 NPC brains feel more like a 19th century postal station, with mailboxes and substations.

`data\libs\tables\ai\brain__yourmodid.xml` only defines a brain ID and name and ties them together:

```xml
<brain brain_id="e2a51ce4-449f-4a2e-83b9-c098c5b118cd" brain_name="mercenary_brain" />
```

Generate a fresh GUID for `brain_id` and reference it consistently in every other file in this guide.

---

## brain2subbrain

This is where the interesting stuff starts to happen. An NPC brain consists of multiple subbrains that each serve different purposes. This file connects a brain to those subbrains.

A basic NPC needs two subbrains: a **switch** (type 6) and a **scheduler** (type 9).

For the scheduler you can use a vanilla one — you don't need to write your own:

```xml
<brain2subbrain brain_id="e2a51ce4-449f-4a2e-83b9-c098c5b118cd" priority="0" subbrain_id="4eaa0620-d090-e268-c244-cba09ad5ec80" />
```

The `subbrain_id` here references a base game scheduler. The scheduler governs where your NPC sleeps, eats, and what they do throughout the day. For basic NPCs you don't need to touch this — most behaviour can be handled in the switch.

Add a second entry for your custom switch subbrain, using a new GUID you generate:

```xml
<brain2subbrain brain_id="e2a51ce4-449f-4a2e-83b9-c098c5b118cd" priority="0" subbrain_id="26e83d2a-964c-4fd3-b077-6de567b0d081" />
```

---

## Mailboxes

Honestly, this is not something I touched much. Mailboxes govern how subbrains communicate with each other and the world. Warhorse probably built a beautiful system that works flawlessly if you have the documentation. We do not. I have spent enough time getting it to just work to not bother exploring it further. The approach described here lets you execute a behaviour tree normally.

### brain2mailbox

Ties a brain to mailboxes. Basic NPC brain mailboxes can be found in the mercenaries mod. Tie your brain to them just in case:

```xml
<brain2mailbox brain_id="e2a51ce4-449f-4a2e-83b9-c098c5b118cd" mailbox_id="..." priority="0" />
```

### mailbox_group

Ties your behaviour tree definition to a mailbox group. `mailbox_group_file_name` is the filename of your behaviour tree XML, and `tree_name` is the name of the root `BehaviorTree` node inside it:

```xml
<mailbox_group mailbox_group_file_name="mercenary_scheduler.xml" mailbox_group_id="61426837-4d6f-4669-9f4a-16553ab66857" mailbox_group_tree_name="onUpdate" />
```

### mailbox_group2mailbox

Connects your mailbox group to a mailbox ID. One mailbox group can connect to multiple mailbox IDs:

```xml
<mailbox_group2mailbox mailbox_group_id="61426837-4d6f-4669-9f4a-16553ab66857" mailbox_id="0be79f74-4e05-48c1-906d-0b4c7a2d8c76" priority="0" />
```

---

## brain_variable

Stores a persistent variable in the brain. I handle variables through Lua instead, but if you need a brain-level persistent variable — for example to survive save/reload — you can declare it here:

```xml
<brain_variable ai_variable_form_id="0" ai_variable_sync_id="0" brain_id="e2a51ce4-449f-4a2e-83b9-c098c5b118cd" brain_variable_name="cooldown" is_persistent="true" type="float" />
```

---

## subbrain

Now the interesting stuff. The subbrain is what actually connects your brain to a behaviour tree XML. The available subbrain types are:

| Type ID | Name |
|---------|------|
| 1 | BehaviorTree |
| 3 | SmartArea |
| 4 | SmartObject |
| 5 | Situation |
| 6 | Switching |
| 7 | Dialog |
| 8 | DogCompanion |
| 9 | Scheduler |

The type of Subbrain you select governs the type of commands you can run inside the brain. For example: a switch cannot run movement or combat nodes, tehy have to be inside a scheduler or a smart object. That's why it's necessary to call interrupts from a switch, to execute a behaviour tree of a different type.
Other things are: I believe wait nodes cannot be called in some types (Behaviour tree for example). If you don't want to touch these incompatabilities I recommend replicating my approach. I spent enough time finding a combination that worked.

The most relevant ones are **6 (Switching)** — which is what we're using — **9 (Scheduler)** for daily routines, and **3 (SmartObject)** for things like doors and a bunch of other things.

The subbrain definition ties your subbrain ID (which `brain2subbrain` references) to a name and type:

```xml
<subbrain always_active="true" subbrain_id="26e83d2a-964c-4fd3-b077-6de567b0d081" subbrain_name="mercenary_scheduler" subbrain_type="6" timeout="0" />
```

`always_active="true"` means this subbrain runs continuously. `timeout="0"` means it won't time out.

---

## subbrain_switching

Finally, the part that ties your subbrain to the actual XML in `yourmodid/data/ai` where the behaviour trees live:

```xml
<subbrain_switching file_name="mercenary_scheduler.xml" subbrain_id="26e83d2a-964c-4fd3-b077-6de567b0d081" tree_name="onUpdate" />
```

- `file_name` — the filename of your behaviour tree XML inside `data/ai/`
- `subbrain_id` — must match what you used in `brain2subbrain` and `subbrain`
- `tree_name` — the `name` attribute on the root `<BehaviorTree>` node in that file

---

## SmartEntity (Interrupts)

`data/libs/tables/ai/SmartEntity/SmartEntity__so_interrupt__yourmodid.xml`

This is how KCD2 handles interrupts — situations where the NPC needs to break out of their current behaviour and do something else, like fight back when attacked. A SmartEntity is essentially a registry of named behaviour templates that other behaviour trees can trigger by name.

When a behaviour tree fires an interrupt (e.g. `AddInterrupt_attack` with `Behavior="'mercenary_attack'"`), the engine looks up `mercenary_attack` in the SmartEntity registry, finds the corresponding tree file, and executes it. While that interrupt tree is running, the original switch is temporarily suspended.

```xml
<?xml version="1.0" encoding="us-ascii"?>
<database name="barbora" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:noNamespaceSchemaLocation="../../database.xsd">
    <SmartEntitys version="1">
        <SmartEntityTemplate BrainId="e2a51ce4-449f-4a2e-83b9-c098c5b118cd" DatabaseId="43c857b4-032b-844f-3d1b-3cc90d5a2382" Name="so_interrupt" UpdatePriority="false">
            <BehaviorTemplates>

                <SmartBehaviorTemplate InitialState="Enabled" MaxInstances="-1" Name="mercenary_attack" PreventsMonsterLod="true">
                    <TreeLocation FileName="mercenary_attack.xml" TreeName="mercenary_attack" />
                    <Inboxes>
                        <InboxTemplate InboxId="80cbc23c-5752-43e3-9405-38355ad8d617" Priority="0" />
                        <InboxTemplate InboxId="5201b5fc-b24b-49ab-b409-23c13ae08e4e" Priority="0" />
                        <InboxTemplate InboxId="5450a641-8c06-4839-a5d8-dd750a977c19" Priority="0" />
                        <InboxTemplate InboxId="b4c700f0-eb28-4605-a0dd-a7188900f83a" Priority="0" />
                        <InboxTemplate InboxId="c1221861-49ff-4dbc-bc94-de1bd2601a1a" Priority="0" />
                        <InboxTemplate InboxId="42b04ead-5936-2286-c9c3-85769ff854b2" Priority="0" />
                    </Inboxes>
                </SmartBehaviorTemplate>

            </BehaviorTemplates>
        </SmartEntityTemplate>
    </SmartEntitys>
</database>
```

Key attributes:

- `BrainId` — must match your brain's `brain_id`
- `DatabaseId` — a unique GUID for this SmartEntity entry; generate a fresh one
- `Name` on `SmartBehaviorTemplate` — the string your behaviour tree references when firing the interrupt
- `FileName` / `TreeName` in `TreeLocation` — the behaviour tree file and root node to execute
- The `InboxId` values are vanilla mailbox IDs used by the combat system; copy them from the example above

How to actually fire an interrupt from within a behaviour tree is covered in the behaviour tree guide.

---

## Summary: Files to Create

| File | Purpose |
|------|---------|
| `brain__yourmodid.xml` | Defines the brain ID and name |
| `brain2subbrain__yourmodid.xml` | Connects the brain to its subbrains (scheduler + switch) |
| `brain2mailbox__yourmodid.xml` | Connects the brain to mailboxes |
| `mailbox_group__yourmodid.xml` | Ties the behaviour tree to a mailbox group |
| `mailbox_group2mailbox__yourmodid.xml` | Connects the mailbox group to a mailbox |
| `subbrain__yourmodid.xml` | Defines the subbrain type and ID |
| `subbrain_switching__yourmodid.xml` | Points the subbrain at the actual behaviour tree XML |
| `SmartEntity__so_interrupt__yourmodid.xml` | Registers interrupt behaviour templates (e.g. combat) |

My knowledge of this part is limited, as I'll freely admit. I got one brain to work, was happy with it, and didn't bother poking at these systems further. Behaviour trees in KCD2 are incredibly powerful and allow for such a large amount of shenanigans that you honestly don't need to deeply understand mailboxes or every subbrain type to build something that works.
