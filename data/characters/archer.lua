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
    -- Innate: raised beside a wolf, she fields it free at the opening bell (data/traits/wolf_companion.lua).
    traits = { "wolf_companion" },
    -- Weapon + armor for combat, plus the trap kit (spike-trap ability + trap detector)
    -- that makes the archer the party's trapper. Rain of Arrows only fires with a bow sitting
    -- adjacent to it in the grid -- arrange the loadout to enable it (see ability_rain_of_arrows.lua).
    -- Summon Wolf reserves a quarter of the archer's (deliberately small) mana pool for as long as
    -- the wolf lives, so fielding it costs a Spike Trap's worth of headroom for the whole battle.
    startingItems = { "bow", "leather_armor", "ability_spike_trap", "trap_sense", "healing_potion", "torch", "buckler", "ability_rain_of_arrows", "ability_summon_wolf" }, -- item ids
}
