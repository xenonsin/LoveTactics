# Meals

The Cafe sells one thing: **one meal before the road**. You may hold one at a time, the whole company
eats it, and it lasts until the quest is done.

Names are café fare on purpose — a pot, a plate, a board, a cup. The building is a café, not a
roadhouse, and a menu of stews and suppers was quietly writing it as one.

This file is the contract. `models/meal.lua` is the implementation, `data/meals/<id>.lua` the
blueprints, `ui/panels/cafe.lua` the counter, and `tests/meal_spec.lua` is what keeps the three
honest.

## Why the Cafe is not a shop

It used to be the **general store**: a shelf for the classless priced goods (a torch, the Boots of
Speed) plus a resale rack that carried every `potion`, whichever house brewed it. Both halves were a
hedge against the seven houses rather than a thing of its own.

- The classless goods were classless because **nobody had asked which sin wanted them**. Every one of
  the five had an obvious home the moment the question was put: the torch is the Lodge's (gluttony's
  whole vocabulary is *knowing what is out there first*), the boots and the flare are the Undercroft's
  (greed already owns every other boot that buys a square, and already owns the hiding the flare
  answers), the Stormglass Rod is the Arcanum's, and the Wellspring Sandals are the Crucible's.
- The **potion resale was a hole in the Crucible's own ladder.** A general store ignores `unlockQuests`
  by design, so a Panacea gated at ten alchemist quests was on the grocer's counter from the first
  visit. The gate was still authored, still displayed, and could be walked around by shopping next
  door.

So the shelf was distributed, the resale was closed, and the building was given something only it can
sell. See [classes.md](classes.md) for the shelf contract the redistribution obeys.

**The Cafe keeps a vendor blueprint anyway** (`data/vendors/cafe.lua`), because it keeps a
*shopkeeper*: the portrait, the name and the one-time first-visit greeting all hang off it, and the
hub's first-visit machinery is keyed on a building naming a vendor. It declares `sells = false`, which
is the whole of its shelf contract — `Vendor.sells` refuses everything, so no item can ever drift onto
this counter by acquiring or losing a class.

## The one-ration rule

> **You hold one meal. Buying is refused while one is held. The quest eats it through.**

`player.meal` is a single meal id. `Meal.eat` refuses a second, `Quest.complete` clears it at the
objective, and `Meal.blockReason` names which of the three refusals applies — already eaten, not on
the menu yet, not enough gold — so the counter can say it in words rather than greying a row.

**A run that ends any other way keeps it.** A wipe or a walk-out rolls the company back to exactly how
it marched in (`states/game.lua`), supper and gold together. That is not generosity, it is the
extraction rule already written: a run only banks — and only spends — through the objective.

The point of all this is that the decision is **once per quest, made before you know the ground**. It
is a wager on what the run will ask for, not a knob to retune between fights. That is the whole reason
this is a menu rather than a shelf: a shelf is a thing you own afterwards, and a menu is a thing you
choose today.

## A platter is two halves

```lua
return {
    name = "Black Tea and Cardamom",
    description = "Deepens the company's magic, and hands mana back at the start of every battle.",
    flavor = "The cardamom is the point. She says the tea is only there to carry it up the hill.",
    price = 130,
    unlockPrestige = 3,        -- the rank the city grows into it at
    bonus = { magicDamage = 2 },        -- the courses: flat stats, every member
    maxBonus = { mana = 10 },           -- ...and resource ceilings
    resist = { fire = 3 },              -- ...and flat wards, per damage tag
    skill = "trait_meal_bottomless_pot",-- the kitchen skill: one named rule
}
```

| Half | Field(s) | What it is |
|---|---|---|
| **The courses** | `bonus`, `maxBonus`, `resist` | Flat numbers, worn by every member. Folded in beside the grid's own armour. |
| **The kitchen skill** | `skill` | One named trait, attached item-less. The reason to pick this dish over a bigger number. |

**A platter must buy at least one of the two.** `tests/meal_spec.lua` fails a plate of nothing.

**A meal declares no `sprite`, deliberately.** Nothing carries it, so it has no icon slot anywhere —
not a grid cell, not a stash row, not a tooltip — and the counter draws only text. Declaring art that
nothing renders would put a bucket of debt into `art-report` for pictures no surface has room for. If
the menu ever grows plates, the field goes on then, alongside the code that draws it.

### How it reaches the board

