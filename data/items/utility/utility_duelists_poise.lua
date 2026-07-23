-- Duelist's Poise: the rogue half of the Duelist (fighter x rogue), and a PASSIVE -- a reflex attaches
-- to a grid charm, never an active cast (docs/classes.md). While the bearer faces exactly one adjacent
-- foe -- a true one-on-one -- every blow bites deeper (trait_duelists_poise, read through the
-- damageBonusVs hook so the number rides the hover preview). Gang up on the Duelist and the edge is
-- gone; catch someone alone and it is a beheading. An indicator lives on the trait's active/inactive tell.
--
-- NAMED "Poise" rather than "Edge" on purpose: data/items/weapon/weapon_duelists_edge.lua already holds
-- that name (a knight's binding blade), so this is the rogue's poise to that blade's edge.
return {
    name = "Duelist's Poise",
    description = "While exactly one foe stands adjacent to you, your blows deal extra damage.",
    flavor = "Two of them is a brawl. One of them is a lesson.",
    sprite = "assets/items/utility_duelists_poise.png",
    type = "utility",
    tags = { "charm" },
    class = "rogue",
    discipline = "duelist", -- fighter x rogue; the Duel-stance mechanic's first stock
    price = 400,
    repRank = 3,
    traits = { "trait_duelists_poise" },
}
