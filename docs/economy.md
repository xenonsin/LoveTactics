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
| **Gold** | A number on the player | Every won fight, rolled by depth; an **end purse** on top at every end ([`Spoils.endPurse`](../models/spoils.lua)); authored payouts | Everywhere: the seven shelves, the Forge, the Cafe, the road's Merchant, the Crossroads, the money kit |

## There were two purses, and why there are not

For a while a descent spent **scrip** — a weightless number that could not be carried home and was
burned at every exit. It existed for exactly the goal at the top of this page, and it worked. The
argument was good enough to be worth keeping on the record:

> a 200g relic on floor three was not priced against the rest of the floor — it was priced against a
> forge rung, and the player either declined every shop underground on principle or bankrupted the
> progression they came back up to spend on. Both of those are correct play, which is the tell: **a
> decision whose sensible answer is "never engage with this system" is not a decision.**

**What ended it was the shelf recut**, not a change of mind. Above a house's opening weapon, gear
stopped being sold at all — it was found in the rift and a counter stocked it only once one had been
carried out ([docs/shelf.md](shelf.md), `tools/drop_tier.lua`). That took the gear off the road's
Merchant, which was scrip's largest sink. What remained was the Crossroads wagers and one ability kit:
a currency with one and a half sinks is a scoreboard, not a money, and `models/scrip.lua` is deleted.

> **The half of that recut which justified this has since been reversed, and scrip is not coming back.**
> A found ware is dealt at its class rung now, so the gear IS on a counter again ([shelf.md](shelf.md)).
> The argument above still holds and is why: scrip died because it had one and a half sinks, and
> restoring a sink to the currency that replaced it does not resurrect the one that was deleted. What it
> does do is make the *magnitude* fence below load-bearing rather than precautionary — see the sink
> problem in **What this obliges**.

**Three fences were available and only one survived the rest of the change.** *Evaporation* went with
scrip itself. *Weight* — gold riding in the pack, so a purchase is priced against the slot it occupies —
died with the mule. *Risk* — the purse dropped where the company fell — died with the pile system when a
wipe stopped costing anything ([docs/the-count.md](the-count.md)). **Magnitude** is what is left, and
unlike the other three it needs no object to hang on: only a number, anchored to the grader so a re-cut
of the shelf moves it.

## Gold was objects for a while, and is not

The campaign's real income arrived as **valuables** — priced loot with no use whatever, dropped by ends,
carried out of the rift and sold at a counter. **Weight was the entire argument.** A valuable took mule
slots, so treasure competed with the gear you found; it rode in the pack, so a wipe dropped the takings
where the company fell. Both of those systems are deleted — the mule has no cap to fill and a wipe takes
nothing — and what was left was an inventory step standing between winning a fight and being paid for
it: carry the idol home, open a shop, click sell. **A step with no decision in it is not a decision.**
`models/valuable.lua` and `data/items/valuable/` are gone.

**What survived is the shape**, because the shape is why the descent has a direction. An end pays an
**end purse** in coin on top of what its fight was worth (`Spoils.endPurse`):

- **Lumpy, not litter.** Only an end pays one — an elite, an objective, a general, which pays double —
  never an ordinary body. **The grind funds spending, the work you chose to walk to funds the
  campaign.** Spreading it over every fight would make the whole floor worth the same to walk.
- **It climbs steeply**, far faster than an ordinary fight's gold (`GOLD_DEPTH_SLOPE`). That climb is
  what the greed at a landing is weighing. It goes flat at floor 11, which is where the old pool topped
  out — a campaign road passes its *day* in as depth and the calendar runs to 40.
- **The numbers are the old ladder's, measured.** The valuable pool ran 110g on floor 1 to 1,500g on
  floor 11, drawn twice with the dearer kept: ~150g and ~850g expected. A base of 130 on a slope of 0.55
  tracks that at every rung it had, so measurements taken against the object economy still read.
- **The stair's toll is unaffected.** It takes a share of the *finds*, counted by the head, and may
  never reach into the kit a company marched down with (`Player.atRisk`, `game:payToll`). That diff is
  the one piece of the old risk apparatus that outlived it.

### What the mule's deletion took with it

The mule capped a haul at 8–20 slots, could be sent home mid-run, and was away for a number of fights
afterwards. All three existed to bound a bet a wipe collected on — *"a bet with no ceiling is not a
bet"*, in its own header. A wipe collects nothing now, so the ceiling was guarding a stake that no
longer exists. A company carries out whatever it can pick up.

What went with it: `Mule.RUNGS`, the gold ladder bought at the Gate. That was a **gold sink**, and its
loss compounded with the shelf recut thinning the houses — worth watching in the first ten floors of a
campaign.

