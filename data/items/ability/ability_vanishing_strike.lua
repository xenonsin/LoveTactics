-- Vanishing Strike: the rogue half of the Ninja's Shadowclone. Strike, slip back a tile (fx.retreat),
-- and be gone -- Invisible until the user's next turn (data/status/invisible.lua). The knife that is
-- never where the answer lands: greed's blink fused with the mage's disappearing.
return {
    name = "Vanishing Strike",
    description = "Strikes a foe, slips back a tile, and turns you Invisible until your next turn.",
    flavor = "The wound is the only proof you were ever standing there.",
    sprite = "assets/items/ability_vanishing_strike.png",
    type = "ability",
    tags = { "pierce", "physical", "guile" },
    class = "rogue",
    discipline = "ninja", -- rogue x mage; the Shadowclone mechanic's first stock
    price = 300,
    repRank = 3,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 7 },
        damage = { 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.retreat(fx.user, 1) -- slip back out of reach
            fx.applyStatus(fx.user, "status_invisible")
        end,
    },
}
