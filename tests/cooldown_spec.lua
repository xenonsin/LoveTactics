-- Tests for the cooldown primitive (Combat.setCooldown/onCooldown/tickCooldowns) and the counter
-- traits it gates (data/traits/{melee,ranged}_counter.lua): a struck fighter hits back, then the
-- reflex recharges before it can fire again. Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

-- A unit whose character carries the given innate traits (attached by Combat.new / Trait.setup).
local function unitWithTraits(id, x, y, traits)
    local char = Character.instantiate(id)
    char.traits = traits
    return { char = char, x = x, y = y }
end

local function unit(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

return {
    {
        name = "a cooldown counts down through rebase ticks and clears at 0",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("knight", 1, 1) }, {})
            local u = c.units[1]
            Combat.setCooldown(u, "test", 8)
            assert(Combat.onCooldown(u, "test"), "on cooldown after being set")

            Combat.tickCooldowns(c, 5)
            assert(Combat.onCooldown(u, "test"), "still recharging after 5 of 8 ticks")
            Combat.tickCooldowns(c, 3)
            assert(not Combat.onCooldown(u, "test"), "cleared once the ticks run out")
        end,
    },
    {
        name = "melee_counter strikes back on an adjacent hit, then goes on cooldown until it recharges",
        fn = function()
            -- Knight (default weapon iron_sword) with the counter reflex; bandit adjacent.
            local c = Combat.new(arena(6, 6),
                { unitWithTraits("knight", 1, 1, { "melee_counter" }) },
                { unit("bandit", 1, 2) })
            local knight, bandit = c.units[1], c.units[2]
            local weapon = Combat.defaultWeapon(bandit.char)

            local hp0 = bandit.char.stats.health.current
            Combat.dealDamage(c, bandit, knight, weapon) -- the bandit strikes the knight in melee
            assert(bandit.char.stats.health.current < hp0, "the knight counters the adjacent striker")
            assert(Combat.onCooldown(knight, "melee_counter"), "and the reflex is now recharging")

            -- A second blow while it recharges draws no counter.
            local hp1 = bandit.char.stats.health.current
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(bandit.char.stats.health.current == hp1, "no counter fires while on cooldown")

            -- Once it recharges, the next blow is answered again.
            Combat.tickCooldowns(c, 10)
            local hp2 = bandit.char.stats.health.current
            Combat.dealDamage(c, bandit, knight, weapon)
            assert(bandit.char.stats.health.current < hp2, "the counter fires again once recharged")
        end,
    },
    {
        name = "melee_counter ignores a ranged hit (the attacker stood too far to answer in kind)",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { unitWithTraits("knight", 1, 1, { "melee_counter" }) },
                { unit("archer", 1, 3) }) -- two tiles away: a ranged strike
            local knight, archer = c.units[1], c.units[2]
            local bow = Combat.defaultWeapon(archer.char)

            local hp0 = archer.char.stats.health.current
            Combat.dealDamage(c, archer, knight, bow)
            assert(archer.char.stats.health.current == hp0, "a melee counter does not answer a ranged shot")
            assert(not Combat.onCooldown(knight, "melee_counter"), "and the reflex was never spent")
        end,
    },
    {
        name = "ranged_counter answers a ranged shot with a bow, but not an adjacent blow",
        fn = function()
            -- Archer (default weapon bow, range 3) with the ranged reflex.
            local c = Combat.new(arena(6, 6),
                { unitWithTraits("archer", 1, 1, { "ranged_counter" }) },
                { unit("bandit", 1, 3), unit("wolf_grunt", 1, 2) })
            local archer = c.units[1]
            local shooter, mauler = c.units[2], c.units[3]

            -- A ranged strike from two tiles away is answered.
            local hp0 = shooter.char.stats.health.current
            Combat.dealDamage(c, shooter, archer, Combat.defaultWeapon(shooter.char))
            assert(shooter.char.stats.health.current < hp0, "the archer returns fire on a ranged attacker")
            assert(Combat.onCooldown(archer, "ranged_counter"), "and the reflex is recharging")

            -- Clear the cooldown; an ADJACENT blow now draws no ranged counter.
            Combat.tickCooldowns(c, 10)
            local hp1 = mauler.char.stats.health.current
            Combat.dealDamage(c, mauler, archer, Combat.defaultWeapon(mauler.char))
            assert(mauler.char.stats.health.current == hp1, "a ranged counter ignores an adjacent striker")
        end,
    },
}
