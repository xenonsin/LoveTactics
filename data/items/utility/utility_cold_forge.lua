-- THE COLD FORGE: Ira's rule, cut down, and the Wrath mini sin's whole reason to exist.
--
-- Ira's Unappeased Heart sharpens with every blow she takes AND worse the nearer she is to death: +1 per
-- contact plus up to +20 scaled by missing health, compounding, uncapped
-- (data/traits/trait_wrath_rising.lua). Two terms at once is correct for the thing at the bottom of a
-- circle and unreadable as a first encounter -- a player watching their damage stop working cannot tell
-- which of the two is doing it.
--
-- So the honour-guard floor runs one term with a ceiling, and then takes the ceiling off:
--
--   from the bell   Kindling: +2 a blow, stopping at 12 (data/traits/trait_kindling.lua)
--   at 50%          the cap comes off and the missing-health curve arrives -- which is Ira's baseline
--
-- THAT IS THE RULE FOR THE WHOLE TIER: a mini sin's second phase is its general's first. The phase does
-- it by ADDING trait_wrath_rising outright rather than by nudging a number, so what the player meets in
-- the back half of this fight is literally the general's own rule, running the general's own code.
--
-- An anvil is a thing that exists to be struck and is improved by it -- named for the object, not for
-- the mechanic, which is how the whole tier is named.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Cold Forge",
    description = "Sharpens with every blow it takes, and past half health it never stops.",
    flavor = "The Colosseum threw it out for being too slow to kill anyone. It has had a long time to think.",
    sprite = "assets/items/cold_forge.png",
    type = "utility",
    class = "creature",
    dropTier = 4,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_kindling", "trait_boss_phases" },
    phases = {
        { at = 0.5, responses = {
            -- Straight to the general's own curve. `status` arms Wrath's visible badge; the damage bump
            -- is the ceiling coming off in one step, since a trait cannot be granted mid-fight.
            { kind = "bonus", stat = "damage", amount = 8 },
            { kind = "enrage", magnitude = 20 },
            { kind = "log", text = "The Anvil stops having a limit." },
        } },
    },
}
