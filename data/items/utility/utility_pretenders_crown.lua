-- THE PRETENDER'S CROWN: the Many Faced One's relic, the first thing its fall pays (Descent.DROPS). "Kill a sin,
-- wear it": whoever lifts it wears the shape of what they last killed (trait_pretenders_crown) -- that body's
-- name, stats and kit, worn through the transform, so the bearer's own health pool carries across ("your health
-- stays yours") and a shape never brings a second bar.
--
-- A GENERAL'S RELIC, and an ALCHEMIST'S TROPHY, on Envy's house shelf (tests/sin_drops_spec.lua): a real class,
-- `unstocked`, no price, nothing takes it off you -- shown on the rack, refused as a monster drop. `unlockLevel`
-- is Envy's seat, floor twelve.
--
-- The row read "you MAY wear its shape". Built as automatic: the board has no prompt between a killing blow and
-- the next beat, and a shape the bearer does not want is taken off by the next kill.
return {
    name = "Pretender's Crown",
    description = "When you kill a foe, wear its shape until you kill another. Your health stays yours.",
    flavor = "It fits every head it has ever been on. It has been on a great many.",
    sprite = "assets/items/utility_pretenders_crown.png",
    type = "utility",
    tags = { "relic" },
    class = "alchemist",
    unlockLevel = 12,
    unstocked = true,
    noSteal = true, -- nothing takes this off you; you took it off the thing that wore it
    traits = { "trait_pretenders_crown" },
}
