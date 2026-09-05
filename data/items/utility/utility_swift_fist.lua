-- Swift Fist: two blows in the time of one. A passive "fist" charm that grants the bearer's
-- bare-handed strike an extra hit (`unarmedBonus.hits`, counted in the unarmed effect in
-- data/items/weapon/weapon_unarmed.lua) -- the fist lands twice per strike. Only the fist is doubled, never a
-- crafted weapon. Stack it with Iron/Drunken Fist and each of the two hits carries the added Power.

return {
    name = "Swift Fist",
    description = "Bare-handed strikes land twice. Does nothing for a weapon.",
    flavor = "Two blows in the time of one, which the monks insist is only practice.",
    sprite = "assets/items/swift_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "monk", -- deeper cut of the shelf: buyable only once the monk gate is cleared
    unlockQuests = 2,
    dropTier = 1,
    unarmedBonus = { hits = { 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2 } },
    -- two punches in the time of one, and no Power a weapon could borrow
    bonus = { speed = 2 },
}
