-- Tests for CERBERUS'S HEADS ON THE TURN STRIP (Combat.seatPassiveHeads). A Cerberus head is timeless -- it
-- takes no turn -- and stands on no tile, so without a card on the strip it could be read nowhere but the
-- body's head picker. Each living one rides the strip as a PASSIVE entry right after its body: never an
-- actor, never in the turn order. The Chimera's heads take turns and are ordinary entries already.

local Combat = require("models.combat")
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

local function board() return Fixture.new(12, 12) end

local function walker(x, y)
    local spawn = Fixture.walker(x, y)
    spawn.char.stats.health.max, spawn.char.stats.health.current = 100, 100
    return spawn
end

local function one(c, id)
    for _, u in ipairs(c.units) do if u.char and u.char.id == id then return u end end
end

local function kill(c, u) Combat.dealFlatDamage(c, u, 99999, { "physical" }, "test", nil, { raw = true }) end

local function cerberus()
    local c = Fixture.combat(board(), walker(1, 1), { unit("character_cerberus", 5, 5, { stats = { health = 300 } }) })
    return c, one(c, "character_cerberus")
end

local function indexOf(entries, pred)
    for i, e in ipairs(entries) do if pred(e) then return i end end
end

return {
    {
        name = "Cerberus strip: three passive head cards sit directly after the body, and none is in the turn order",
        fn = function()
            local c, dog = cerberus()
            local heads = Combat.headsOf(c, dog)
            assert(#heads == 3, "three heads grow at the bell")
            local entries = Combat.buildTimeline(c, {})
            local at = indexOf(entries, function(e) return e.unit == dog and not e.preview and not e.passive end)
            assert(at, "the body has a live card")
            for k = 1, 3 do
                local e = entries[at + k]
                assert(e and e.passive and e.unit.headOf == dog, "entry " .. (at + k) .. " is a passive head")
                assert(not e.preview, "a passive card is not a ghost")
                assert(e.initiative == dog.initiative, "it carries the body's initiative")
            end
            local passives = 0
            for _, e in ipairs(entries) do if e.passive then passives = passives + 1 end end
            assert(passives == 3, "exactly three passive entries, got " .. passives)
            for _, u in ipairs(Combat.turnOrder(c)) do
                assert(not u.headOf, "no head is in the turn order")
            end
        end,
    },
    {
        name = "Cerberus strip: a ghost of the body never drags a head card along",
        fn = function()
            local c, dog = cerberus()
            local entries = Combat.previewTimeline(c, dog, dog.initiative + 500)
            for i, e in ipairs(entries) do
                if e.passive then
                    local prev = entries[i - 1]
                    assert(prev and (prev.unit == dog or (prev.passive and prev.passiveOf == dog))
                        and not prev.preview, "a head card follows the body's live card, never its ghost")
                end
            end
        end,
    },
    {
        name = "Cerberus strip: a broken head drops its card; a fallen dog takes them all",
        fn = function()
            local c, dog = cerberus()
            local heads = Combat.headsOf(c, dog)
            kill(c, heads[1])
            assert(not heads[1].alive, "the head is broken")
            local n = 0
            for _, e in ipairs(Combat.buildTimeline(c, {})) do
                if e.passive then
                    n = n + 1
                    assert(e.unit ~= heads[1], "the broken head has no card")
                end
            end
            assert(n == 2, "two cards left, got " .. n)
            kill(c, dog); kill(c, dog); kill(c, dog)
            for _, e in ipairs(Combat.buildTimeline(c, {})) do
                assert(not e.passive, "no head card outlives the body")
            end
        end,
    },
    {
        name = "Chimera strip: its heads take turns, so each has one ordinary card and no passive twin",
        fn = function()
            local c = Fixture.combat(board(), walker(1, 1),
                { unit("character_chimera", 5, 5, { stats = { health = 400 } }) })
            local body = one(c, "character_chimera")
            local heads = Combat.headsOf(c, body)
            assert(#heads == 2, "goat and serpent grow")
            local seen = {}
            for _, e in ipairs(Combat.buildTimeline(c, {})) do
                assert(not e.passive, "a head that takes turns gets no passive card")
                seen[e.unit] = (seen[e.unit] or 0) + 1
            end
            for _, h in ipairs(heads) do
                assert(seen[h] == 1, "each chimera head has exactly one card")
            end
        end,
    },
}
