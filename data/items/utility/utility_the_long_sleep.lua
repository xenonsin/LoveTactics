-- THE LONG SLEEP: Desidia's relic, the first thing her fall pays (Descent.DROPS). "Kill a sin, wear it": a knight who
-- holds still banks the turns she did not take, up to 3, and the first blow that lands on her takes them all at once
-- (trait_the_long_sleep).
--
-- A GENERAL'S RELIC, and a KNIGHT'S TROPHY, on Sloth's house shelf (the Bastion; tests/sin_drops_spec.lua): a real
-- class, `unstocked`, no price, nothing takes it off you -- shown on the rack, refused as a monster drop.
-- `unlockLevel` is Sloth's seat, floor ten. A knight because the knight is the one who stands where she is put and
-- waits for the blow; this makes the waiting the weapon.
return {
    name = "The Long Sleep",
    description = "Each round you use nothing banks a turn, up to 3. When you are struck, take every banked turn at once.",
    flavor = "She was not idle. She was saving it all for you.",
    sprite = "assets/items/utility_the_long_sleep.png",
    type = "utility",
    tags = { "relic" },
    class = "knight",
    unlockLevel = 10,
    unstocked = true,
    noSteal = true, -- nothing takes this off you; you took it off the thing that slept in it
    traits = { "trait_the_long_sleep" },
}
