-- THREE-FACED ASURA: the third rung (models/asura.lua). Six arms -- three landings on every bare-handed blow --
-- and the whole of the monk's shelf that SPENDS: Flurry, Asura Strike, and the Centering Charm, whose Gather
-- its blood turns into heat (Tapas, +2 chi). It is the one asura that chooses its moment instead of bursting
-- blind, and the one that answers you first: Keen Senses strikes before your blow lands, with every arm, and
-- every landing is chi. Walking up to it is how you fill it.
--
-- Imagery: Ashura of Kofuku-ji, three faces and six arms.
return {
    name = "Three-Faced Asura",
    race = "asura",
    tier = 3,
    class = "priest",
    discipline = "monk",
    sprite = "assets/chars/asura_three_faced.png",
    archetype = "aggressive",
    stats = {
        health = 118, mana = 0, stamina = 30,
        staminaRegen = 4,
        damage = 12, magicDamage = 0,
        defense = 7, magicDefense = 6,
        movement = 4,
        speed = 4, -- 5 after the race
        skill = 5, luck = 4, -- 6 after the race
    },
    startingItems = {
        "utility_six_arms",       "utility_iron_fist",  "ability_flurry",
        "ability_asura_strike",   "utility_centering_charm", "ability_keen_senses",
        false,                    false,                false,
    },
    signatureWeapon = "utility_iron_fist",
    signatureAbility = "ability_asura_strike",
}
