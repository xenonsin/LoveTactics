-- Coup de Grace: a finishing strike. An adjacent foe already below a quarter of its health is slain
-- outright -- an overwhelming, armor-ignoring blow (opts.raw, amount = full health) that drops it to 0.
-- Above the threshold it lands as an ordinary heavy hit. A boss is never executed: a quest objective
-- must be worn all the way down, not cut short. Requires an adjacent melee weapon in the grid.
return {
    name = "Coup de Grace",
    description = "A finishing strike: an adjacent foe below a quarter health is slain outright. Bosses are immune. Requires an adjacent melee weapon.",
    sprite = "assets/items/ability_coup_de_grace.png",
    type = "ability",
    tags = { "guile", "physical" },
    class = "rogue",
    price = 300,
    repRank = 3,
    activeAbility = {
        name = "Coup de Grace",
        target = "enemy",
        range = 1,
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        requiresAdjacent = { type = "weapon", tag = "melee" },
        damage = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local hp = t.char.stats.health
            local frac = (hp.max > 0) and (hp.current / hp.max) or 1
            if not t.char.boss and frac <= 0.25 then
                fx.damage(t, { amount = hp.max, raw = true }) -- a clean kill: full health, ignoring armor
            else
                fx.damage(t)
            end
        end,
    },
}
