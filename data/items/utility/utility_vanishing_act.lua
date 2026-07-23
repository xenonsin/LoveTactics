-- The Guttering Lamp: an Undercroft lamp wicked to go out at the worst possible moment for whoever is
-- swinging. It carries Vanishing Act (data/traits/trait_vanishing_act.lua) -- Final Fantasy Tactics'
-- Sunken State, the reaction that hid its bearer the instant it was struck.
--
-- Where the rest of the rogue's utility rack buys OPENINGS -- the Opportunist's Charm, the Executioner's
-- Eye, the boots that get you there -- this one buys the turn after the opening closes. The shelf had
-- three utilities and every one of them assumed the rogue was winning; this is the one that assumes it
-- guessed wrong, which is a thing a rogue does roughly as often.
--
-- It is guile rather than armor, and the distinction is the point: it adds no defense whatsoever. A hit
-- that lands still lands in full. What it takes off the table is the SECOND hit, which is the one that
-- actually kills something with a rogue's health pool. Read against the shelf's own vocabulary
-- (docs/classes.md: "conditional multipliers, return-to-origin blinks, and taking what is not yours"),
-- this is a blink the enemy pays for.
--
-- Rank 2 and cheap. It is a survival floor rather than a build piece, and pricing it as a luxury would
-- mean the rogue only gets to stop dying once it is already winning.
return {
    name = "Guttering Lamp",
    description = "Struck and still standing, the bearer slips out of sight until its next turn.",
    flavor = "The Undercroft's first lesson is that the dark is a tool. The second is where to stand in it.",
    sprite = "assets/items/vanishing_act.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    price = 260,
    repRank = 2,
    traits = { "trait_vanishing_act" },
    -- Movement, not defense: the lamp does not make you harder to hurt, it makes you harder to find,
    -- and a step further from where you were seen last is the same idea in a different currency.
    bonus = { movement = { 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 1 } },
}
