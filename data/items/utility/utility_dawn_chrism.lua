-- Cathedral rank-4. A passive aura, in the shape of data/items/consumable/consumable_fire_stone.lua: it sanctifies
-- the weapons and abilities adjacent to it in the 3x3 grid, lending them the holy tag. Kit that
-- already channels shadow refuses the blessing.
--
-- It is an ampulla of consecrated oil, NOT a censer: `censer` is a weapon family (docs/weapons.md),
-- and a censer's claim is `incense` -- ground that walks with its bearer. This lays no ground and
-- swings at nobody. It anoints whatever is stood next to it in the grid and nothing else.
--
-- The Cathedral insists the chrism purifies. It is never explained why it must be carried at all
-- times, nor what the oil keeps at arm's length -- the first hint of Lust, whose general takes
-- what is not offered.
return {
    name = "Dawn Chrism",
    description = "Adjacent weapons and abilities gain holy.",
    flavor = "The Cathedral insists it purifies. It never explains why it must be carried at all times, nor what the oil keeps at arm's length.",
    sprite = "assets/items/dawn_chrism.png",
    type = "utility",
    tags = { "holy" },
    class = "crusader", -- fighter x priest; Smite as an aura -- the Cathedral consecrating somebody else's steel
    unlockLevel = 6,
    aura = {
        appliesTo = { "weapon", "ability" },
        exceptTags = { "shadow" },
        grantTags = { "holy" },
    },
    -- it makes the grid beside it holy
    bonus = { magicDamage = 2 },
}
