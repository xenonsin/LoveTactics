-- The Archer's innate: she was raised beside a wolf, and it fights at her side from the first bell.
-- At combat start it summons a wolf onto an open tile next to her -- sustained by her (it falls if she
-- does), but FREE, with none of the mana reservation the Summon Wolf ability item demands. That is the
-- point of an innate: the quirk is hers without an item, and the loadout is built around it.
--
-- The wolf is summoned `noClaim` (ctx.summon, models/trait.lua): it does NOT lock the granting item's
-- active, because the Wolfsong Horn's howl fires WHILE the wolf stands, not once it is gone
-- (data/items/utility/utility_wolfsong_horn.lua). Instead the wolf is stashed on the archer as
-- `unit.wolfCompanion`, which the horn's `when` gate and its howl both read -- when the wolf dies it
-- cannot be resummoned, the back-ref goes stale (`alive == false`), and the horn falls silent with it.
--
-- Distinct from data/items/ability/ability_summon_wolf.lua, which any character can carry and recast.
-- This one is a single companion, granted once, at no cost.
return {
    name = "Wolf Companion",
    description = "Starts each battle with a wolf at your side, free of any reservation.",
    onCombatStart = function(ctx)
        local x, y = ctx.openTileNear(ctx.unit.x, ctx.unit.y)
        if x then
            ctx.unit.wolfCompanion = ctx.summon("character_wolf_grunt", x, y,
                { scaling = { health = 2, damage = 0.5 }, amount = 8, noClaim = true })
        end
    end,
}
