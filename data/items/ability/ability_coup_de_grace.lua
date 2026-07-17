-- Coup de Grace: a finishing strike. An adjacent foe already below a quarter of its health is slain
-- outright -- an overwhelming, armor-ignoring blow (opts.raw, amount = full health) that drops it to 0.
-- Above the threshold it lands as an ordinary heavy hit. A boss is never executed: a quest objective
-- must be worn all the way down, not cut short. Requires an adjacent melee weapon in the grid.
return {
    name = "Coup de Grace",
    description = "Slays an adjacent foe below a quarter health outright. Bosses are immune. Needs a melee weapon adjacent.",
    flavor = "The Undercroft does not call it mercy. It does not call it anything else either.",
    sprite = "assets/items/ability_coup_de_grace.png",
    type = "ability",
    tags = { "guile", "physical" },
    class = "rogue",
    price = 300,
    repRank = 3,
    activeAbility = {
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
