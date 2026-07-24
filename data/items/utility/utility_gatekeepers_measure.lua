-- Saber's bout relic: the three-stage shape of the debut fight, carried on the boss twin
-- (data/characters/character_saber_bout.lua) and NOWHERE else -- the recruited Saber
-- (data/characters/character_saber.lua) never holds it, so none of what follows rides home when she
-- joins the party. That separation is the whole reason the twin exists.
--
-- It is the exact pattern of the Demon Champion's Ascendant Sigil (data/items/utility/utility_demon_sigil.lua):
-- a bound centre-cell relic carrying trait_boss_phases, whose `phases` table below is this boss's own
-- script. No new Lua -- the trait reads the stages off the relic.
--
-- WHAT THE STAGES MEAN. Saber is the gatekeeper, and she is delighted to finally be pressed
-- (data/conversations/prologue_victory.lua). The fight is her taking a newcomer progressively more
-- seriously, not a health bar with tricks bolted on:
--   66%  She calls in another hand from the house. Everything on this sand is a team, and she stops
--        fighting as if the one at her side were enough. The summoned body is a netter
--        (data/characters/character_arena_hand.lua), so the escalation is MORE PINS for her greatsword,
--        which is the exact threat the opening already taught -- turned up, not turned into something new.
--        It arrives as a phase response rather than a third body in the opening line, so the bout opens a
--        fair two-on-two and the extra pressure cannot be skipped by bursting her past the threshold
--        (trait_boss_phases fires only on a survived blow -- the honest reading its header documents).
--   33%  She stops holding the edge for the perfect moment and simply commits: fast (status_hasted) and
--        hitting harder (a flat damage bump). Patience was the discipline of picking the moment; past
--        this she has decided every moment is the moment. A player who has been walking out of her
--        wind-ups now has half the time to do it.
--
-- `bound = true` (models/item.lua): unstealable, so a rogue cannot lift her whole fight off her in one
-- grab. No `class`/`price`: not gear anyone shops for.
return {
    name = "The Gatekeeper's Measure",
    description = "Its bearer answers each wound with the next stage of the fight.",
    flavor = "She has watched this sand eat better fighters than you. Show her something, and she " ..
        "stops watching.",
    sprite = "assets/items/sig_unappeased_heart.png", -- placeholder until its own art exists
    type = "utility", -- `bound` (not the type) is what locks it in the center cell
    tags = { "signature", "relic" },
    bound = true,
    traits = { "trait_boss_phases" },
    phases = {
        -- 66%: call in another hand. A netter, so the escalation is more of the pin-then-commit threat
        -- the opening already posed. Summoned onto an open tile beside her (trait_boss_phases' summon).
        { at = 0.66, responses = {
            { kind = "summon", id = "character_arena_hand", count = 1 },
            { kind = "log", text = "Saber whistles through her teeth, and another of the house's hands steps onto the sand." },
        } },
        -- 33%: she stops toying. Fast, and a flat bump to the swing -- committed rather than patient.
        { at = 0.33, responses = {
            { kind = "status", id = "status_hasted" },
            { kind = "bonus",  stat = "damage", amount = 6 },
            { kind = "log", text = "Saber sets her feet and stops waiting for the opening. She is going to make one." },
        } },
    },
}