Battle setup stamps the held blueprint onto every party unit as `unit.meal` — including the **bench**,
since a member rotated in mid-fight ate the same supper as the four who opened. Two places read it,
and neither is a new code path:

- `Combat.applyUnitPassives` folds `bonus` / `maxBonus` / `resist` in **beside the grid's**, so a
  supper's +2 defense is the same quantity a coat's +2 is. The damage breakdown, the mitigation maths
  and the loadout tooltip need no case of their own.
- `Trait.attach` instantiates the `skill` **item-less**, exactly as it does a relic's granted traits.

Nothing about a meal survives the battle: `unit.bonus` is rebuilt from scratch at every setup, so the
supper is re-eaten at each bell of the quest and never compounds across its fights.

## Magnitudes: one rung below a shelf

A meal is worn by **four bodies at once**, costs **no grid cell**, and is never forged. So the courses
sit one rung below what the same number buys on a shelf: `+2` where a level-0 charm gives `+2` to one
body, `+14` max health where Toughness gives `+20` to one.

Subtractive mitigation means a point of defense and a point of weapon power are the same quantity
(see [balance.md](balance.md)), so a party-wide `+2 defense` is a real number and must be priced as
one. **Do not reach for a bigger figure to make a dish feel worth ordering** — reach for a kitchen
skill. That is what the second half is for.

Two magnitudes are deliberately load-bearing and should not be raised without re-reading why:

- **`movement`.** Armour never grants a square and the only things that hand one back are the
  Undercroft's boots, one cell and one body at a time ([classes.md](classes.md), *Armor costs a
  square*). The Walking Lunch gives it to the whole company, which is why it is the most expensive
  platter with no skill on it and why it is gated well above the opening three. A supper handing out
  pace on day one would be the answer to every early quest.
- **`revivesAt` on Moxie.** Second Wind stands one earned body up at half health. The Empty Chair
  refuses a death for *every* member, bought with gold, so it comes up at 0.15 — a second chance, not
  a second life.

## The menu grows

`unlockPrestige` gates a dish exactly as it gates a building, and the counter lists the whole menu at
every rank — a dish the city has not grown into is greyed and shows the prestige it opens at rather
than a price you cannot pay. A kitchen that offered its best platter on day one would only ever be
ordered from once.

## Borrowed from Monster Hunter, and what was left behind

The canteen is the model, openly. Three things came across:

- **A platter is courses plus a Felyne skill** — a number and a rule, and the rule is the interesting
  half.
- **It is a pre-hunt decision**, spent on the way out, not re-rollable in the field.
- **The menu grows** as you do.

One thing deliberately did not: **the ingredient minigame and the activation chance.** A buff that
sometimes does not happen is unreadable on a board where every other number is exact, and MH can
afford it because a hunt is fifty minutes of continuous feedback. A quest here is four fights of
arithmetic. Ours always fires.

The skills themselves are adaptations rather than ports, and each trait file says which one it came
from and what changed:

| Kitchen skill | From | What changed on the way |
|---|---|---|
| **Heroics** (`trait_meal_heroics`) | Felyne Heroics | A threshold, not a ramp — a ramp makes taking damage a small buff. |
| **Moxie** (`trait_meal_moxie`) | Felyne Moxie | Rises at a sliver, because it applies to four bodies rather than one. |
| **The Bottomless Pot** (`trait_meal_bottomless_pot`) | Felyne Booster | Points at **mana**, the one resource that never regenerates — which makes it far sharper here than there. |
| **The Wake** (`trait_meal_the_wake`) | Felyne Insurance | Read from the other side: what the loss does to the four still standing, not what it costs the one who fell. |
| **Finish the Plate** (`trait_meal_finish_the_plate`) | Felyne Slugger | Slugger sharpens stun, which most companies here cannot use. What survives is the shape: a skill that only pays where you are already committed. |

## Adding a meal

1. Write `data/meals/<id>.lua` with `name`, `description`, `flavor`, `price`, `unlockPrestige`, and at
   least one of `bonus` / `maxBonus` / `resist` / `skill`.
2. If it carries a kitchen skill, the trait goes in `data/traits/` like any other and must declare a
   `name` and a `description` — the counter prints the trait's own wording, never a second copy.
3. Keep the courses one rung below a shelf item's, per the magnitudes section above.
4. Run `& "E:\LOVE\lovec.exe" . test meal`.
