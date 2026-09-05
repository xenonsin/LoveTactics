-- The Hoard's own pile, and the phase script that spends it.
--
-- Every threshold sheds a pair of coin-chitters -- which is what a disturbed hoard DOES: pieces of it
-- run for the dark carrying as much as they can hold (data/items/weapon/weapon_cutpurse_nip.lua). So the
-- longer you spend opening it, the less of it there is to take, and the fight has a clock made of its
-- own reward.
--
-- Which is the sharpest reading of Greed available: the pile is worth more the faster you get through
-- it, and being careful costs you the thing you were being careful about.
--
-- Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
return {
    name = "The Hoard",
    description = "Sheds a pair of coin-chitters as it is wounded.",
    flavor = "It is not guarding anything. It simply is the pile, and the pile has learned to object.",
    sprite = "assets/items/the_hoard.png",
    type = "utility",
    class = "creature",
    dropTier = 2,
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_boss_phases" },
    phases = {
        { at = 0.66, responses = {
            { kind = "summon", id = "character_coin_chitter", count = 2 },
            { kind = "log", text = "Part of the pile gets up and leaves with as much as it can carry." },
        } },
        { at = 0.33, responses = {
            { kind = "summon", id = "character_coin_chitter", count = 2 },
            { kind = "log", text = "More of it goes. There is less here than there was." },
        } },
    },
}
