-- RACE: what a body IS, one axis above what it does (models/race.lua, data/races/).
--
-- Four things need holding and none of them can be seen from inside a single file:
--
--   1. THE FIELD SET IS CLOSED. models/terrain.lua taught this the expensive way -- a bag that accepted
--      every key and read two of them printed "+2 Defense bonus" to the player and moved no number in
--      the fight, for years, because nothing had authored the key yet.
--   2. `kind` IS DERIVED AND STAYS DERIVED. It is stamped onto every blueprint at load, so asserting
--      that a def's kind matches its race's would be asserting that an assignment happened -- circular,
--      and green against exactly the drift it is supposed to catch. So this reads the blueprint SOURCES
--      and fails on a `kind` line anybody adds back.
--   3. A RACE IS RULES AND A FIXED LINE, NEVER A CLASS. The stat budget, and no growth table.
--   4. THE RACIAL LINE REACHES THE BODY. The resist, the stats and the grants all fold at
--      Character.instantiate, and every one of them is a seam that can be dropped by a refactor of a
--      function that builds a runtime character field by field -- which is precisely how this codebase
--      builds one, on purpose, and precisely why a dropped field reads back nil in silence.

local Race = require("models.race")
local Character = require("models.character")
local Combat = require("models.combat")
local Balance = require("models.balance")

local tests = {}

