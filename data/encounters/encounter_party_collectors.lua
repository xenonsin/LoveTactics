-- THE COLLECTORS: an adventuring party ("The Rift's Adventurers", approved 2026-10-09). Written in
-- classes; each body's race is rolled when the party is fielded (models/adventurers.lua).
--
-- The Thief steals off you; the Mammonite banks coin on every blow and spends it on damage, tempo
-- and his own survival. The Sentinel covers the mammonite while the purse fills. Deeper, a Rogue
-- steals too and a Bulwark pushes you away from the purse.
--
-- How you beat it: Kill the mammonite before he banks enough to spend, and kill the thief to stop
-- feeding him.
--
-- THE THIEF RUNS (the objective pass, 2026-10-21): he fights until he has lifted something off you, then
-- bolts for the far edge with it (`after = "stolen"`), and if he gets there the fight is over and he is
-- gone with what he carries -- a stolen piece sits in his grid (Combat.steal), so it goes with him. Run
-- him down or let it go. The thief is core, so he stands on every floor the party does.
local Adventurers = require("models.adventurers")

return Adventurers.party({
    id = "encounter_party_collectors",
    name = "The Collectors",
    core = { "mammonite", "thief", "sentinel" },
    grow = { "rogue", "bulwark", "warlord" },
    combo = "The Thief steals off you; the Mammonite banks coin on every blow and spends it on damage,"
        .. " tempo and his own survival. The Sentinel covers the mammonite while the purse fills. Deeper,"
        .. " a Rogue steals too and a Bulwark pushes you away from the purse.",
    counter = "Kill the mammonite before he banks enough to spend, and kill the thief to stop feeding him.",
    objective = { type = "killAll", enemy = "the collectors",
                  escape = { who = "character_adv_thief", region = "far", after = "stolen" } },
})
