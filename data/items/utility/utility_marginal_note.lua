-- MARGINALIA'S NOTE: Sublimitas's rule, cut down, and the Pride mini sin's whole reason to exist.
--
-- Her Codex Unanswered deflects a single-target spell aimed at her ENTIRELY, for mana, on a ten-tick
-- cooldown (data/traits/trait_counter_magic.lua). A caster-heavy party meets that and finds its whole
-- plan refused, repeatedly, with nothing on screen explaining why.
--
-- So the honour-guard floor deflects the FIRST spell and no others, and then at half health closes its
-- rank instead:
--
--   from the bell   Answered Once: one spell unravelled, ever (data/traits/trait_answered_once.lua)
--   at 50%          it calls the rank in, which is the other thing a Pride body does
--
-- THAT IS THE RULE FOR THE WHOLE TIER: a mini sin's second phase is its general's first.
--
-- Marginalia is the lesser writing beside the real text, in somebody else's hand -- named for the object
-- rather than for the mechanic, which is how the whole tier is named.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Marginal Note",
    description = "Unravels the first spell aimed at it, and calls in its rank once wounded.",
    flavor = "Somebody argued with the Codex in its own margins, at length, and was eventually answered.",
    sprite = "assets/items/marginal_note.png",
    type = "utility",
    class = "creature",
    dropTier = 3,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_answered_once", "trait_close_ranks", "trait_boss_phases" },
    phases = {
        { at = 0.5, responses = {
            { kind = "summon", id = "character_gilded_page", count = 2 },
            { kind = "log", text = "Marginalia calls, and the room answers with more of itself." },
        } },
    },
}