tests[#tests + 1] = { name = "every race answers the closed set, and nothing outside it", fn = function()
    for id, def in pairs(Race.defs) do
        assert(type(def.name) == "string" and #def.name > 0, id .. ": a race says what it is called")
        assert(type(def.kind) == "string" and #def.kind > 0, id .. ": a race declares its kind")
        for key in pairs(def) do
            assert(Race.readsField(key), string.format(
                "%s declares %q, which nothing reads. A key absent from Race.FIELDS is a typo, and a "
                .. "typo in a data table is a promise made to the player and kept by nobody.", id, key))
        end
    end
    -- ...and the other direction: a declared field with no possible source is a dead entry in the list.
    for _, entry in ipairs(Race.FIELDS) do
        assert(type(entry.read) == "string" and #entry.read > 0,
            entry.key .. " is declared with no read site named")
    end
end }

tests[#tests + 1] = { name = "every kind a race names is a kind the bestiary's rules split on", fn = function()
    -- The seven the item rules have always known. Listed here rather than derived from the races
    -- themselves, because deriving it would let a typo'd kind invent an eighth category that every
    -- creature/bodied rule in the tree would then quietly answer "no" for.
    local KINDS = {
        humanoid = true, beast = true, demon = true, undead = true,
        construct = true, elemental = true, object = true,
    }
    for id, def in pairs(Race.defs) do
        assert(KINDS[def.kind], id .. ": unknown kind " .. tostring(def.kind))
    end
end }

tests[#tests + 1] = { name = "every body declares a race, and no body declares a kind", fn = function()
    local missing, authored = {}, {}
    for id, def in pairs(Character.defs) do
        if not def.race then
            missing[#missing + 1] = id
        elseif not Race.get(def.race) then
            missing[#missing + 1] = id .. " (race " .. tostring(def.race) .. " does not exist)"
        end
    end
    table.sort(missing)
    assert(#missing == 0, "bodies with no usable race:\n  " .. table.concat(missing, "\n  "))

    -- READ OFF THE SOURCE, which is the only non-circular way to ask this. models/character.lua stamps
    -- `def.kind` from the race at load, so the runtime table always agrees with itself; what this is
    -- actually asking is whether anybody has gone back to AUTHORING one, which would put two ledgers
    -- of one fact back in the tree and start the drift over.
    local files = love.filesystem.getDirectoryItems("data/characters")
    table.sort(files)
    for _, name in ipairs(files) do
        if name:match("%.lua$") then
            local src = love.filesystem.read("data/characters/" .. name) or ""
            for line in (src .. "\n"):gmatch("([^\n]*)\n") do
                -- Skip comments: several headers discuss `kind` in prose, and one quotes a different
                -- kind field entirely (character_slime's note about encounter kinds).
                if not line:match("^%s*%-%-") then
                    assert(not line:match("[%w_%.]*kind%s*=%s*[\"']"), string.format(
                        "%s authors a `kind`:%s\n  kind is DERIVED from `race` now (models/character.lua). "
                        .. "Two authored ledgers of one fact drift, and the drift is silent.",
                        name, line))
                end
            end
        end
    end
end }

tests[#tests + 1] = { name = "a race is rules and a fixed line, never a class", fn = function()
    for id, def in pairs(Race.defs) do
        -- The three things that would make it a class, refused by name so the refusal is readable in
        -- the failure rather than only in models/race.lua's header.
        assert(def.growth == nil, id .. ": a race may not carry a growth table -- that is a class")
        assert(def.class == nil and def.discipline == nil, id .. ": a race names no shelf")
        assert(def.unlockQuests == nil and def.price == nil, id .. ": a race is not merchandise")

        local spent = 0
        for stat, amount in pairs(def.bonus or {}) do
            assert(type(amount) == "number" and amount == math.floor(amount),
                string.format("%s: %s = %s is not a whole number", id, stat, tostring(amount)))
            spent = spent + math.abs(amount)
        end
        assert(spent <= Race.STAT_BUDGET, string.format(
            "%s spends %d points of stat line against a budget of %d. Absolute magnitude, so a line "
            .. "cannot buy itself room by pairing a large gift with a large cost -- a race that wants "
            .. "to be dramatic has tags, resists and grants to be dramatic with.",
            id, spent, Race.STAT_BUDGET))
    end
end }

tests[#tests + 1] = { name = "a racial resist obeys the innate contract at the lowest rung that wears it", fn = function()
    local legal = { magical = true }
    for _, t in ipairs(Balance.INNATE_PHYSICAL) do legal[t] = true end
    for t in pairs(Combat.ELEMENT_TAGS) do legal[t] = true end

    -- THE BUDGET IS THE LOWEST RUNG'S, and that is the whole reason this case is not a copy of
    -- tests/bestiary_spec.lua's. A blueprint's innate line is judged against its own tier; a race is
    -- worn by bodies at several rungs at once, so a table written at elite magnitude would put its own
    -- chaff over budget on the day it was authored, and nothing reading a single blueprint would see it.
    local lowest = {}
    for _, def in pairs(Character.defs) do
        local tier = def.tier or 0
        if def.race and tier > 0 then
            local seen = lowest[def.race]
            if not seen or tier < seen then lowest[def.race] = tier end
        end
    end

    local bad = {}
    for id, def in pairs(Race.defs) do
        if def.resist then
            local rung = lowest[id]
            local budget = rung and Balance.INNATE_BUDGET[rung]
            local function fail(fmt, ...) bad[#bad + 1] = id .. ": " .. string.format(fmt, ...) end

            local physical = 0
            for tag, amount in pairs(def.resist) do
                if tag == "physical" then
                    fail("names `physical`, which subtracts from all three melee probes at once -- "
                        .. "that is what the `defense` stat already is. Name the type.")
                elseif not legal[tag] then
                    fail("unknown resist tag %q -- nothing carries it, so the line is worth zero", tag)
                end
                if type(amount) ~= "number" or amount ~= math.floor(amount) then
                    fail("%s = %s is not a whole number of damage", tag, tostring(amount))
                elseif budget then
                    local cap = amount >= 0 and budget or budget * Balance.INNATE_WEAKNESS_FACTOR
                    if math.abs(amount) > cap then
                        fail("%s = %d exceeds the rung-%d %s budget of %d -- a race is written to the "
                            .. "LOWEST rung that wears it", tag, amount, rung,
                            amount >= 0 and "resist" or "weakness", cap)
                    end
                end
                for _, t in ipairs(Balance.INNATE_PHYSICAL) do
                    if tag == t then physical = physical + amount end
                end
            end

            if physical ~= 0 then
                fail("its slash/pierce/impact lines sum to %+d. A hide is a REDISTRIBUTION: turning "
                    .. "one weapon aside has to cost it another.", physical)
            end
        end
    end
    table.sort(bad)
    assert(#bad == 0, "racial `resist` tables that break the contract:\n  " .. table.concat(bad, "\n  "))
end }

tests[#tests + 1] = { name = "the naga is what its table says, on a body that was minted from it", fn = function()
    local c = Character.instantiate("character_shoalkin")
    assert(c.race == "naga", "the race rides the runtime character")
    assert(c.kind == "humanoid", "and the kind derives from it")

    -- The resist reaches the body...
    assert(c.resist and c.resist.lightning == -4, "a naga takes lightning the harder, off its race")
    assert(c.resist.slash == 1 and c.resist.pierce == -2, "scale turns a blade and opens to a point")

    -- ...the stat line is folded into the BASE, so nothing per-level can ever move it...
    local blueprint = Character.defs.character_shoalkin
    assert(c.stats.movement == blueprint.stats.movement - 1,
        "movement -1: the bill for the lane, paid on the base stat line")
    assert(c.stats.speed == blueprint.stats.speed + 1, "and speed +1 is the other half of the body")

    -- ...and the grant is in the grid, which is where Combat.isAquatic looks.
    local coils = false
    for _, item in ipairs(Character.eachItem(c)) do
        if item.id == "utility_naga_coils" then coils = true end
    end
    assert(coils, "the race put its own coils in the grid")
end }

tests[#tests + 1] = { name = "a granted item never displaces what the designer put in the grid", fn = function()
    -- The grant takes the first FREE cell. A blueprint's own layout is the thing a designer arranged by
    -- hand, and a racial organ landing on top of a signature weapon would be the race quietly editing
    -- content -- the exact failure mode that makes an implicit system worse than an explicit one.
    local c = Character.instantiate("character_fen_lancer")
    local def = Character.defs.character_fen_lancer
    for cell = 1, Character.MAX_INVENTORY do
        local authored = def.startingItems and def.startingItems[cell]
        if type(authored) == "string" then
            assert(c.inventory[cell] and c.inventory[cell].id == authored,
                "cell " .. cell .. " still holds what the blueprint put there")
        end
    end
end }

tests[#tests + 1] = { name = "a naga swims because of what it is, and a human does not", fn = function()
    local naga = { char = Character.instantiate("character_shoalkin"), x = 1, y = 1 }
    local man  = { char = Character.instantiate("character_bandit"), x = 2, y = 1 }
    assert(Combat.isAquatic(naga), "the race grants the swim, with no item authored on the blueprint")
    assert(not Combat.isAquatic(man), "and nobody else gets it for free")
end }

tests[#tests + 1] = { name = "the demon's holy line lives on the race and still reaches the unit", fn = function()
    -- docs/bestiary.md's one mechanical kind rule, rehomed. The check that keeps it
    -- (tests/bestiary_spec.lua) measures the finished unit and goes on measuring the unit; this asserts
    -- the race is now what MAKES it true, rather than sixteen blueprints each remembering to.
    local demon = Race.get("demon")
    assert(demon and demon.resist and demon.resist.holy < 0,
        "a demon takes holy the harder because of what it is")
    local c = Character.instantiate("character_demon_imp")
    assert(c.race == "demon" and c.kind == "demon", "an imp is one")
    assert(c.resist and c.resist.holy and c.resist.holy < 0, "and carries the line without authoring it")
end }

tests[#tests + 1] = { name = "a body's own resist layers OVER its race's, never under", fn = function()
    -- Flesh first, then what was put on top of it -- the same order the item fold uses one layer
    -- further out. A body that is tougher than its kin says so on its blueprint and wins the tag.
    local lord = Character.instantiate("character_demon_lord")
    local race = Race.get("demon").resist.holy
    -- The Lord's own crown carries -8; whatever the blueprint and the grid say, the race cannot be the
    -- thing that makes a demon LESS answerable to holy than its race declares.
    assert(lord.resist == nil or (lord.resist.holy or race) <= race,
        "a blueprint may deepen its race's weakness, never soften it into an advantage")
end }

return tests
