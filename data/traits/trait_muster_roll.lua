-- The rule behind the Greywatch Muster Roll (data/items/utility/utility_greywatch_muster_roll.lua):
-- the bearer opens the battle harder to kill for each ally already standing beside them.
--
-- Diligence rendered as arithmetic, and the exact mechanical inverse of the oath Acedia imposes
-- (data/traits/trait_unrelieved.lua). Hers bites a unit for ending its turn apart; this pays a unit
-- for beginning the battle together. Same geometry, opposite claim about what it is worth.
--
-- Measured ONCE, at combat start, rather than per turn -- which is the design and not a shortcut. A
-- per-turn recount would reward shuffling into a huddle and back out again, and the whole line's
-- argument is about where you CHOSE to stand, not how well you can micro. Take post, and the roll
-- counts who took it with you.
--
-- Orthogonal adjacency, matching Combat.tryRedirect and status_sworn: "beside" means one thing across
-- the knight's whole vocabulary.
return {
    name = "The Muster",
    description = "Opens each battle with bonus defense for every ally already standing beside you.",
    magnitude = 3, -- defense per adjacent ally
    onCombatStart = function(ctx)
        local unit = ctx.unit
        local beside = 0
        for _, u in ipairs(ctx.unitsNear(unit.x, unit.y, 1)) do
            if u.alive and u ~= unit and u.side == unit.side
                and math.abs(u.x - unit.x) + math.abs(u.y - unit.y) == 1 then
                beside = beside + 1
            end
        end
        if beside > 0 then
            ctx.addBonus("defense", beside * ctx.def.magnitude)
        end
    end,
}
