-- BESTOWED: a share of the Oni General's own power, given to one oni (data/items/ability/ability_bestow.lua).
-- Reviewed 2026-09-27 ("The Oni of Wrath", round 2), after Reincarnated as a Slime's premise that power is
-- something a leader GIVES -- on an oni already standing, never an ogre.
--
-- +2 to every stat, and the horn cannot be snapped while the one who gave it still stands (trait_the_horn reads
-- `status.giver`). It lasts the fight; the General's death ends the ward on the horn but not the stats, since
-- what was given was given.
return {
    name = "Bestowed",
    abbr = "Gift",
    description = "Given the General's power: +2 to every stat, and the horn cannot be snapped while the General stands.",
    color = { 0.300, 0.180, 0.180 }, -- badge tint (black flame)
    duration = math.huge,
    hideDuration = true,
    statBonus = { damage = 2, magicDamage = 2, defense = 2, magicDefense = 2, speed = 2, movement = 2, skill = 2, luck = 2 },
    onApply = function(ctx)
        if ctx.applier then ctx.status.giver = ctx.applier end
    end,
}
