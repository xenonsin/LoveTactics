return {
    name = "Archer",
    sprite = "assets/chars/archer.png",
    stats = {
        health = 75, mana = 15, stamina = 90, -- resource stats
        staminaRegen = 2, -- stamina recovered per elapsed tick (a flat stat, not a resource)
        damage = 16, magicDamage = 3,          -- flat stats
        defense = 7, magicDefense = 5,
        movement = 4, -- number of spaces this character can move
        speed = 5,    -- nimble
    },
    -- Weapon + armor for combat, plus the trap kit (spike-trap ability + trap detector)
    -- that makes the archer the party's trapper. Rain of Arrows only fires with a bow sitting
    -- adjacent to it in the grid -- arrange the loadout to enable it (see ability_rain_of_arrows.lua).
    startingItems = { "bow", "leather_armor", "ability_spike_trap", "trap_sense", "healing_potion", "torch", "buckler", "ability_rain_of_arrows" }, -- item ids
}
