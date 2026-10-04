-- NIGHTMARE LANTERN: What the Sleepers Dream, lifted off Desidia for a necromancer ("Sloth's Bestiary", slice G,
-- approved word for word). While a foe sleeps, a shade of it fights for you; it is gone when the foe wakes.
--
-- The same trait her organ carries (trait_what_the_sleepers_dream): at the start of each of the bearer's turns,
-- every sleeping foe without a shade dreams one up beside the bearer -- its face, its kit, its wounds -- and the
-- shade goes the beat its sleeper wakes. A Necromancer's, because raising a body that is not quite the body is the
-- whole of that shelf; this one does not even need it dead.
--
-- An unstocked trophy on the seat's rung (floor 10), noSteal like every stair piece.
return {
    name = "Nightmare Lantern",
    description = "While a foe sleeps, a shade of it fights for you. It is gone when the foe wakes.",
    flavor = "It does not give much light. It gives the dark something to do.",
    sprite = "assets/items/utility_nightmare_lantern.png",
    type = "utility",
    tags = { "charm", "dark" },
    class = "necromancer",
    unlockLevel = 10,
    unstocked = true,
    noSteal = true,
    traits = { "trait_what_the_sleepers_dream" },
}
