-- Tests for the four new status effects: Cripple (movement cut), Mark (defense cut), Blind (range cut,
-- floored at 1), and Charm's reversion on expiry. Pure logic, headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Fixture = require("tests.support.fixture")

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
    char.traits = {}
    return { char = char, x = x, y = y }
end

return {
    {
        name = "Cripple reduces the unit's movement budget by 2",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_bandit", 1, 1) }, {})
            local u = c.units[1]
            local before = Combat.moveBudget(u)
            Status.apply(c, u, "status_cripple")
            assert(Combat.moveBudget(u) == before - 2, "cripple should cut movement by 2")
        end,
    },
    {
        name = "Mark reduces effective defense so a hit lands for more",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_bandit", 1, 1) }, {})
            local u = c.units[1]
            local base = 20 -- comfortably above the bandit's defense so nothing floors at 1
            local d0 = Combat.mitigatedDamage(u, base, { "physical" })
            Status.apply(c, u, "status_mark")
            local d1 = Combat.mitigatedDamage(u, base, { "physical" })
            assert(d1 == d0 + 5, "mark should cut defense by 5, so damage rises by 5")
        end,
    },
    {
        name = "Blind reduces ability range, but never below 1",
        fn = function()
            local c = Combat.new(arena(6, 6), { unit("character_bandit", 1, 1) }, {})
            local u = c.units[1]
            local far = { range = 5 }
            local r0 = Combat.abilityRange(c, u, far)
            Status.apply(c, u, "status_blind")
            assert(Combat.abilityRange(c, u, far) == r0 - 2, "blind should cut range by 2")
            -- A range-1 ability stays usable at melee: the reach floors at 1, not 0 or negative.
            assert(Combat.abilityRange(c, u, { range = 1 }) == 1, "blind never drops range below 1")
        end,
    },
    {
        -- The bug this gate exists for: the range cut lived only in Combat.abilityRange (the gate
        -- Combat.useItem checks) and not in Combat.attackReach (the band the red highlight, the
        -- action-preview tooltip and the click plan are all built from). A blinded unit therefore saw
        -- its FULL reach lit, hovered a foe two tiles past the cut, read a valid preview -- and the
        -- click did nothing at all, because useItem refused it and battle.confirm dropped the reason.
        -- Anything the band promises, the cast must accept.
        name = "Blind shortens the attack-reach band too, so it can't light a shot useItem refuses",
        fn = function()
            local c = Combat.new(arena(8, 1), { unit("character_archer", 1, 1) },
                { unit("character_bandit", 4, 1) })
            local a, foe = c.units[1], c.units[2]
            local bow = nil
            for _, it in ipairs(a.char.inventory) do
                if it.id == "weapon_iron_bow" then bow = it end
            end
            assert(bow and bow.activeAbility.range == 3, "the archer carries the range-3 bow")

            -- Sighted, no movement budget: the band is exactly the bow's three tiles.
            local ar = Combat.attackReach(c, a, 3, {}, true)
            assert(ar["4,1"], "unblinded, the foe three tiles off is in the band")

            Status.apply(c, a, "status_blind")
            local blind = Combat.attackReach(c, a, 3, {}, true)
            assert(blind["4,1"] == nil, "blinded, the band no longer reaches the 3-tile foe")
            assert(blind["2,1"], "but it still covers the adjacent tile")

            -- ...and the band and the gate say the same thing about that foe.
            c.turn = { unit = a, moved = false, moveCost = 0 }
            local hp0 = foe.char.stats.health.current
            assert(Combat.useItem(c, a, bow, 4, 1) == false, "the blinded shot is refused")
            assert(foe.char.stats.health.current == hp0, "and nothing was dealt")
        end,
    },
    {
        name = "Charm reverts a unit's side and control when it expires",
        fn = function()
            local c = Combat.new(arena(6, 6), {}, { unit("character_bandit", 1, 1) })
            local u = c.units[1]
            assert(u.side == "enemy", "the bandit starts on the enemy side")
            Status.apply(c, u, "status_charm", { duration = 2 })
            assert(u.side == "party", "while charmed it fights on the party side")
            Status.tick(c, 5) -- run the clock past the duration
            assert(u.side == "enemy", "on expiry it reverts to the enemy side")
            assert(u._charmSide == nil, "the stash is cleared on reversion")
            assert(not Status.has(u, "status_charm"), "the charm status is gone")
        end,
    },
    {
        name = "Cleansing a charmed unit reverts its side (Charm is a curable debuff)",
        fn = function()
            local c = Combat.new(arena(6, 6), {}, { unit("character_bandit", 1, 1) })
            local u = c.units[1]
            local origSide, origControl = u.side, u.control
            Status.apply(c, u, "status_charm", { duration = 5 })
            assert(u.side == "party", "charmed onto the party side")
            -- Cure strips the debuff; the teardown must still fire so the flip is undone.
            Combat.cleanse(c, u)
            assert(not Status.has(u, "status_charm"), "Cure strips the charm")
            assert(u.side == origSide and u.control == origControl, "and it reverts to its own side and control")
            assert(u._charmSide == nil, "the stash is cleared on reversion")
        end,
    },
    -- THE FLIP BELONGS TO THE STATUS, NOT TO THE DELIVERER. It lived in the Charm ability's effect,
    -- so the four things that charm the PLAYER -- the sweetbriar, the Petal Drift's touch, the
    -- Hartwood Bride's antlers, the Chorister's Lure -- all inflicted a badge that changed nothing,
    -- and a charmed party member kept taking the player's orders. These cases enter through a
    -- deliverer rather than through the ability, which is the half that was never covered.
    {
        name = "a Charm delivered by a weapon turns a party member against the party",
        fn = function()
            local c = Fixture.combat(Fixture.new(8, 8),
                { Fixture.unit("character_knight", 4, 4) },
                { Fixture.unit("character_chorister", 5, 4) })
            local knight, singer = c.units[1], c.units[2]
            assert(knight.side == "party" and Combat.isPlayerControlled(knight), "the knight starts yours")

            Fixture.openTurn(c, singer)
            assert(Combat.useItem(c, singer, Fixture.itemNamed(singer.char, "weapon_petal_touch"),
                knight.x, knight.y), "the chorister reaches him")

            assert(Status.has(knight, "status_charm"), "he is charmed")
            assert(knight.side == "enemy", "and he is fighting on the side that took him")
            assert(not Combat.isPlayerControlled(knight), "the player is not driving him while he is")
            Status.tick(c, 20)
            assert(knight.side == "party" and Combat.isPlayerControlled(knight), "he comes back")
        end,
    },
    {
        name = "ground names no charmer, so the victim simply turns on its own line",
        fn = function()
            -- The sweetbriar's path: an unsided hazard applies the status with no applier at all.
            local c = Combat.new(arena(6, 6), { unit("character_knight", 1, 1) }, {})
            local u = c.units[1]
            Status.apply(c, u, "status_charm")
            assert(u.side == "enemy" and u.control == "ai", "the briar takes him for the enemy")
        end,
    },
    {
        name = "a quest objective is never taken, whatever inflicts the Charm",
        fn = function()
            local c = Combat.new(arena(6, 6), {}, { unit("character_bandit_chief", 1, 1) })
            local boss = c.units[1]
            assert(boss.char.boss, "the chief is a quest objective")
            assert(Status.apply(c, boss, "status_charm") == nil, "the charm is refused outright")
            assert(not Status.has(boss, "status_charm"), "no badge lands")
            assert(boss.side == "enemy", "and it is still fighting its own fight")
        end,
    },
    {
        name = "a body that falls while charmed comes home, so a won fight still carries it out",
        fn = function()
            local c = Combat.new(arena(6, 6),
                { unit("character_knight", 1, 1) }, { unit("character_bandit", 3, 3) })
            local knight = c.units[1]
            Status.apply(c, knight, "status_charm", { applier = c.units[2] })
            assert(knight.side == "enemy", "charmed onto the enemy's side")

            Combat.dealFlatDamage(c, knight, 9999, nil, "test")
            assert(not knight.alive, "and cut down while he is theirs")
            assert(knight.side == "party", "he falls back to his own side")
            local fallen = Combat.fallenParty(c)
            assert(#fallen == 1 and fallen[1] == knight.char, "so the company carries him out")
        end,
    },
}
