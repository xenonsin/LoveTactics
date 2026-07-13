-- Swift Fist: two blows in the time of one. A passive "fist" charm that grants the bearer's
-- bare-handed strike an extra hit (`unarmedBonus.hits`, counted in the unarmed effect in
-- data/items/weapon/unarmed.lua) -- the fist lands twice per strike. Only the fist is doubled, never a
-- crafted weapon. Stack it with Iron/Drunken Fist and each of the two hits carries the added Power.
return {
    name = "Swift Fist",
    description = "Your bare-handed strike lands twice. Does nothing for a weapon.",
    sprite = "assets/items/swift_fist.png",
    type = "utility",
    tags = { "fist" },
    class = "priest",
    price = 300,
    repRank = 3,
    unarmedBonus = { hits = 1 },
}
