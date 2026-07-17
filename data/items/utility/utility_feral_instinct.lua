-- Feral Instinct: a beast's reflex to being cornered. The natural cousin of the Reprisal Quiver
-- (data/items/utility/utility_reprisal_quiver.lua) -- a passive utility whose whole effect is the Melee Counter
-- trait it grants (data/traits/melee_counter.lua): strike an animal carrying it from an adjacent tile
-- and, if it survives, it whips straight back with its fangs before the reflex has to recharge. Where
-- the quiver answers a shot, this answers a blow up close, which is how a boar or a wolf fights.
--
-- No `class`/`price`: it is not crafted or sold, only born with. It sits in the loadout of the wild
-- things (boar, stag, wolves) the way a signature relic sits in a hero's -- innate, not bought.
return {
    name = "Feral Instinct",
    description = "Struck in melee, it strikes straight back.",
    flavor = "Not crafted and not sold. Only born with, and only in things that were cornered young.",
    sprite = "assets/items/feral_instinct.png",
    type = "utility",
    tags = { "beast" },
    noSteal = true, -- an innate instinct, not a trinket: a pickpocket cannot lift it (like a beast's Fangs)
    traits = { "trait_melee_counter" },
}
