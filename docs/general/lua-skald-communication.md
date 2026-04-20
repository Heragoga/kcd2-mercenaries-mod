# Skald ↔ Lua Communication via Inventory Tokens
 
## The Problem
 
If you're writing a quest of any real complexity in KCD2, you will eventually hit this wall: you need Skald (the dialog/quest scripting system) to trigger something in Lua. Maybe you want hiring a mercenary to be tied to a quest node, or you want a dialog choice to set a flag your Lua mod reads. Whatever the reason, you need these two systems to talk to each other.
 
The short answer is: **there is no direct way to do it.**
 
If you've already poked around in Skald and found the node that looks like it lets you run console commands — the one that seems like it's exactly what you need — stop right there. That node does not work in the vanilla game. It is vestigial, broken, or locked behind something we don't have access to. Don't waste your time on it.
 
The only reliable bridge between Skald and Lua is the player's inventory.
 
This is, admittedly, a cursed solution. You are encoding inter-system communication as items in an RPG character's bag. If the player opens their inventory at exactly the wrong millisecond, they will briefly see a bag of nails appear and vanish. It's a small price to pay for something that should have been a first-class feature, but here we are.
 
---
 
## How It Works
 
The pattern is simple:
 
1. Skald gives the player a specific item when something happens in the quest tree
2. Your Lua code polls the player's inventory on a timer
3. When it finds the item, it deletes it and executes whatever action the item encodes
4. The item is never meant to be seen or used — it's a message, not loot
You can encode additional information in the **amount** of the item. One item type can represent up to 2,147,483,647 distinct states purely through quantity, so you can squeeze a lot of data through a single token if you're creative about it.
 
---
 
## Step 1: Define the Token Item
 
Create or add to `yourmod/data/libs/tables/item/item__yourmodid.xml`:
 
```xml
<?xml version="1.0" encoding="us-ascii"?>
<database xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
          name="yourmodid"
          xsi:noNamespaceSchemaLocation="item.xsd">
    <ItemClasses version="8">
        <!-- Communication tokens — these are never meant to be seen by the player -->
        <MiscItem
            Type="5"
            SubType="0"
            IconId="loot_sackOfNails"
            UIInfo="ui_in_common_sackOfNails"
            UIName="ui_nm_common_sackOfNails"
            Model="manmade/task_specific_props/construction/nails_bag_a.cgf"
            Weight="1.2"
            Price="120"
            FadeCoef="1.111111"
            VisibilityCoef="1"
            Id="YOUR-UUID-HERE"
            Name="loot_sackOfNails"
        />
    </ItemClasses>
</database>
```
 
The item itself is a bag of nails. The appearance doesn't matter at all — the player is never supposed to have it for more than a single inventory scan cycle. The only thing that matters is the `Id`.
 
