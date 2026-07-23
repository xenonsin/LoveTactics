-- Bolas: a thrown weight that wraps a runner's legs. Modest damage, then Root (data/status/root.lua) --
-- the target burns its turn going nowhere. The hunter half of the Poacher (rogue x hunter): it sets up
-- the Poacher's Kris, which bites half again as deep into a foe that cannot flinch away. Thrown, not a
-- bow shot, so it needs no weapon beside it -- the snare IS the tool.
return {
    name = "Bolas",
    description = "Deals damage and inflicts Root at range, pinning a foe for the kill.",
    flavor = "The Lodge tracks. The Undercroft collects. This is the knot where the two trades meet.",
    sprite = "assets/items/ability_bolas.png",
    type = "ability",
    tags = { "pierce", "physical" },
    class = "hunter",
    discipline = "poacher", -- rogue x hunter; the Snare-execute mechanic's first stock
    price = 240,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 3,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8 },
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_root")
        end,
    },
}
