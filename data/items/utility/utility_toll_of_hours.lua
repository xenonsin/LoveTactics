-- TOLL OF HOURS: Mora's organ (data/characters/character_mora.lua; models/toll.lua). Her two rules:
--   Toll of Hours  every ability used within 4 of her costs its user its next move: Rooted on its next turn
--   Passage Paid   a body that spends a whole turn doing nothing on a gate tile passes through and leaves the board
-- She Never Strikes is not on here: it is the absence of a weapon (`unarmed = false` on her blueprint).
-- Creature kit: bound, unstealable, on no shelf.
return {
    name = "Toll of Hours",
    description = "An ability used within 4 of her Roots its user on its next turn. A foe idle a turn beside her passes.",
    flavor = "The gate is open. It has always been open. It is only a question of what you will spend standing in it.",
    sprite = "assets/items/utility_toll_of_hours.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_toll_of_hours", "trait_passage_paid" },
    traitParams = { range = 4 },
}