**Generate a fresh UUID for every token you define.** Use [uuidgenerator.net/version4](https://www.uuidgenerator.net/version4) and write them down somewhere. Each distinct action or state you want to communicate needs its own UUID so your Lua code can tell them apart. Don't reuse UUIDs across items or mods.
 
A few practical notes on the item definition fields:
- `Type="5"` and `SubType="0"` make this a misc item — it won't trigger any special inventory UI behavior
- `Weight` and `Price` are arbitrary since the item will be deleted immediately; just give it something non-zero
- `VisibilityCoef="1"` means it is technically visible if the inventory opens at the wrong time — you can't fully prevent this, but the polling interval is short enough that it's rarely an issue in practice
---
 
## Step 2: Trigger the Token from Skald
 
In your Skald dialog tree, add an `EventFunction` node wherever you want to fire the signal:
 
```xml
<EventFunction
    Name="lua_communicator"
    PositionY="1500"
    PositionX="900"
    MethodName="wh::entitymodule::CreatePlayerReward"
    DeclaringType="wh::entitymodule">
    <Constant Name="ItemClass" Value="YOUR-UUID-HERE" />
    <Constant Name="Amount" Value="1" />
    <Constant Name="ShowUINotification" Value="false" />
    <Edge From="yourtrigger.trigger" To="Exec" />
</EventFunction>
```
 
The `Edge` attribute is how you wire this node into your tree. `From` is the output pin of whatever node should trigger this, and `To="Exec"` is the execution input of this node. You can have multiple edges feeding into a single communicator if several branches should trigger the same Lua action.
 
**`ShowUINotification="false"` is important.** Without it the game will flash a reward notification on screen when the item is added, which immediately breaks the illusion that nothing is happening.
 
**Encoding state in the amount:** If you need to pass different values — for example, which tier of mercenary to hire, or which dialog branch was chosen — use different `Amount` values on otherwise identical nodes rather than defining a new item UUID for every possible state. Your Lua code reads the count and branches on it:
 
```xml
<!-- Hire tier 1 -->
<Constant Name="Amount" Value="1" />
 
<!-- Hire tier 2 -->
<Constant Name="Amount" Value="2" />
 
<!-- Hire tier 3 -->
<Constant Name="Amount" Value="3" />
```
 
---
 
## Step 3: Poll for Tokens in Lua
 
In your main Lua file, set up the token IDs and a polling loop:
 
```lua
yourmodid = {}
 
-- Store token UUIDs as constants so they're easy to change and reference
yourmodid.TokenIDSomeAction   = "YOUR-UUID-HERE"
yourmodid.TokenIDAnotherAction = "ANOTHER-UUID-HERE"
 
-- OnGameplayStarted fires after every load, including saves.
-- This is where you kick off the polling loop.
function yourmodid:OnGameplayStarted(actionName, eventName, argTable)
    Script.SetTimerForFunction(1000, "yourmodid.MonitorLoop")
end
 
-- The core polling loop. Reschedules itself every 1000ms indefinitely.
-- If player or inventory is unavailable (cutscene, loading screen) it
-- safely skips the scan and still reschedules.
function yourmodid.MonitorLoop()
    if player and player.inventory then
        local p = player.inventory
 
        -- Check for the first token type
        local countSomeAction = p:GetCountOfClass(yourmodid.TokenIDSomeAction)
        if countSomeAction and countSomeAction > 0 then
            -- Delete the token immediately before doing anything else.
            -- This prevents the action from firing twice if something
            -- slow happens during execution.
            p:DeleteItemOfClass(yourmodid.TokenIDSomeAction, countSomeAction)
 
            -- countSomeAction holds the encoded value from Skald.
            -- You can branch on it to handle multiple states from one token.
            yourmodid:HandleSomeAction(countSomeAction)
        end
 
        -- Check for the second token type
        local countAnotherAction = p:GetCountOfClass(yourmodid.TokenIDAnotherAction)
        if countAnotherAction and countAnotherAction > 0 then
            p:DeleteItemOfClass(yourmodid.TokenIDAnotherAction, countAnotherAction)
            yourmodid:HandleAnotherAction(countAnotherAction)
        end
    end
 
    -- Always reschedule, regardless of whether anything was found.
    Script.SetTimerForFunction(1000, "yourmodid.MonitorLoop")
end
 
function yourmodid:HandleSomeAction(encodedValue)
    -- encodedValue is the Amount from the Skald node.
    -- Use it to branch on different states if needed.
    if encodedValue == 1 then
        -- handle state 1
    elseif encodedValue == 2 then
        -- handle state 2
    end
end
 
-- Register the event listener. This is what actually calls OnGameplayStarted.
UIAction.RegisterEventSystemListener(yourmodid, "", "OnGameplayStarted", "OnGameplayStarted")
```
 
### Key points about the Lua side
 
**Always delete the token before executing the action**, not after. If your handler errors out partway through, you don't want the token sitting in the inventory and firing again on the next poll cycle.
 
**The timer is in real milliseconds, not game time.** 1000ms means one real-world second. The polling interval is a tradeoff between responsiveness and overhead — 500ms feels more immediate, 2000ms is cheaper. For most quest triggers 1000ms is fine since dialog interactions are human-speed.
 
**`OnGameplayStarted` fires on every load, not just the initial game launch.** This means `SetTimerForFunction` will be called every time the player loads a save. If you're not careful you'll stack multiple parallel polling loops that each reschedule themselves forever. Guard against this:
 
```lua
yourmodid._loopStarted = false
 
function yourmodid:OnGameplayStarted(actionName, eventName, argTable)
    if not yourmodid._loopStarted then
        yourmodid._loopStarted = true
        Script.SetTimerForFunction(1000, "yourmodid.MonitorLoop")
    end
end
```
 
**`GetCountOfClass` returns nil if the item class doesn't exist in the game's item registry at all**, not just 0 if the player doesn't have it. Always check for nil before comparing to 0, as shown in the example.
 
---
 
## Putting It Together: A Minimal Example
 
Here's the full flow for a single action — a dialog choice that triggers a custom Lua function:
 
**`item__yourmodid.xml`** — defines the token item with a unique UUID
 
**Skald node** — `EventFunction` with `wh::entitymodule::CreatePlayerReward`, wired to your dialog node's output, `ShowUINotification="false"`
 
**`yourmod.lua`** — stores the UUID as a constant, runs a 1s polling loop, deletes the token and calls your handler the moment it's detected
 
That's the entire pattern. It's not elegant, but it's robust, it's compatible with everything else in the game, and it doesn't require any engine hooks or unsupported APIs. Once you've wired it up once, adding new communication channels is just a matter of defining another item UUID and adding another `if` block to your loop.
 
