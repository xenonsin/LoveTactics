-- THE TOLL LEDGER: what Mora drops (data/characters/character_mora.lua; "Sloth's Bestiary", 2026-10-04, slice F,
-- approved word for word). A foe that uses an ability within 3 of you is Rooted on its next turn -- her Toll of Hours
-- (data/traits/trait_toll_of_hours.lua), a tile shorter and paid by foes only.
--
-- She pays it only if she falls: a company that paid its way through her gate (Passage Paid) leaves her standing and
-- this with her (models/toll.lua withholds her list). A MAMMONITE'S, the shelf that prices what a body does. An
-- unstocked trophy on the seat's rung.
return {
    name = "Toll Ledger",
    description = "A foe that uses an ability within 3 of you is Rooted on its next turn.",
    flavor = "Every hour anybody ever spent at her gate is in it, and none of them are crossed off.",
    sprite = "assets/items/utility_toll_ledger.png",
    type = "utility",
    tags = { "charm" },
    class = "mammonite",
    unlockLevel = 10,
    unstocked = true,
    traits = { "trait_toll_of_hours" },
    traitParams = { range = 3, foesOnly = true },
}
