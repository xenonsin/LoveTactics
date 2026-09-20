-- THE OPEN DOOR: whatever is down here can find the bearer.
--
-- An opening boon pointed the wrong way (`openingBoon`, drained onto the bearer by states/battle.lua at
-- the bell), granting Vulnerable: Dark for the fight. The Hungry Edge already opens a body bleeding; this
-- opens one EXPOSED, which is a different kind of problem -- bleed is a clock the party can cleanse, and
-- a vulnerability is a multiplier on whatever the floor happens to be swinging.
--
-- CONDITIONAL ON THE GROUND, WHICH IS THE POINT. Dark is the rift's own element -- the Unseeing's clan,
-- the worms, the things that leave curses where they die -- so this is near-harmless on the tundra and a
-- serious problem in exactly the places curses come from. It is the one hex a player reads the CIRCLE
-- against, and the one worth carrying down one floor and leaving behind on the next.
--
-- DOES NOT BIND, because a hex whose severity depends on where you are going has to be a thing you can
-- act on before you go. Shelving it for one descent is the play, and having to remember to is the cost.
return {
    name = "The Open Door",
    description = "The bearer opens every fight Vulnerable to dark.",
    depth = 9,
    fee = 260,
    openingBoon = { id = "status_vulnerable_dark" },
}
