-- SNARE LINE: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Trapper lays traps on the approach before you get there. The Bulwark pushes you onto them.
-- The Hunter shoots what's caught. From floor 8 a Poacher hits Rooted bodies far harder, and from
-- floor 10 an Artificer's turrets cover the trapped lane.
--
-- How you beat it: Walk the board slowly and read the traps, or kill the bulwark first so nothing
-- pushes you into them.
--
-- CROSS THE SNARE LINE (the objective pass, 2026-10-21): anyone at the far edge wins, through the traps they
-- laid for exactly that walk. No tide (`waves = {}`): the default would re-field the party's own members off
-- the top of its roster, and a party is the people standing there.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_snare",
    name = "Snare Line",
    core = { "trapper", "bulwark", "hunter" },
    grow = { "poacher", "artificer", "barbarian" },
    combo = "The Trapper lays traps on the approach before you get there. The Bulwark pushes you onto"
        .. " them. The Hunter shoots what's caught. From floor 8 a Poacher hits Rooted bodies far harder,"
        .. " and from floor 10 an Artificer's turrets cover the trapped lane.",
    counter = "Walk the board slowly and read the traps, or kill the bulwark first so nothing pushes you"
        .. " into them.",
    objective = { type = "reach", region = "far", place = "across the snare line", enemy = "the trappers",
                  waves = {} },
})
