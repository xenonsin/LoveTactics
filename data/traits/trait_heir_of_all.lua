-- Heir of All: the Hoard-Thane's rule (data/items/utility/utility_the_thanes_seal.lua).
--
-- THE FLAG: trait_inheritance, run on every dwarf that falls, looks for a living kinsman carrying this
-- FIRST and at any range -- so every Share on the board flows to him, and every coffer with it. The fight
-- is a race that way: kill the line and he grows; leave it standing and it fights you while he hires.
--
-- THE KING'S JEWEL (round 3, 2026-09-24 -- the Arkenstone): when he falls, the office does not die with
-- him. It drops on his tile as a jewel (data/hazards/hazard_kings_jewel.lua), and the first dwarf to reach
-- it becomes the new heir of every Share. Killing the Thane is a race for the jewel, not the end of it.
return {
    name = "Heir of All",
    description = "Every fallen dwarf's Share and coffer pass to you. When you fall, the King's Jewel drops where you stood.",
    heirOfAll = true,
    onDeath = function(ctx)
        local unit = ctx.unit
        if not (ctx.combat and unit) then return end
        ctx.placeHazard(unit.x, unit.y, "hazard_kings_jewel", { side = unit.side })
        ctx.log("action", string.format("The King's Jewel falls from %s's hand.",
            (unit.char and unit.char.name) or "the Thane"), unit)
    end,
}
