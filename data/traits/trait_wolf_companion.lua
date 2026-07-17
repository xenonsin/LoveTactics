-- The Archer's innate: she was raised beside a wolf, and it fights at her side from the first bell.
-- At combat start it summons a wolf onto an open tile next to her -- sustained by her (it falls if she
-- does), but FREE, with none of the mana reservation the Summon Wolf ability item demands. That is the
-- point of an innate: the quirk is hers without an item, and the loadout is built around it.
--
-- The wolf holds the horn's `activeSummon` claim while it stands (ctx.summon, models/trait.lua), so the
-- relic that granted it opens the battle already spent: the archer cannot blow it for the Wolfsong
-- Spirit over a companion that is alive and well. One creature answers the horn at a time, and the
-- true call is what she is left with once the pack is gone.
--
-- Distinct from data/items/ability/ability_summon_wolf.lua, which any character can carry and recast.
-- This one is a single companion, granted once, at no cost.
return {
    name = "Wolf Companion",
    description = "Starts each battle with a wolf at your side, free of any reservation.",
    onCombatStart = function(ctx)
        local x, y = ctx.openTileNear(ctx.unit.x, ctx.unit.y)
        if x then
            ctx.summon("character_wolf_grunt", x, y, { scaling = { health = 2, damage = 0.5 }, amount = 8 })
        end
    end,
}
