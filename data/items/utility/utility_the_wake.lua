-- THE WAKE: the Unseeing's ground, taken off him.
--
-- `trail` on any item in the grid is laid by Combat.layTrail from Combat.enterTile on every walked or
-- forced step -- the seam the Cinderstride Boots, the Tidewalker Boots and the Wellspring Sandals all
-- ride. This one lays curse (data/hazards/hazard_curse.lua), and that is the whole item.
--
-- IT IS THE ONLY GROUND IN THE GAME THAT DENIES HEALING, and it bleeds what stands in it besides
-- (data/status/status_cursed.lua: three a turn, and nothing gets it back). The trail shelf is fire,
-- rain, wellspring and caltrops -- four ways of hurting or helping whoever stands there, and every one
-- of them answerable by a priest. This is the one that is not.
--
-- WHICH IS WHAT IT IS ACTUALLY FOR. An enemy healer is the thing that turns three committed turns into
-- nothing, and the answer the game offered was "kill the priest first", which is the same problem moved
-- one tile. This is the other answer: walk the ground they have to stand on. The zone is side-agnostic
-- like every other hazard, so what you lay getting there is ground your OWN priest cannot work on and
-- your own line loses health standing in -- a real cost on a narrow carve, and the reason this is a
-- decision rather than a free wall.
--
-- The enemy AI steps around it (`disposition = "hostile"` on the hazard), so like the Cinderstride
-- Boots this is less a trap than a wall you draw by walking away -- except that the wall it draws is
-- specifically between a wounded body and the person who was going to mend it.
--
-- Shorter-lived than what a fallen body leaves, on the Pilgrim's Sandals' rule: prints that cost
-- nothing at all must not outlast ground somebody had to die on (data/traits/trait_curse_bearer.lua
-- leaves the hazard's full 25).
return {
    name = "The Wake",
    description = "The tile you step off is cursed: it eats at whoever stands there, and they cannot be healed.",
    flavor = "Whatever went through here first was not walking. You can tell from what will not grow.",
    sprite = "assets/items/utility_the_wake.png",
    type = "utility",
    tags = { "boots", "dark" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS: the house that wins by making a wound worse rather
    -- than by making it bigger. `class` is the vendor shelf and never an equip gate -- anyone may carry it.
    class = "plague_knight",
    -- A RUNG DEEPER THAN THE INSTRUMENT FILES IT, and the reason is the third sighting of one blindness.
    -- tools/drop_tier.lua reads net stat swing and replayed damage; a `trail` is neither, so this graded
    -- 4.5 when the ground only refused healing and graded 4.5 again once it started eating people --
    -- the same number for two different items. The figure below is what free, damaging, unhealable
    -- ground laid on every step is worth, and it still sits under the horn, which is where the list
    -- wants it.
    unlockLevel = 6,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    trail = { hazard = "hazard_curse", duration = 10 },
    bonus = { movement = 1 }, -- footwear; the curse is what it leaves
}
