-- "Get them out": a refugee has to be walked off the far edge of the board while demons try to cut
-- the road. The flight leg's second objective lesson (states/prologue.lua), teaching the `reach`
-- (extraction) win after the defend fight taught holding ground -- the same shape the Bastion's
-- siege road runs on (data/encounters/encounter_siege_*.lua), reused here for the prologue.
--
-- `weight = 0`: authored-only, placed through a quest's `map.encounters.always`.
--
-- The driver `escort`s -- it walks for the exit on its own every turn it is not swinging at something
-- in reach (models/ai.lua) -- so the fight is won by clearing its path, not by babysitting it. It
-- must both cross (`who`) and live (`protect`): fighting through is not enough, the person has to
-- actually get out.
--
-- The two halves of that are a pair, and neither is a fight on its own. The column holds while any
-- demon stands within one demon's stride, so ground the party has not cleared is a turn the wagon does
-- not spend moving; and the `waves` below keep feeding the road ahead while it stands there, so the
-- turn costs something. Take either one away and the stop is a kill-them-all: without the hold the
-- wagon crosses whatever the party does, and without the clock the party clears the field at leisure
-- and then walks it out.
return {
    name = "Break for the Tree Line",
    kind = "combat",
    minDay = 1,
    weight = 0,

    allies = { "character_caravan_driver" },

    composition = function(ctx)
        local p = ctx.day or 1
        local list = { "character_demon_imp", "character_demon_imp" }
        for i = 1, 1 + math.floor((p - 1) / 3) do list[#list + 1] = "character_demon_grunt" end
        return list
    end,

    objective = {
        type = "reach", region = "far",
        who = "character_caravan_driver",
        protect = "character_caravan_driver",

        -- THE ROAD KEEPS CLOSING. Authoring this list replaces the trickle a reach objective is handed
        -- for free (models/arena.lua's pressureWave: half the opening line, from every side, every 12
        -- ticks, topped at the opening strength). That default is what an unauthored road gets, and on
        -- this one it was too thin to be a clock: two imps re-landing at the board's edge against a
        -- party that opens on them is a treadmill, not pressure, and the stop played as a kill-them-all
        -- with a wagon rolling out behind it.
        --
        -- What replaces it is aimed at the driver's own stop rule instead of at the party's health bar.
        -- The column holds while any foe stands within one demon's stride (character_caravan_driver),
        -- so every demon standing anywhere near the road is a turn the wagon does not move -- which
        -- makes a wave that lands IN FRONT of it the thing that actually costs, and dawdling the thing
        -- that pays for it.
        --
        -- `from = "back"` is behind the enemy's line (Combat.resolveWaveEdge), which on a `reach` map is
        -- the tree line the column is driving AT: reinforcements step into the road ahead. They land
        -- clear of the wagon either way (Combat.WAVE_PROTECT_CLEARANCE), so this is pressure on the
        -- crossing rather than a knife at the charge's back.
        --
        -- SIZED AGAINST THE TWO BODIES THAT MEET IT -- the avatar and Rowan -- and measured rather than
        -- guessed: the stop was run headless with both sides on the AI (models/autobattle.lua's loop,
        -- with the waves walked on by hand), which is a floor rather than a forecast, since nobody is
        -- steering the screen and the party carries none of the four stops of kit it actually arrives
        -- with. Ten runs of the default road crossed 7 times, in 35 unit-turns and against 4 arrivals;
        -- ten of this one crossed 8 times, in 46 turns and against 6. That is the shape being aimed at
        -- -- a longer crossing with more road to clear, not a deadlier one -- and it is why the early
        -- grunt this list opened with was cut: out of the tree line at tick 8 it took the wagon down in
        -- 7 runs of 8, which is not a harder crossing, it is a different fight.
        waves = {
            -- The party has committed forward with the wagon by now, so the first arrival comes in
            -- beside them -- the edge nearest where they are actually standing, not the far line.
            { at = 16, from = "flank", composition = function(ctx)
                local list = { "character_demon_imp" }
                if (ctx.day or 1) >= 2 then list[#list + 1] = "character_demon_imp" end
                return list
            end },
            -- The press: two more imps into the road ahead every few turns for as long as the crossing
            -- drags on, holding off while the board is still full (`maxAlive`) so it tops the road up
            -- rather than piling on. Uncapped, like the default it replaces and for the default's own
            -- reason -- a road you have to WALK across cannot be won by clearing the field -- and the
            -- cap that was written here first is gone: it handed the last stretch back to the stroll
            -- this whole list exists to end.
            --
            -- Which leaves the one thing worth checking, since the column will not roll with anything
            -- inside four tiles and this feeds the very edge it is walking into: whether an endless
            -- tide can hold the wagon still forever. It does not: the board is held at four demons, and
            -- two bodies clear that faster than fourteen ticks refills it, so a firing costs the column
            -- a turn or two of standing still rather than the road it still has to cross, and
            -- ten headless runs finished every time -- no stall, at either the four-tile hold or the
            -- three it used to keep.
            { every = 14, from = "back", maxAlive = 4,
              composition = function() return { "character_demon_imp", "character_demon_imp" } end },
        },
    },
}
