-- Plaguebearer's Draught: the Plague Knight's opening move (knight x alchemist). You drink poison, and
-- every enemy standing beside you catches it in the same breath.
--
-- The self-poison is not a cost the item apologises for -- it is the mechanism. Contagion reads poisoned
-- BODIES rather than poisoned enemies, so a plague knight who has sickened itself becomes a walking
-- source: from the turn this is drunk, the rot spreads out of the knight's own tile into whatever is
-- standing next to it, every turn, for free. And the Rot-Fume Gauntlet counts your own affliction toward
-- its damage.
--
-- So the three items are one sentence: drink it (this), spread it (Contagion), collect on it (Rot-Fume).
-- None of the three is worth much alone, which is what a discipline is supposed to feel like.
--
-- The burst on the adjacent is what makes it worth a turn on its own if you do not own the other two --
-- a consumable that only harmed its drinker would be an item nobody buys first, and the deep shelf has
-- to be enterable from somewhere.
return {
    name = "Plaguebearer's Draught",
    description = "Inflicts Poison on you and every adjacent enemy; you become the source.",
    flavor = "The first plague doctors were not immune. They were simply willing, which is cheaper.",
    sprite = "assets/items/consumable_plaguebearers_draught.png",
    type = "consumable",
    -- NOT tagged `potion`, and that is a rule rather than a preference: the Market's `stockTags` resells
    -- anything wearing it, and a general store ignores repRank entirely (docs/classes.md). A
    -- discipline-locked draught tagged `potion` would sit on the grocer's shelf from the first visit,
    -- which unlocks the gated item without the gate.
    tags = { "draught", "poison" },
    class = "alchemist",
    discipline = "plague_knight",
    price = 120,
    unlockQuests = 6,
    maxStack = 3,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 2,
        consumesItem = true,
        description = "Inflicts Poison on you and every adjacent enemy.",
        effect = function(fx)
            fx.applyStatus(fx.user, "status_poison")
            for _, u in ipairs(fx.unitsNear(fx.user.x, fx.user.y, 1)) do
                if u.alive and u.side ~= fx.user.side then
                    fx.applyStatus(u, "status_poison")
                end
            end
        end,
    },
}