> **That watch is over, and it resolved the way this paragraph said it should not.** The line here read
> *"if gold piles up with nothing to buy, the answer is more on the ability ladder, not gear back on the
> shelf"* — and gear went back on the shelf. It was not a sink decision: the gate came off because a
> drop table cannot guarantee reachability and a shelf can ([shelf.md](shelf.md)), and the sink is a
> side effect of the fix rather than its purpose. Recorded rather than quietly edited, because the
> prediction was a real one and it was overruled on other grounds.
>
> **Which inverts the risk.** The question is no longer whether gold piles up with nothing to buy; it is
> whether a trip pays enough that a rung of a class's stock is a decision rather than a formality. That
> is a measurement, not a guess — see below.

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

## The Forge's mend: one of those prices, re-read

The bullet below asks for the Forge to be measured rather than assumed. It has been, and it was worse
than mis-tuned — it was **gone**.

Mending was `10% of item.price, scaled by what is missing`, and the argument for the share was sound:
the richer the company, the more it costs to keep what makes it rich, which is the shape a sink wants.
Then the shelf recut took `price` off everything above a house's opener ([shelf.md](shelf.md)) and the
formula read `(item.price or 0)` — so for most of the catalogue the bill collapsed onto its own
`math.max(1, …)` floor. Measured: **a fully destroyed Frostfall Hammer mended for one gold**, and so
did broken Leather Armor, while a priced iron sword still cost 8. Nothing failed, because a formula
reading a field almost nobody carries still returns a number.

It is now a **fixed rate per point of wear** (`Forge.MEND_PER_POINT = 2`) — the smith charges for the
hour, not for the blade:

| | |
|---|---|
| a full weapon bar (30) | **60g** |
| a full armour bar (40) | **80g** |
| one uncured Corroding (12 points) | **24g** |
| *for comparison* — the Ward buying off a wound | 40g |

Measured against descent income (`Spoils.roll`, 200 rolls a floor): an ordinary fight pays **54g on
floor one** and **208g on floor fifteen**; elites 242g → 1267g. A fielded four keeping a dozen pieces
whole runs roughly a fifth to a third of a trip's take.

**What the fixed rate gives up**, recorded because it overrules the share version's own argument: it
does not climb with the campaign. Income roughly quadruples across a descent and this does not, so the
sink is heaviest in the first floors and thinnest at the bottom. If that trade is wrong the fix is one
line — price it off `Vendor.foundPrice(item)`, which is the function that already answers *what is this
unpriced found ware worth* and is what the share version should have been reading all along.

## What this obliges

- **Every gold price in the game is quoted against a curve that moved twice** — once when income became
  lumpy and end-weighted, and again when the two purses merged. The seven shelves, the Forge's gold
  rungs and the Cafe want re-reading against *measured* descent income rather than authored figures.
  `. board-report N descent` is the instrument.
- **The ceiling is a magnitude and magnitudes drift.** It is anchored to `Grade.PRICE_BASE` so a shelf
  re-cut carries it, but if the Merchant ever stops being worth stopping at, that number is the dial.
- **Gold became a gear currency the day the discovery gate came off** — **347 wares** now reach a
  counter that did not, each priced at `Grade.priceFor(dropTier - 1)`. Measured rather than feared,
  and the two ladders turn out to be roughly parallel, because both are keyed to depth:

  | depth it drops at | 1 | 3 | 6 | 8 |
  |---|---|---|---|---|
  | its rung | 0 | 2 | 5 | 7 |
  | what the counter charges | 80g | 245g | 495g | 660g |
  | what an objective on that floor pays | 130g | 273g | 487g | 631g |

  So **an end pays about one piece at its own depth**, and a general pays two. That is a defensible
  resting point and not a designed one — nobody chose it, it falls out of both numbers reading the
  same axis. What it means practically is that the risk is *scarcity*, not a pile: a full class shelf
  runs 6,700g (alchemist) to 23,300g (knight), so a campaign buys a handful of pieces and finds the
  rest. Re-measure after any re-tier, since a tier now moves the price as well as the depth.

  **The dial is `Spoils.endPurse`, never the derived price** — a price is the grade speaking, and
  moving one by hand re-opens the tautology [shelf.md](shelf.md) exists to close.

## The invariant

One claim, and it is about what *cannot* happen: **nothing underground is ever priced against a
permanent upgrade.** The failure mode is silent — an ask that drifts over the ceiling does not crash, it
just puts a floor-three find beside a forge rung — so it is pinned in
[tests/economy_spec.lua](../tests/economy_spec.lua) rather than left to reading.

What holds it up, each one line somewhere and each invisible if it broke:

- `Spoils.askingPrice` clamps every underground quote, or a merchant's shelf reaches a forge rung
  again. (It was a *relic slate* that first made this bite; that shelf is parked — [relics.md](relics.md)
  — and the clamp still holds the gear the road sells.)
- `Spoils.endPurse` is the only place an end's income is decided, and it is capped at floor 11, or a
  late campaign road out-pays the bottom of the rift.
- **Every price in the game is a shelf price**, so every price needs a shelf
  (`tests/progression_spec.lua`). The one exception was the valuable, whose number was what a counter
  *paid*; the same spec is what would catch one being authored back in.
