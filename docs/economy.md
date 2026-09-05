# The economy

The goal, stated once: **no purchase made underground may be priced against a permanent upgrade.**

There is **one currency**. It is gold, it is spent everywhere, and what keeps the goal above true is not
a second purse but a **ceiling**:

> **Nothing the rift asks for may cost more than the cheapest thing the campaign sells.**

`Spoils.priceCeiling()` is `Grade.PRICE_BASE` — the price of a house's opening rung — and every seam
that quotes a price underground runs its number through `Spoils.askingPrice`. A purchase on floor three
is therefore always the *smaller* decision than any permanent one, by construction, so the comparison
that would spoil it never gets close enough to bite. "Can I afford this" stops being the question and
"will I need it" becomes it.

| | What it is | Where it is earned | Where it is spent |
|---|---|---|---|
| **Gold** | A number on the player | Every won fight, rolled by depth; authored payouts at ends | Everywhere: the seven shelves, the Forge, the Cafe, the road's Merchant, the Crossroads, the money kit |
| **Valuables** | Objects with a price, no class, no effect and no use | Ends only: elites, objectives, generals | Sold at a counter, at **par** ([models/valuable.lua](../models/valuable.lua)) |

## There were two purses, and why there are not

For a while a descent spent **scrip** — a weightless number that could not be carried home and was
burned at every exit. It existed for exactly the goal at the top of this page, and it worked. The
argument was good enough to be worth keeping on the record:

> a 200g relic on floor three was not priced against the rest of the floor — it was priced against a
> forge rung, and the player either declined every shop underground on principle or bankrupted the
> progression they came back up to spend on. Both of those are correct play, which is the tell: **a
> decision whose sensible answer is "never engage with this system" is not a decision.**

**What ended it was the shelf recut**, not a change of mind. Above a house's opening weapon, gear is no
longer sold at all — it is found in the rift and a counter stocks it only once one has been carried out
([docs/shelf.md](shelf.md), `tools/drop_tier.lua`). That took the gear off the road's Merchant, which
was scrip's largest sink. What remained was the Crossroads wagers and one ability kit: a currency with
one and a half sinks is a scoreboard, not a money, and `models/scrip.lua` is deleted.

**Three fences were available and only one survived the rest of the change.** *Evaporation* went with
scrip itself. *Weight* — gold riding in the pack, so a purchase is priced against the slot it occupies —
died with the mule. *Risk* — the purse dropped where the company fell — died with the pile system when a
wipe stopped costing anything ([docs/the-count.md](the-count.md)). **Magnitude** is what is left, and
unlike the other three it needs no object to hang on: only a number, anchored to the grader so a re-cut
of the shelf moves it.

## Why gold is also objects

The campaign's real income arrives as **valuables** — loot with a price and no use whatever — and that
is unchanged by the merge. Making it physical is what lets a haul be a decision at all:

- **Bulk is the knob.** A valuable declares how many slots it takes, and **worth per slot climbs with
  bulk** (`tests/economy_spec.lua` pins this). A three-slot idol is worth more per slot than three
  pocket pieces, so *"leave the censer, take the idol"* is a real question where a set that all weighed
  one would only ever ask "how many".
- **It is what the stair's toll takes a share of.** A gate that demands *n* finds counts the haul, and
  may never reach into the kit a company marched down with (`Player.atRisk`, `game:payToll`). That diff
  is the one piece of the old risk apparatus that outlived it.

**Valuables are lumpy, not litter.** They fall off ends — elites, objectives, generals — never off an
ordinary body, because one valuable per fight would be an inventory chore with a floor's worth of
clicking in it. The ambient income is plain coin. That split is still the whole economy in one line:
**the grind funds spending, the work you chose to walk to funds the campaign.**

### What the mule's deletion took with it

The mule capped a haul at 8–20 slots, could be sent home mid-run, and was away for a number of fights
afterwards. All three existed to bound a bet a wipe collected on — *"a bet with no ceiling is not a
bet"*, in its own header. A wipe collects nothing now, so the ceiling was guarding a stake that no
longer exists. A company carries out whatever it can pick up.

What went with it: `Mule.RUNGS`, the gold ladder bought at the Gate. That was a **gold sink**, and its
loss compounds with the shelf recut thinning the houses — worth watching in the first ten floors of a
campaign. If gold piles up with nothing to buy, the answer is more on the ability ladder, not gear back
on the shelf.

## The money kit

Money abilities (`Combat.spendPurse`, the greed/rogue shelf) spend the campaign's gold. `combat.lua`
never learns which purse it was handed — the injection happens in
[states/battle.lua](../states/battle.lua) — and an enemy still spends its own `coffer`, because a body
like Aurea is a walking treasury rather than a shareholder in your purse.

It spent scrip for a while, and the reason was the objection at the top of this page: billing a forge
rung to size a blow is a cost paid three menus and one expedition away from the swing that incurred it,
so the honest play was never to cast it. The ceiling answers that the other way, and **the kit is
sharper for the merge**: burning coin that evaporated at the next staircase was close to free, and
burning coin the Forge is waiting for is a real decision taken at the moment of the swing.

## What this obliges

- **Every gold price in the game is quoted against a curve that moved twice** — once when income became
  lumpy and end-weighted, and again when the two purses merged. The seven shelves, the Forge's gold
  rungs and the Cafe want re-reading against *measured* descent income rather than authored figures.
  `. board-report N descent` is the instrument.
- **The ceiling is a magnitude and magnitudes drift.** It is anchored to `Grade.PRICE_BASE` so a shelf
  re-cut carries it, but if the Merchant ever stops being worth stopping at, that number is the dial.

## The invariant

One claim, and it is about what *cannot* happen: **nothing underground is ever priced against a
permanent upgrade.** The failure mode is silent — a valuable that slips into `Spoils.shelf` does not
crash, it just puts the thing the player is descending to fetch on a counter for sale — so it is pinned
in [tests/economy_spec.lua](../tests/economy_spec.lua) rather than left to reading.

The exceptions that make it work, each one line somewhere and each invisible if it broke:

- `Spoils.askingPrice` clamps every underground quote, or a relic slate reaches a forge rung again.
- `lootCandidates` refuses valuables, or every idol in the data turns up as ordinary loot.
- `Vendor.sells` refuses them, or the Market — which stocks everything priced — sells them back to you.
- `Vendor.sellValue` pays them at **par**, not the 50% gear takes, because nobody ever sold you one: a
  valuable's price is its worth, and halving it here would mean every file authored at double.
- `Item.instantiate` copies `valuable` and `bulk` onto the instance, or the counter — which is handed
  live items and nothing else — cannot see them.
