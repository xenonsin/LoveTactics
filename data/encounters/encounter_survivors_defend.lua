-- "Reach and defend": survivors caught in the open with the demons closing on them. The flight leg's
-- first real objective lesson (states/prologue.lua). It teaches the `defend` win type together with
-- OFF-PARTY objective placement -- the survivors are ANCHORED just ahead of the party's own line (the
-- `rally` anchor below; see models/arena.lua), not seated among the party, so the lesson is to step
-- forward and throw a wall up between them and the tree line rather than turtle in the back row.
--
-- The survivors sit close enough that the party can screen them on turn 1 (an earlier `center` anchor
-- put them mid-board, where the demons arrive first and the fight was a race the party could not win).
--
-- `weight = 0`: authored-only, reachable through a quest's `map.encounters.always` (like the siege
-- encounters). It never rolls into an ordinary board's pool.
--
-- The party keeps at least one survivor alive (`protect`, satisfied while ANY survivor stands) for
-- `duration` ticks while demons arrive in `waves`. Aggressive demons walk for the nearest enemy, which
-- is the anchored survivor -- so the party has to intercept. Prestige-scaled so the same encounter
-- still bites later in the game.
return {
    name = "Survivors Beset",
    kind = "combat",
    minPrestige = 1,
    weight = 0,

    allies = { "character_survivor", "character_survivor" },

    -- Turn 1 opens against two imps only -- enough pressure to force the party forward without a melee
    -- grunt already in reach of a survivor before anyone can screen. The grunt walks on as an early wave
    -- (below). Prestige still stacks extra imps for a later-game bite.
    composition = function(ctx)
        local p = ctx.prestige or 1
        local list = { "character_demon_imp", "character_demon_imp" }
        for i = 1, math.floor((p - 1) / 3) do list[#list + 1] = "character_demon_imp" end
        return list
    end,

    objective = {
        type = "defend",
        anchor = "rally",           -- survivors stand just ahead of the party's line; models/arena.lua seats them there
        duration = 30,              -- TICKS to outlast (the unit the clock counts and the HUD quotes)
        protect = "character_survivor",
        -- More demons out of the tree line as the clock runs, so the fight is a hold against a rising
        -- tide rather than a fixed set to clear. `at` is a tick mark on the same clock: the wave walks
        -- on once elapsed initiative passes it.
        waves = {
            -- The melee grunt held out of the opening, now closing behind the imps.
            { at = 6, composition = function() return { "character_demon_grunt" } end },
            { at = 10, composition = function() return { "character_demon_imp", "character_demon_imp" } end },
            { at = 20, composition = function(ctx)
                local list = { "character_demon_imp" }
                if (ctx.prestige or 1) >= 2 then list[#list + 1] = "character_demon_grunt" end
                return list
            end },
        },
    },
}
