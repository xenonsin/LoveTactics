-- The Crucible Golem's innate, and the reason it is a golem rather than a large homunculus: the first
-- blow each turn aimed at an ally standing beside it is taken by the golem instead. Final Fantasy
-- Tactics' Golem summon did exactly this for the whole party; here it does it for whoever is willing
-- to stand next to a two-ton clay statue, which is the positional cost that makes it interesting.
--
-- It sets `unit.guard` and nothing else -- the interception, its cooldown and its logging all live in
-- the damage core (Combat.tryRedirect), exactly as the knight's own Oathward does
-- (data/traits/trait_oathward.lua, whose comment notes that any relic granting this guards the same
-- way). Reusing `kind = "oathward"` rather than inventing a golem-shaped guard is deliberate: the
-- mechanic is identical, and a second `kind` in that switch would be two names for one behaviour.
--
-- ONE DEVIATION FROM FFT, recorded rather than engineered around: the original Golem absorbed PHYSICAL
-- damage only, and Combat.tryRedirect does not filter by school, so this one steps in front of spells
-- too. Filtering would mean a new guard kind and a new branch in the damage core for a distinction the
-- rest of the game does not draw at that seam. The golem is a wall against everything and is priced
-- as one; if the school filter ever matters, that is where it goes.
--
-- Its cooldown is longer than a knight's (6). The golem is slower than a person in every other respect
-- and it is slower at this too -- it is a statue that has to be walked into position, and a party that
-- wants a blow eaten every single turn should be paying a knight for it.
return {
    name = "Bulwark",
    description = "The first hit each turn on an adjacent ally is taken by the golem instead.",
    onCombatStart = function(ctx)
        ctx.unit.guard = { kind = "oathward", cooldown = 9 }
    end,
}
