-- THE HEAVE: an Ogre, a Troll Scarlord and two Trolls, on Sloth's seat (approved 2026-10-04, "Sloth's Bestiary",
-- slice B). The lesson: the trolls are the ogre's ammunition, and they regrow from being thrown -- so every troll
-- that walks up beside the Ogre comes down beside your healer.
--
-- PINNED, NOT ROLLED (tests/encounter_spec.lua): the review's cast is exactly this. Two trolls are the ogre's two
-- throws before the company reaches it; one would be a lesson it might never get to teach.
return {
    name = "The Heave",
    kind = "combat",
    weight = 3,
    condition = function(ctx) return ctx.biome == "tundra" end,
    rung = 2,
    composition = function()
        return { "character_sloth_ogre", "character_troll_scarlord", "character_troll", "character_troll" }
    end,
}
