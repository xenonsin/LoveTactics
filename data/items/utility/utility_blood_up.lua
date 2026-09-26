-- BLOOD UP: the orc Berserker's organ (approved as pitched, 2026-09-26, "The Orcs of Wrath"). Each turn in a row
-- it lands a hit, +3 Damage; once struck it must strike every turn, and with no foe in reach it hits the nearest
-- body; a turn without a hit leaves it Spent (trait_blood_up, models/rampage.lua). The streak without the
-- compulsion is what it drops: the Unbroken Axe and Warpaint.
return {
    name = "Blood Up",
    description = "Each turn in a row you hit, increase damage by 3. You must strike every turn, and a turn without a hit leaves you Spent.",
    flavor = "It does not decide to keep going. Stopping is the thing it would have to decide.",
    sprite = "assets/items/utility_blood_up.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_blood_up" },
}
