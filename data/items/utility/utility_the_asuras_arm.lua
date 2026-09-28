-- THE ASURA'S ARM: one of Furor's, for a company monk (Descent.DROPS). One more landing on every bare-handed
-- blow -- the field Swift Fist raises (unarmedBonus.hits), so the two stack, and so does everything that pays
-- per landing: Iron Fist's damage, Flurry's three strikes, and the chi each landing banks.
-- A monk trophy: unstocked, seen on the Cathedral's rack and never sold.
return {
    name = "The Asura's Arm",
    description = "Bare-handed strikes land once more. Stacks with Swift Fist.",
    flavor = "It still makes a fist when nobody is looking.",
    sprite = "assets/items/utility_the_asuras_arm.png",
    type = "utility",
    tags = { "fist" },
    class = "monk",
    unstocked = true,
    unlockLevel = 8,
    unarmedBonus = { hits = 1 },
}
