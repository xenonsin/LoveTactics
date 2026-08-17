-- THE UNKEPT WATCH: Acedia's rule, cut down, and the Sloth mini sin's whole reason to exist.
--
-- Acedia's Forsworn Pike swears the WHOLE enemy party into pairs at the opening bell, and every body
-- that ends its turn away from its partner is bitten (data/traits/trait_unrelieved.lua). It is a
-- standing tax on moving independently, applied to everyone before anybody has taken a turn -- and met
-- cold it reads as the board being broken rather than as a rule.
--
-- So the honour-guard floor swears ONE pair, when it acts, and then at half health starts bracing its
-- own line the way her Oathkeeper Shield does:
--
--   from the bell   Torpor: one pair sworn, on its own turn (data/traits/trait_torpor.lua)
--   at 50%          it braces -- armour on itself and the line, which is Acedia's other half
--
-- THAT IS THE RULE FOR THE WHOLE TIER: a mini sin's second phase is its general's first.
--
-- A relief that came too late to be a relief: named for the office rather than for the mechanic, which
-- is how the whole tier is named.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "Unkept Watch",
    description = "Swears two foes together as it acts, and braces once it is wounded.",
    flavor = "The relief never came. It has decided this is the same as not needing one.",
    sprite = "assets/items/unkept_watch.png",
    type = "utility",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_torpor", "trait_boss_phases" },
    phases = {
        { at = 0.5, responses = {
            { kind = "bonus", stat = "defense", amount = 6 },
            { kind = "bonus", stat = "magicDefense", amount = 6 },
            { kind = "status", id = "status_defending", opts = { duration = 999 } },
            { kind = "log", text = "The Late Watch settles, and stops intending to move at all." },
        } },
    },
}
