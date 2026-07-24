-- Saber's bout relic: the closing shape of the debut fight, carried on the boss twin
-- (data/characters/character_saber_bout.lua) and NOWHERE else -- the recruited Saber
-- (data/characters/character_saber.lua) never holds it, so none of what follows rides home when she
-- joins the party. That separation is the whole reason the twin exists.
--
-- It is the exact pattern of the Demon Champion's Ascendant Sigil (data/items/utility/utility_demon_sigil.lua):
-- a bound centre-cell relic carrying trait_boss_phases, whose `phases` table below is this boss's own
-- script. No new Lua -- the trait reads the stages off the relic.
--
-- WHAT THE STAGE MEANS. Saber is the gatekeeper, and she is delighted to finally be pressed
-- (data/conversations/prologue_victory.lua). The bout opens with her whole team already on the sand --
-- two Trappers off her shoulders (data/quests/arena_debut.lua), no reinforcement held back -- so the
-- one remaining stage is about HER, not the size of the crowd:
--   33%  She stops holding the edge for the perfect moment and simply commits: fast (status_hasted) and
--        hitting harder (a flat damage bump). Patience was the discipline of picking the moment; past
--        this she has decided every moment is the moment. Because Haste runs a wind-up shorter without
--        softening it (data/status/status_hasted.lua), a player who has been walking out of her deep
--        holds now has HALF the tell to do it in -- and the blow at the end is no smaller. It cannot be
--        skipped by bursting her past the threshold -- trait_boss_phases fires only on a survived blow
--        (the honest reading its header documents).
--
-- `bound = true` (models/item.lua): unstealable, so a rogue cannot lift her whole fight off her in one
-- grab. No `class`/`price`: not gear anyone shops for.
return {
    name = "The Gatekeeper's Measure",
    description = "Its bearer answers a deep enough wound by committing to the fight.",
    flavor = "She has watched this sand eat better fighters than you. Show her something, and she " ..
        "stops watching.",
    sprite = "assets/items/sig_unappeased_heart.png", -- placeholder until its own art exists
    type = "utility", -- `bound` (not the type) is what locks it in the center cell
    tags = { "signature", "relic" },
    bound = true,
    traits = { "trait_boss_phases" },
    phases = {
        -- 33%: she stops toying. Fast, and a flat bump to the swing -- committed rather than patient. The
        -- crowd is already all here (both trappers opened with her), so the escalation is entirely in how
        -- she herself fights, not in another body called onto the sand.
        { at = 0.33, responses = {
            { kind = "status", id = "status_hasted" },
            { kind = "bonus",  stat = "damage", amount = 6 },
            { kind = "log", text = "Saber sets her feet and stops waiting for the opening. She is going to make one." },
        } },
    },
}
