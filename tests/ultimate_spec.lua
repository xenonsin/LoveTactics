-- Tests for the conditional-signature ("ultimate") system: the per-unit event tallies that a
-- signature earns itself with (Combat.tally), the unlock gate that keeps it greyed until the
-- requirement is met (Combat.unlockMet / itemBlockReason), the fire-time re-lock (Combat.unlockConsume),
-- and Saber's bespoke chargeable wind-up (a deeper hold = a longer channel and a harder blow, and a
-- shattered wind-up wastes the swing). Pure logic, headless -- mirrors tests/spells_spec.lua.

local Character = require("models.character")
local Item = require("models.item")
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

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

local function findItem(char, id)
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then return it end
    end
end

-- A punching bag that survives anything, so a blow's magnitude can be read straight off its HP drop.
local function dummy(x, y)
    local u = unit("character_bandit", x, y)
    u.char.stats.health.max, u.char.stats.health.current = 99999, 99999
    u.char.stats.defense, u.char.stats.magicDefense = 0, 0
    return u
end

return {
    {
        name = "tallies start at zero and bank the right event on dealing / taking a blow",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_knight", 1, 1) }, { dummy(9, 9) })
            local knight, bag = c.units[1], c.units[2]
            assert(Combat.tallyCount(knight, "hitDealt") == 0, "a fresh unit has no tally")
            assert(Combat.tallyCount(bag, "hitTaken") == 0, "and neither does its target")

            -- Struck from across the board, so the bag cannot answer and muddy the tallies.
            local sword = Item.instantiate("weapon_iron_sword")
            local dealt = Combat.dealDamage(c, knight, bag, sword)
            assert(dealt > 0, "the blow drew blood")
            assert(Combat.tallyCount(knight, "hitDealt") == 1, "the attacker banks a hitDealt")
            assert(Combat.tallyCount(knight, "damageDealt") == dealt, "and the damage it dealt")
            assert(bag.alive, "the bag survives")
            assert(Combat.tallyCount(bag, "hitTaken") == 1, "the survivor banks a hitTaken")
            assert(Combat.tallyCount(bag, "damageTaken") == dealt, "and the damage it took")
        end,
    },
    {
        name = "beginning a turn banks a turnTaken; the killing blow banks a kill (never a hitTaken)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, { unit("character_bandit", 2, 1) })
            local acting = Combat.startTurn(c)
            assert(acting and Combat.tallyCount(acting, "turnTaken") == 1, "the actor banks a turnTaken")

            local knight, bandit = c.units[1], c.units[2]
            local before = Combat.tallyCount(bandit, "hitTaken")
            Combat.dealFlatDamage(c, bandit, 99999, { "physical" }, nil, knight)
            assert(not bandit.alive, "the bandit is felled")
            assert(Combat.tallyCount(knight, "kill") == 1, "the killer banks a kill")
            assert(Combat.tallyCount(bandit, "hitTaken") == before, "a fatal blow is not a hit survived")
        end,
    },
    {
        name = "an unlock gate greys a signature until its requirement is met, with progress",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, {})
            local knight = c.units[1]
            local ans = Item.instantiate("armor_sworn_aegis") -- its signature active: weather 4 blows
            local blocked = Combat.itemBlockReason(knight, ans)
            assert(blocked and blocked.kind == "locked", "locked before the requirement is met")
            assert(blocked.total == 4 and blocked.cur == 0, "progress reads 0/4")

            for _ = 1, 3 do Combat.tally(knight, "hitTaken", 1) end
            local mid = Combat.itemBlockReason(knight, ans)
            assert(mid and mid.cur == 3, "progress climbs to 3/4")

            Combat.tally(knight, "hitTaken", 1)
            assert(Combat.itemBlockReason(knight, ans) == nil, "unlocked at 4")
            assert(Combat.unlockMet(knight, ans), "and unlockMet agrees")
        end,
    },
    {
        name = "a repeatable unlock re-locks after firing; a `once` unlock stays open",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, {})
            local knight = c.units[1]
            local ans = Item.instantiate("armor_sworn_aegis")
            for _ = 1, 4 do Combat.tally(knight, "hitTaken", 1) end
            assert(Combat.unlockMet(knight, ans), "earned once")
            Combat.unlockConsume(knight, ans) -- fire it
            assert(not Combat.unlockMet(knight, ans), "re-locked after firing")
            for _ = 1, 4 do Combat.tally(knight, "hitTaken", 1) end
            assert(Combat.unlockMet(knight, ans), "earned again by weathering four more")

            -- A `once` signature latches open and never re-locks.
            local onceItem = { activeAbility = { unlock = { event = "kill", count = 1, once = true } } }
            assert(not Combat.unlockMet(knight, onceItem), "locked before its one kill")
            Combat.tally(knight, "kill", 1)
            assert(Combat.unlockMet(knight, onceItem), "opens on the kill")
            Combat.unlockConsume(knight, onceItem)
            assert(Combat.unlockMet(knight, onceItem), "and stays open for the rest of the battle")
        end,
    },
    {
        name = "a `when` predicate gates a signature on board state (HP threshold), not a tally",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 1, 1) }, {})
            local knight = c.units[1]
            local item = { activeAbility = { unlock = {
                when = function(u) return u.char.stats.health.current / u.char.stats.health.max < 0.5 end,
            } } }
            assert(not Combat.unlockMet(knight, item), "locked at full health")
            knight.char.stats.health.current = math.floor(knight.char.stats.health.max * 0.4)
            assert(Combat.unlockMet(knight, item), "opens once bloodied below half")
        end,
    },
    {
        name = "a gated signature never blocks the unit's basic loadout (turn-1 playability)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 2) }, { unit("character_bandit", 4, 2) })
            local knight = c.units[1]
            local mace = knight.char.inventory[1]
            local aegis = findItem(knight.char, "armor_sworn_aegis")
            assert(mace and Combat.itemBlockReason(knight, mace) == nil, "the basic weapon is usable turn 1")
            local blocked = aegis and Combat.itemBlockReason(knight, aegis)
            assert(blocked and blocked.kind == "locked", "while the signature answer on it is still locked")
        end,
    },
    {
        name = "Saber's wind-up: floored at min, capped at max, and a deeper hold hits harder",
        fn = function()
            local function windupHit(depth)
                local c = Combat.new(arena(10, 10), { unit("character_saber", 2, 2) }, { dummy(3, 2) })
                local saber, bag = c.units[1], c.units[2]
                local lw = findItem(saber.char, "weapon_first_motion")
                local before = bag.char.stats.health.current
                openTurn(c, saber)
                assert(Combat.useItem(c, saber, lw, 3, 2, depth), "the wind-up begins")
                assert(saber.channel, "she is channeling it")
                openTurn(c, saber)
                Combat.resolveChannel(c, saber) -- the wind-up lands
                return before - bag.char.stats.health.current, saber.channel
            end

            local lo, hi = 2, 5 -- weapon_first_motion windup { min = 2, max = 5 }
            local shallow = windupHit(lo)
            local deep = windupHit(hi)
            assert(shallow > 0 and deep > shallow, "the deeper wind-up hits harder (" .. deep .. " > " .. shallow .. ")")

            -- The depth is clamped to the ability's own [min, max], wherever it came from: a hold of 0
            -- is RAISED to the floor (a signature swing is never +0), an over-deep one capped.
            local function channelWindupFor(depth)
                local c = Combat.new(arena(10, 10), { unit("character_saber", 2, 2) }, { dummy(3, 2) })
                local saber = c.units[1]
                openTurn(c, saber)
                Combat.useItem(c, saber, findItem(saber.char, "weapon_first_motion"), 3, 2, depth)
                return saber.channel and saber.channel.windup
            end
            assert(channelWindupFor(0) == lo, "a hold below the floor is raised to windup.min (never +0)")
            assert(channelWindupFor(99) == hi, "an over-deep wind-up is capped at windup.max")
        end,
    },
    {
        name = "an interrupted wind-up wastes the swing -- cost spent, no blow lands",
        fn = function()
            local c = Combat.new(arena(10, 10), { unit("character_saber", 2, 2) }, { dummy(3, 2) })
            local saber, bag = c.units[1], c.units[2]
            local lw = findItem(saber.char, "weapon_first_motion")
            local hpBefore = bag.char.stats.health.current
            openTurn(c, saber)
            assert(Combat.useItem(c, saber, lw, 3, 2, 3), "the deep wind-up begins")
            assert(saber.channel, "she is committed to it")
            Combat.interruptChannel(c, saber, "test")
            assert(not saber.channel, "the wind-up is shattered")
            assert(Combat.resolveChannel(c, saber) == false, "there is nothing left to resolve")
            assert(bag.char.stats.health.current == hpBefore, "the wasted wind-up dealt nothing")
        end,
    },
}
