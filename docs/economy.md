# The economy

The goal, stated once: **no purchase made underground may be priced against a permanent upgrade.**

There are two currencies. They cannot be exchanged, and the reason they cannot is physics rather than a
rule the player has to be told twice:

> **The run's money is weightless and dies at the surface. The campaign's money is heavy and has to be
> carried.**

| | What it is | Where it is earned | Where it is spent | Files |
|---|---|---|---|---|
| **Scrip** | A number on the player. Weightless, occupies nothing, and **burned at every exit a descent has** | Ordinary fights, elites, skims, bounties, crossroads finds — the ambient income | The road's Merchant, the Crossroads wagers, and the money kit inside a fight | [models/scrip.lua](../models/scrip.lua) |
| **Gold** | Objects. It arrives as **valuables** — loot with a price, no class, no effect and no use — that occupy mule slots and have to be carried out and sold | Ends only: elites, objectives, generals | The seven shelves, the Forge, the Cafe, the mule ladder. Nothing underground accepts it | [models/valuable.lua](../models/valuable.lua) |

## The problem this replaced

There was one purse. A company walked down the stair with the campaign's gold in it, and every merchant
stop, every crossroads wager and every money ability spent out of the same number the Forge bills
against. So a 200g relic on floor three was not priced against the rest of the floor — it was priced
against a forge rung, and the player either declined every shop underground on principle or bankrupted
the progression they came back up to spend on.

Both of those are correct play, which is the tell: **a decision whose sensible answer is "never engage
with this system" is not a decision.**

## Why scrip evaporates rather than converting

A conversion re-opens the valve the split was built to close. At any rate above zero scrip is gold with a
haircut, and every purchase underground goes back to being priced against a forge rung — just at a
discount. Evaporation is what makes an unspent purse a **loss**, which is what flips the Merchant from a
stop you walk past into a stop you had better use.

Darkest Dungeon's provisions do exactly this and for exactly this reason: what you did not use is
destroyed, so the question is never *can I afford it* but *will I need it*. Its heirlooms are the other
half of the same idea — found only in dungeons, spent only in the hamlet, never purchasable with gold.

**There are three exits and all three burn it**: the stair up ([states/game.lua](../states/game.lua)'s
climb-out), a wipe, and the Hollow Crown. That is what lets the rule be one sentence instead of a table
of exceptions. The stair-up prompt forecasts the burn *before* the choice is made, because there is a
Merchant back there and an unspent purse is the one cost of leaving the player can still do something
about.

There is deliberately **no fence** — no selling a valuable underground for scrip. It is the obvious next
feature and the thing it would solve is already solved: a company with a full mule far from the stair
sends the mule home. If it is ever built it runs one direction and at a rate bad enough to hurt.

## Why gold is objects

Making the campaign's income physical lets it inherit two systems that only ever worked on things, and
lets a special rule be **deleted**:

- **The mule's cap.** Treasure now competes with found gear for the eight slots the mule holds. That is
  the knapsack the cap was built to create and had nothing to fill it with — gear's worth is diffuse
  ("might I use this?"), and a valuable puts a *quoted number* on the slot it takes.
- **The bloodstain.** A wipe drops the pack where the company fell (`Descent.dropPack`), and the pack now
  contains the run's income. The takings are recoverable by walking back down to the tile.

So `Player.loseHaul` **no longer touches gold**. It used to shave 75% off gold-gained; keeping that
alongside the dropped pack would bill one loss twice. The sting is the same size, and now the player can
answer it — and answering it is another descent. Ore still takes the cut, because ore is still a number.

### Bulk is the knob

A valuable declares how many mule slots it takes, and **worth per slot climbs with bulk**
(`tests/economy_spec.lua` pins this). A three-slot idol is worth more per slot than three pocket pieces,
so the deep floors' lumpy finds are the ones worth clearing space for and *"leave the censer, take the
idol"* is the decision. A set where everything weighed one would only ever ask "how many", which is not a
question.

### Valuables are lumpy, not litter

They fall off **ends** — elites, objectives, generals — and never off an ordinary body. One valuable per
fight would be an inventory chore with a floor's worth of clicking in it. The ambient income is scrip's
job, and that split is the whole economy in one line: **the grind funds in-run power, the work you chose
to walk to funds the campaign.**

## The money kit

Money abilities (`Combat.spendPurse`, the greed/rogue shelf) spend **scrip**. `combat.lua` never learns
which purse it was handed — the injection happens in [states/battle.lua](../states/battle.lua) — and an
enemy still spends its own `coffer`, which is real coin, because a body like Aurea is a walking treasury
rather than a shareholder in your purse.

This is the change that made the kit worth having. It used to bill a forge rung to size a blow: a cost
paid three menus and one expedition away from the swing that incurred it, so the honest play was never to
cast it. It now bills the Merchant two rooms down — local, legible, settled inside the run that spent it,
and in direct competition with the shelf you were saving for. That competition is the feature.

## What this obliges

Gold income is now lumpy and end-weighted, so **every gold price in the game is quoted against a curve
that no longer exists.**

- `Mule.RUNGS` (400 / 1100 / 2400) is explicitly anchored on *"an errand's purse, a 250g median"*. That
  anchor is the first casualty.
- The seven shelves, the Forge's gold rungs and the Cafe all need re-reading against **measured** descent
  income rather than authored figures. `. board-report N descent` is the instrument.
- Scrip prices did **not** move: what used to be a fight's gold is its scrip at the same number, and the
  Merchant's shelf is quoted in the same digits it always was. Both sides of that comparison were renamed
  together, so floor three is exactly as affordable as it was. Only the campaign side needs re-measuring.

## The invariant

One claim, and it is about what *cannot* happen: **the two purses never touch.** Scrip cannot become
gold, gold cannot be spent underground, and no seam converts one into the other. The failure mode is
silent — a valuable that slips into `Spoils.shelf` does not crash, it just puts the thing the player is
descending to fetch on a counter for sale — so it is pinned in
[tests/economy_spec.lua](../tests/economy_spec.lua) rather than left to reading.

The exceptions that make it work, each of which is one line somewhere and each of which would be invisible
if it broke:

- `lootCandidates` refuses valuables, or every idol in the data turns up as ordinary loot.
- `Vendor.sells` refuses them, or the Market — which stocks everything priced — sells them back to you.
- `Vendor.sellValue` pays them at **par**, not the 50% gear takes, because nobody ever sold you one: a
  valuable's price is its worth, and halving it here would mean every file authored at double.
- `Mule.load` weighs by bulk, or the cap never binds.
- `Item.instantiate` copies `valuable` and `bulk` onto the instance, or the mule and the counter — which
  are handed live items and nothing else — cannot see them.
