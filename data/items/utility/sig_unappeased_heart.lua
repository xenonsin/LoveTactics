-- Ira's heart, still beating for a fight that is over. It carries the general of Wrath's one rule
-- (data/traits/wrath_rising.lua): every blow she survives is added to her next one. The rule now
-- rides on this relic, reaching her through her grid the same way a hero's signature does. (Distinct
-- from data/items/armor/mail_of_the_unappeased.lua, the mail YOU lift off her body, which carries the
-- same trait id for the player -- one rule, two relics.)
--
-- `bound = true` (models/item.lua): it can never be stolen off her. A rogue that could pickpocket the
-- heart would end her fight in one lift -- bound forbids it. Her blueprint places it in her grid's center.
--
-- No `class`/`price`: not gear anyone shops for. The damage curve is flavor -- the player never forges
-- an enemy's relic -- so only its base value is ever seen.
return {
    name = "The Unappeased Heart",
    description = "Every wound she walks away from is added to her next blow.",
    sprite = "assets/items/sig_unappeased_heart.png",
    type = "utility", -- `bound` (not the type) is what locks it in place
    tags = { "signature", "relic" },
    bound = true,
    traits = { "wrath_rising" },
    bonus = { damage = { 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7 } }, -- levels 0..10 (only base is ever used)
}
