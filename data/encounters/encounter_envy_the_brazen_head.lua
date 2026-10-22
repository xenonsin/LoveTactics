-- THE BRAZEN HEAD: Envy's seat elite of slice C ("Envy's Bestiary", 2026-10-03; data/characters/
-- character_brazen_head.lua). The head speaks three times behind its guards, and the fight is the gaps between the
-- utterances: shove it to break each wind-up, and burst the guards before Time Was heals them back.
--
-- THE GUARD: the page put a Mirror-Knight in front of it (character_mirror_knight, the Faceless line's), and the
-- two Homunculi beside it. The knight's mirror is up at the top of each of its turns, so the first single blow
-- aimed past it comes back -- which is what makes the shove that breaks each word worth planning.
--
-- Seat-locked, `rung = 2`.
--
-- THE OBJECTIVE (the objective pass, 2026-10-21): destroy the head. This was an explicit killAll and the pass
-- reverses it: the fight is the head's three utterances, so it ends when the head does and the guard leaves.
return {
    name = "The Brazen Head",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 2,
    composition = function()
        return { "character_brazen_head", "character_mirror_knight", "character_red_homunculus",
            "character_red_homunculus" }
    end,
    objective = { type = "assassinate", target = "character_brazen_head", verb = "Destroy", enemy = "the Brazen Head" },
}
