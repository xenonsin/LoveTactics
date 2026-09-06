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
permanent upgrade.** The failure mode is silent — an ask that drifts over the ceiling does not crash, it
just puts a floor-three relic beside a forge rung — so it is pinned in
[tests/economy_spec.lua](../tests/economy_spec.lua) rather than left to reading.

What holds it up, each one line somewhere and each invisible if it broke:

- `Spoils.askingPrice` clamps every underground quote, or a relic slate reaches a forge rung again.
- `Spoils.endPurse` is the only place an end's income is decided, and it is capped at floor 11, or a
  late campaign road out-pays the bottom of the rift.
- **Every price in the game is a shelf price**, so every price needs a shelf
  (`tests/progression_spec.lua`). The one exception was the valuable, whose number was what a counter
  *paid*; the same spec is what would catch one being authored back in.
