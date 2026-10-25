-- THORNED: melee attackers take a share of their own blow back. The spiked mail's rule
-- (data/traits/trait_thorns.lua), lent whole, so the hover preview warns of it the same way.
return {
    name = "Thorned",
    description = "Melee attackers take 40% of the damage they deal back.",
    mark = "T",
    color = { 0.55, 0.75, 0.35 },
    traits = { "trait_thorns" },
}
