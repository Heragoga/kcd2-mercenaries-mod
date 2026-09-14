# The camp trader

A camp improvement: a market stall on one of the camp's grid tiles, a sutler standing behind
it, and a counter the player buys from and sells to. Bought on the camp screen (`U`) like
every other improvement — `UpgTraderCost`, 2,500 groschen.

The point of him is the sell side. Before this, the mod had no way to turn loot into coin
anywhere near a camp, and the war chest exists as a stand-in for exactly that — its comment
says so: *"stands in for 'sell loot' (the engine gives no way to enumerate arbitrary
inventory loot to sell)"*. It does now; see [Prices](#prices).

| | |
|---|---|
| Module | `data/Scripts/mods/mercenaries_trader.lua` |
| Prices | `data/Scripts/mods/mercenaries_price_data.lua` (generated, `tools/gen_price_table.py`) |
| Stock | `inventory_merc_trader_stock` in `data/libs/tables/item/InventoryPreset__mercenaries.xml` |
| Soul | `soul_merc_trader`, on the **quartermaster's brain** |
| Shop row | `data/libs/tables/shop/shop__mercenaries.xml` (the engine-shop attempt only — see below) |
| Dialogue | `trader_dialog.xml` on `role_mercenary_trader`, one Out port → token `…bef6d` → `TraderOpen` |
| Console | `merc_trader_build` / `_remove` / `_open` / `_restock` / `_stock` / `_probe` |

---

## What the player does

Walk up to the sutler and press **E**. He has his own two-line dialogue — *"Show me your
wares."* / *"Not now."* — and the first one makes him say how the deal works before the window
opens:

> Help yourself to what's on the counter, and lay out whatever you're selling. I'll do the
> reckoning when you're done, and we'll square up then.

That line is load-bearing. The mod cannot open the game's own trade screen (below), so the
counter settles from what moved once the window closes, and without him saying so the player
has no idea when they are being charged.

Then the item-transfer window opens onto his counter. Take what you want off it, put what you
want to sell onto it, close it, and three quiet seconds later the deal settles: the difference
is paid in real groschen, and an on-screen line says what changed hands and what he has left
in his purse.

He sells potions and bandages, food and drink, arrows and bolts, basic weapons, armour,
helmets and repair kits. He buys anything. He carries **25,000 groschen** and restocks — new
goods, full purse — every three days.

## Why it is not the game's shop screen

**Asked and answered in game.** `merc_trader_probe` at a standing stall:

```
keeper: GetShopDBIdByKeeper=-1  IsLinkedWithShop=<null wuid>  GetShopMoney=0
```

The engine will not accept a runtime-spawned shopkeeper, and the disassembly says why.

`Shops` is a real script bind with eleven functions (`GetShopMoney`, `IsLinkedWithShop`,
`FindItemInShop`, `AcceptTransaction`, …) and **not one of them opens the trade UI**. The only
thing that does is a Skald sequence with `Type="OpenShop"`, which the game uses in
`nakupovani_z_dialogu_muz.xml` and in every roadside-camp merchant's dialogue — and it
resolves the shop from the dialogue partner, through the same lookup that just answered -1.

That lookup (`sub_152EDC8`) walks the engine's own list of live shop records and asks each one
"is this entity my keeper". A record binds its keeper from the **XGenAI linkable-object
graph**, which is built at level load — `wh::shopmodule::C_Shop` has RTTI type converters to
and from `wh::xgenaimodule::C_LinkableObject`, so a shop *is* a node in that graph.
`Entity.CreateLink` writes a **CryEntity** link, which is not the same graph, and
`XGenAIModule` exposes `FindLinks` (read) and nothing that writes. So the `shopKeeper` link
this module creates is real and simply invisible to the shop module.

`Shops.OpenInventoryForItem` is not a way round it either: it resolves a shop from the item's
owner through the same function and returns silently when there is none.

