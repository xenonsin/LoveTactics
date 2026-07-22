-- A conjured creature, reached only through the alchemist's Summon Homunculus ability
-- (data/items/ability/ability_summon_homunculus.lua), which scales it by the item's upgrade level. A
-- frail, shambling construct of alchemical clay -- little health and a soft touch -- whose worth is
-- not the hit but the Poison its Homunculus Fists leave behind, ticking on long after it falls. A
-- body to soak a turn and rot a foe, not to win a duel. See data/characters/water_elemental.lua for
-- the blueprint shape.
return {
    name = "Homunculus",
    sprite = "assets/chars/homunculus.png",
    stats = {
        health = 18, mana = 0, stamina = 12,
        staminaRegen = 2,
        damage = 5, magicDamage = 0,
        defense = 2, magicDefense = 3,
        movement = 4,
        speed = 5,
    },
    startingItems = { "weapon_homunculus_fists" },
    -- Basic tactics (models/ai.lua): a body to rot a foe -- press the one closest to falling so the
    -- Poison finishes what the claws start.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
