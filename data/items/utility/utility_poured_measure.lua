-- The Poured Measure: a charm with no ability of its own. It reaches into the ABILITIES sitting next
-- to it in the 3x3 grid (diagonals included), and every mana one of them spends comes back to the
-- caster as health. Same `aura` block every other charm on the rack declares, one new field
-- (`manaHeal`), aggregated by adjacencyAura and paid at the spend by combat.lua's drinkSpentMana.
--
-- IT IS VAMPIRIC STRIKE FOR CASTERS, and the parallel is the whole design rather than a comparison
-- made after the fact. That charm infuses the weapons beside it with a thirst and pays the wielder a
-- share of the wound it opens; this one infuses the workings beside it and pays the caster a share of
-- the pool it empties. Both cost one of nine cells, both are read off an adjacency the player arranges,
-- and both drink half. What separates them is where the number comes from: a blade's payout rises with
-- the blow it lands, and a working's payout rises with what it COST -- so the measure is worth most
-- beside the expensive spell a mage already hesitates over, and worth nothing at all beside a cantrip.
--
-- THAT IS THE DECISION IT SELLS. A caster's pools are the one resource in this game that does not come
-- back on its own (see utility_mana_wellspring.lua, which exists because of it), so the honest read of
-- a big spell is "I have four of these in the fight". The measure does not hand any of them back. It
-- converts the emptying into standing, which is the trade a theurge is already making at the altar --
-- and it means the expensive prayer stops being the one you save and becomes the one you lead with.
--
-- ABILITIES ONLY (`appliesTo`), deliberately. A weapon that bills mana exists (the crescent blade pays
-- for its beam out of the pool) and letting the measure drink off it would make the charm a flat
-- damage-and-sustain fixture beside a swing you take every single turn. Held to the ability shelf it
-- stays a caster's item, pays on the turns a caster actually spends, and leaves the weapon rack to
-- Vampiric Strike.
--
-- The heal is measured off the POOL at the moment of the spend, never off the printed price, so an
-- oath that doubles the working pays double and the Overdraft -- which stops the price being mana at
-- all -- pays nothing. drinkSpentMana's header argues that in full.
return {
    name = "The Poured Measure",
    description = "Adjacent abilities heal you for half the mana they cost.",
    flavor = "A shallow bronze bowl, worn thin at the rim. It comes back warm from whatever is poured out of it.",
    sprite = "assets/items/utility_poured_measure.png",
    type = "utility",
    tags = { "charm", "holy" },
    class = "theurge", -- the mage x priest crossing: arcane spending, answered as a priest answers it
    unlockLevel = 6,
    -- NO AUTHORED `grade`, deliberately. The instrument prices the PRESENCE of an `aura` block and is
    -- blind to what any of them carry, so it reads this at 19.2 and Vampiric Strike at 19.2 -- two
    -- charms doing the same trade on two shelves, rated alike. A judged grade here (Grade.of's
    -- authored hatch) would have to be judged there too, and filing one of a matched pair by hand is
    -- how a shelf order stops meaning anything. If the blind spot is ever closed it closes for both.
    aura = {
        appliesTo = { "ability" }, -- the workings it sits beside, never the weapon rack
        manaHeal = 0.5,            -- the caster drinks back half of what the working took
    },
    -- what it gives back keeps the caster upright -- the mana is the neighbour's
    bonus = { magicDefense = 1 },
}
