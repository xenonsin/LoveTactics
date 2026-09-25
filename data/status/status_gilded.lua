-- GILDED: plated in gold, and gold is a weight. Reviewed 2026-09-24 as written ("The Dwarves of Greed").
--
-- LUXURY AND THE BURDEN OF WEALTH: +3 Defense, -1 Movement, -2 Speed. On a dwarf it is armour -- the
-- Goldsmith's support half. On a company body it is worse than it looks, because every dwarf COVETS a
-- gilded body (`targetPref = "gilded"` on their rules, models/ai.lua) and goes for it first: it hands the
-- player a tank they did not choose, and the answer is to Cure it off or to use the bait.
--
-- AND IT IS WORTH SOMETHING: a gilded body that falls on the enemy's side pays BOUNTY gold into the
-- company's spoils (Combat.bounty), which is what makes Gilder's Leaf a mammonite piece and not only a
-- slow. A company body that falls gilded pays nobody -- the dwarves do not get to bank the company.
local BOUNTY = 20

return {
    name = "Gilded",
    abbr = "Gild",
    description = "Plated in gold: increase defense, reduce movement and speed. Dwarves go for it first, and it pays gold if it falls on the enemy's side.",
    color = { 0.886, 0.760, 0.345 }, -- badge tint (leaf gold)
    duration = 20, -- ~4 turns
    statBonus = { defense = 3, movement = -1, speed = -2 },
    onDeath = function(ctx)
        if not ctx.combat or ctx.unit.side == "party" then return end
        require("models.combat").bounty(ctx.combat, BOUNTY)
        ctx.log("action", string.format("%s's gilding is prised off: %d gold.",
            (ctx.unit.char and ctx.unit.char.name) or "It", BOUNTY), ctx.unit)
    end,
}
