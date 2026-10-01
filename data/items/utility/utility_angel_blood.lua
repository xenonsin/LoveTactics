-- INCORRUPTIBLE: what an angel IS, granted by its race (data/races/angel.lua) into the first free cell of every
-- angel ever minted. Reviewed 2026-09-30 ("Pride's Bestiary").
--
-- Two rules on one organ, both of them what the race is rather than kit:
--   INCORRUPTIBLE  no debuff lands unless its own side laid it, and no push or pull moves it (trait_incorruptible;
--                  Status.isImmune and Status.blocksForcedMove read the flag)
--   WINGED         the `flying` tag: every tile costs one and no ground is impassable (Combat.isFlying)
--
-- Bound and unstealable: an organ, never kit.
return {
    name = "Incorruptible",
    description = "Foes' debuffs never land, and nothing pushes or pulls you. Flies.",
    flavor = "It has been offered everything there is. It has never once been tempted, and it will tell you so.",
    sprite = "assets/items/utility_angel_blood.png",
    type = "utility",
    tags = { "natural", "flying" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_incorruptible" },
}