The `Shop` entity, the shop row in `shop__mercenaries.xml` and the `shopKeeper` link are all
still created, and the probe now also reports `GetShopDBIdByLinkedEntityId` for the Shop
entity and `XGenAIModule.FindLinks` for the sutler — so a future attempt can tell whether the
shop row and entity registered and only the keeper binding is missing, or whether nothing
registered at all. Nothing in the shipped feature depends on any of it.

## Prices

Two routes, tried in that order:

1. **The engine's own figure.** `ItemManager.GetItem` hands back an item object whose
   metatable (`wh::entitymodule::Item`, registered at `sub_CE0CD8`) declares `Name`,
   `ItemClass`, `Category`, `Type`, `Subtype`, `Amount`, `Condition`, `MaxQuality`,
   `NewUnitPrice`, `CurrentUnitPrice`, `NewStackPrice` and `CurrentStackPrice`.
   `TraderBasePrice` reads `CurrentUnitPrice` as a field and then as a method, so whichever
   form it takes, it is used and quality is accounted for.
2. **The baked table.** `tools/gen_price_table.py` reads the `Price` attribute off every row
   of the game's own `item*.xml` — 5,358 classes — and packs it into fixed-width records
   (32 hex digits of dashless GUID + 6 digits of price). `mercenaries_price_data.lua` is
   200 KB of string constant; it is unpacked into a hash **once, on the first trade**, and
   never if route 1 answers.

`merc_trader_probe` prints which route is live (`price route: engine` or `price route:
table`).

Margins are `TraderBuyMargin` (1.15) and `TraderSellMargin` (0.35), both scaled by the
item's condition. He is a camp follower: dear to buy from, thin to sell to, and the only
buyer for miles.

## How the deal is read

**Nothing tells Lua that the transfer window has closed.** That is the same wall
`mercenaries_delivery.lua` hit, and the answer is the same: snapshot the counter before
opening it, then poll it once a second and treat three ticks with an unchanged signature as
"they are done". Whatever left the counter the player bought (priced from the snapshot,
because it is no longer there to read); whatever arrived they sold (priced from the counter,
where it now is).

Settlement is net:

* He owes more than he is owed → he pays, capped at what is in his purse, and says so if he
  ran out.
* The player owes more → their purse is charged. If it cannot cover it, they pay what they
  have and `TraderClawBack` takes the **dearest** goods back until the debt is covered. What
  comes back is recreated rather than moved, so it loses its condition. That is the price of
  walking off with more than you can pay for.

## The stall

Researched out of the base game rather than assembled by eye. A Kuttenberg market stall is
**one authored mesh**: `Prefabs/profession/seller/shop_outside.xml`, the prefab behind every
outdoor shop in the city, is a single `shop_rustic_b.cgf` brush plus the shop's logic ports,
and `Prefabs/exteriorDecoration/shop_fisherman.xml` is that same mesh with herring, barrels
and knives laid on it. The family lives in
`objects/manmade/structures/municipal/trading/` — `shop_rustic_a`/`_b`, `shop_by_house_a`/`_b`,
`shop_fancy_a`, `shop_big_a`, each with a matching `_counter` piece for shops built into a
house front.

The camp uses **`shop_rustic_b`**, the roadside one: 3.32 m wide, 1.07 deep, 2.70 tall, origin
on the customer edge with the body running +Y and the counter top at 0.97. `rz = -90` turns
that edge to face the camp, so the player walks up to the counter and the sutler stands
behind it at `fwd 1.55`, in the open, the way the game's own market sellers do.

The dressing copies the fisherman's heights — goods on the counter at 0.97, things hung off
the frame around 2.0, barrels and crates on the ground either side:

| Where | What |
|---|---|
| On the counter | a bread basket, a saviour-schnapps flask, his scales, a quiver — left to right as you walk up |
| Hung off the frame | a bunch of drying herbs |

Six pieces including the stall itself, every offset measured out of the object paks. It was
twenty-two at first and that read as a junk pile rather than a stall — the vanilla ones are
sparse, and the fisherman's is only busy because the fish *are* the stock. Like the rest of
the camp dressing they spawn without collision (`merc_collision all` puts it back).

