-- The Wolfsong Spirit: the great wolf that answers the Wolfsong Horn's true call, not the everyday
-- companion but the beast behind it -- called only at a blood-price (the summoner pays half their
-- current health for it, see data/items/utility/sig_wolfsong_horn.lua). Bigger, faster and fiercer
-- than any wolf of the pack (compare data/characters/wolf_alpha.lua), it is a conjured body: no mana
-- of its own, a natural bite for a weapon, and it stands only as long as the archer sustaining it does.
-- Scaled by the horn's forged level like any summon. See data/characters/fire_elemental.lua for the
-- conjured-creature blueprint shape.
return {
    name = "Wolfsong Spirit",
    sprite = "assets/chars/wolfsong_spirit.png",
    stats = {
        health = 90, mana = 0, stamina = 80,
        damage = 22, magicDamage = 0,
        defense = 7, magicDefense = 6,
        movement = 6, -- fastest thing on four legs
        speed = 6,
    },
    startingItems = { "fangs", "feral_instinct" },
}
