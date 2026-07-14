-- Net: a weighted throwing net that tangles a foe's legs. Deals no damage -- it just Roots the target
-- (data/status/root.lua), pinning it where it stands and burning its time as if it had walked. A
-- rogue's cheap, disposable answer to a runner: throw it, then close in. Carries no magnitude to
-- forge (the root's duration is fixed), so it never appears at the alchemist's upgrade bench.
return {
    name = "Net",
    description = "A weighted net. Roots a foe in place -- no damage, just the tangle.",
    sprite = "assets/items/net.png",
    type = "consumable",
    tags = { "snare" },
    class = "rogue",
    price = 90,
    repRank = 1,
    activeAbility = {
        name = "Throw Net",
        target = "enemy",
        range = 3,
        requiresSight = true, -- a thrown net needs a clear line to its mark
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        consumesItem = true,
        effect = function(fx)
            fx.applyStatus(fx.target, "root")
        end,
    },
}