`lat` in the layout table is the **customer's left** as they walk up (the frame's forward axis
points out of the camp, so `Lft` is forward rotated +90°, which is the player's left hand).

## The sutler

He is `soul_merc_trader` on **`quartermaster_brain`** — the same lobotomised merc the
quartermaster runs (stand at a post, eat now and then, defend yourself, never wander; see
[quartermaster.md](quartermaster.md)). Nothing new was needed for him.

The one change that made sharing possible: `GetQuartermasterPost` now takes an **entity**,
and `quartermaster_idle.xml` passes one in. It answers the trader's post for the trader and
the quartermaster's for everybody else, so the two men do not walk to the same spot.
`FindQuartermasterTarget` was already per-entity (`data` + wuid), so combat needed nothing.

He has his own `skald_character` (`char_mercenary_trader`) and his own dialogue role
(`role_mercenary_trader`, assigned from `soul_merc_trader` in the Storm rules), kept separate
from the quartermaster's so pressing E on him opens the stall and not the company's books.

`TraderInjectInteraction` — a hold-E "Trade" prompt of the kind
`mercenaries_lookatinteraction.lua` puts on a merc — is still in the module but **off**
(`TraderUsePrompt = false`): two doors into one room. It is kept because it is the only route
that does not depend on the Skald chain, so if the dialogue ever fails to cast him it is a
one-line fix rather than a rewrite. `merc_trader_open` does the same from the console.

## Lifetime

| | |
|---|---|
| Stall props | `MercCampTraderProp_*`, no-save, under the camp's `MercCamp` prop sweep |
| Sutler | `MercTrader_*`, no-save, respawned with the camp, swept by name |
| Counter | `MercTraderStock_*`, a `Stash`, **saved with the game** |

The counter is the exception on purpose. It holds the stock and everything the player has
already sold him, so breaking camp, moving camp and reloading all leave it alone — a stall
that re-rolled its goods every time the camp went back up would make the restock timer
meaningless. `SpawnCampTrader` adopts a leftover counter rather than spawning a second one.

### A runtime Stash loses its generated stock across a save

The entity comes back and so do real item instances — what the player sold him — but the
inventory rolled from `Database.sGeneratedInventory` **does not**. The symptom is a stall that
re-opens holding nothing but the last thing sold to it, and the log gives no clue: the adopt
path simply doesn't print `counter stocked from …`.

Nothing reports the loss, so it is read off the class count. `traderStockN` records how many
item classes were on the counter when it was last written (after a roll, after a restock,
after every settled deal) and is saved with the rest of the logistics state. On adopt, a
counter holding materially fewer classes than that was emptied by the save, not by a customer,
and is re-rolled — with anything real on it carried across to the new one first.

Comparing against the recorded number rather than just asking "is it empty" is what stops a
player who legitimately bought the stall out from getting it refilled by reloading: the settle
wrote the low number down, so the low count is expected. A save written before the number
existed falls back to `TraderStockFloor` (6 classes).

Selling the improvement back (the camp screen's Remove, or the quartermaster's remove menu,
index 12) calls `TraderDropStock`, which does take the counter away: a stall bought again is
a new man with new goods.

## What is not done

* **The quartermaster can take the stall down but not put it up.** His remove-one-improvement
  menu lists the trader (index 12, and `tools/check_dialogs.py` enforces that the menu and
  `UpgRemovable` agree, so it had to). His *buy* menu does not: that would be another
  token GUID and another six-file chain for a second route to a button the camp screen
  already has.
* **No haggling, no reputation, no stolen-goods flag.** Those live in the engine's shop, and
  this is not it.
* **No engine trade screen**, and there cannot be one for a spawned merchant — see
  [above](#why-it-is-not-the-games-shop-screen). A trade screen in the mod's own UI
  framework is possible but is its own project: the Scaleform pipeline bakes every
  label as an image, so arbitrary item names would need dynamic text first.
