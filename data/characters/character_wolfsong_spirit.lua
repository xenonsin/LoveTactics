-- SHELVED (unused): the Wolfsong Horn's true call was retired for the Quieting Howl
-- (data/items/utility/utility_wolfsong_horn.lua), so nothing currently summons this blueprint. Kept for
-- later reuse.
--
-- The Wolfsong Spirit: the great wolf that answers the Wolfsong Horn's true call, not the everyday
-- companion but the beast behind it (see data/items/utility/utility_wolfsong_horn.lua). It is called for
-- nothing and paid for when it dies -- but that price is the horn's bargain, bound to the beast by the
-- call itself (`traits` in models/summon.lua), not written here: this blueprint is just the body, and
-- another ability could raise it owing nothing. Bigger, faster and fiercer
-- than any wolf of the pack (compare data/characters/wolf_alpha.lua), it is a conjured body: no mana
-- of its own, a natural bite for a weapon, and it stands only as long as the archer sustaining it does.
-- Scaled by the horn's forged level like any summon. See data/characters/fire_elemental.lua for the
-- conjured-creature blueprint shape.
return {
    name = "Wolfsong Spirit",
    sprite = "assets/chars/wolfsong_spirit.png",
    stats = {
        health = 62, mana = 0, stamina = 80,
        damage = 22, magicDamage = 0,
        defense = 7, magicDefense = 6,
        movement = 6, -- fastest thing on four legs
        speed = 6,
    },
    startingItems = { "weapon_wolf_fangs", "utility_feral_instinct" },
    -- Basic tactics (models/ai.lua): the great wolf runs down the wounded -- press the foe closest to falling.
    ai = {
        { priority = "high", act = "attack", targetPref = "lowest_hp",
          when = { subject = "foe_lowest_hp", test = "hp_pct_below", value = 0.5 } },
    },
}
