-- Pol's bound relic (Bombardier). He throws first and counts afterwards.
--
-- IT SETS OFF WHAT HE ALREADY PUT DOWN. Acid, Ice and Lightning Bomb, Blast Charge and the Powder Keg
-- all leave something on the floor; The Held Reaction is the shelf's one-at-a-time chain. This pulls
-- every fuse on the board together, so the relic's size is decided by how much of the fight he spent
-- littering -- which is the only thing a bombardier wants to be rewarded for.
--
-- A TALLY, NOT A CENSUS, and the reason is worth keeping: what is on the floor is not always his to
-- count, and a gate that read the board would open on somebody else's hazards. Three casts is his own
-- work, and by the third the floor is his anyway.
--
-- Detonation goes through fx.detonate, the same seam the shelf's own chain uses, so a charge set off
-- here behaves exactly as one set off by hand -- its own damage, its own tags, its own footprint.
return {
    name = "The Short Fuse",
    description = "Sets off every charge you have planted, at once.",
    flavor = "He is not reckless. He simply finished the arithmetic some time ago.",
    sprite = "assets/items/sig_short_fuse.png",
    type = "utility",
    tags = { "signature", "impact" },
    class = "alchemist",
    discipline = "bombardier",
    bound = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 5,
        cost = { stat = "stamina", amount = 9 },
        description = "Detonates every charge and trap you have planted on the field.",
        unlock = { event = "cast", count = 3, text = "Cast 3 times" },
        effect = function(fx)
            -- One call: Combat.detonateAll already means "every charge this caster planted", which is
            -- the whole of what the relic does. An earlier draft walked the trap list by hand and was
            -- both a duplicate of that helper and wrong about which charges are his.
            fx.detonate()
        end,
    },
}
