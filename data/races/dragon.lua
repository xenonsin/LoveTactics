-- Dragon: what the kobolds worship -- the Wyrmling that hatches and the Godling it grows into (reviewed
-- 2026-09-25, "The Kobolds of Greed": "Add a dragon race instead of using beast", approved).
--
-- A RACE SO "WHAT IS A DRAGON" IS ONE TABLE. Fielded as `beast` the Godling would have worn the forest's
-- fur-and-hide reading; as its own race it answers for itself, and every dragon carries the same rule the
-- kobolds' whole faith hangs on (utility_dragonblood: the `dragonkin` flag). Kind `beast`, because the
-- item rules split on seven kinds and a dragon is a creature to all of them.
--
-- FIRE, AND THE HIDE ON THE BODY. The race holds only what every dragon is -- fire runs off it. The
-- physical three (a hide that turns a blade and a club and lets a point through the bare patch) are on
-- each blueprint, because the bestiary holds every armourless body to declaring its own (tests/
-- bestiary_spec.lua reads the blueprint), and a hide two blueprints state is one they can tune apart.
--
-- NOT PLAYABLE. A dragon is what a kobold has, not what a company hires; the Dragon Egg a player hatches
-- (ability_dragon_egg) is a summon, and the race is never on the roster.
return {
    name = "Dragon",
    description = "A young wyrm of the deep caves. Fire runs off it, and kobolds would die for it.",
    kind = "beast",
    playable = false,
    resist = {
        fire = 2, -- the one thing every dragon is
    },
    grants = { "utility_dragonblood" },
}
