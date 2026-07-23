-- The Culling Stroke: a swing that is unremarkable against a healthy body and lethal against a failing
-- one -- and if it kills, the fighter has not finished their turn.
--
-- THE EXTRA ACTION IS THE ITEM. Execution thresholds already exist on the rogue's shelf (that is what
-- greed's `execute` is), and a fighter version of one would be a reskin. What makes this wrath's is
-- fx.grantExtraAction: a kill re-opens the turn, so a fighter standing in the middle of a broken line
-- can cull, cull, and cull again while there are wounded bodies left to reach.
--
-- Which turns the END of a fight into the fighter's best moment rather than the priest's. It is worth
-- nothing on turn one against a full-health line, and on turn five, with three enemies at a quarter
-- health and a mace in the other hand, it is the largest swing in the game. That arc -- useless, then
-- decisive -- is the shape wrath is supposed to have.
--
-- The threshold, not the damage, is what scales. The blow itself is modest and stays modest; what the
-- forge and the grid buy is a WIDER window, which is a much more interesting number to raise: every
-- point of it turns some enemy from "nearly dead" into "dead, and I get another swing".
--
-- ADJACENCY: it counts the `weapon` items around it. A fighter with two axes and a hammer in the
-- neighbouring cells culls at nearly twice the threshold of one holding a single blade -- which is the
-- Colosseum's actual doctrine (bring everything, swing all of it) as a number, and a real competitor
-- for the cells Dual Wield and Cleave already want.
return {
    name = "The Culling Stroke",
    description = "Kills outright below a health threshold -- and a kill hands the turn straight back.",
    flavor = "The crowd does not cheer the first one. They have worked out what the first one means.",
    sprite = "assets/items/ability_culling_stroke.png",
    type = "ability",
    tags = { "slash", "physical" },
    class = "fighter",
    price = 420,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = { 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20 },
        adjacencyScaling = { type = "weapon" },
        effect = function(fx)
            local hp = fx.target.char and fx.target.char.stats and fx.target.char.stats.health
            if not hp or hp.max <= 0 then return end
            -- The window: a fifth of the target's maximum, plus a twentieth for every weapon beside
            -- this one in the grid, plus the forge. Read against MAX rather than against a flat number
            -- so it means the same thing against a boss as against a rat.
            local weapons = fx.adjacentMatching({ type = "weapon" })
            local window = 0.20 + 0.05 * weapons + 0.01 * fx.level
            if (hp.current / hp.max) <= window then
                -- Raw and enormous: an execution is not a big hit, it is the end of the argument. Sized
                -- off the target's own maximum so armor and health pools cannot make a body
                -- unexecutable -- the threshold already decided whether this lands.
                fx.damage(fx.target, { amount = hp.max, raw = true })
            else
                fx.damage(fx.target)
            end
            -- A kill hands the turn back (Combat.grantExtraAction -- the turn re-opens instead of
            -- ending, and the tempo is banked and settled when it finally does). Checked after the
            -- blow, on the body itself, so it pays for an ordinary swing that happened to finish
            -- somebody too -- the stroke rewards the KILL, not the threshold.
            if not fx.target.alive then
                fx.grantExtraAction(1)
                fx.log("action", string.format("%s does not stop.",
                    fx.user.char and fx.user.char.name or "The fighter"), fx.user)
            end
        end,
    },
}
