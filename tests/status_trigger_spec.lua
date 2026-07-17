-- Tests for the two conditional-trigger families:
--   #3 abilities that key off the TARGET's status  -- Exploit Weakness, Shatter Strike, Detonate
--   #4 traits that fire when a status is APPLIED    -- Opportunist, Cleansing Ward, Executioner's Eye
-- Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")

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

local function withGrid(id, ids)
    local char = Character.instantiate(id)
    char.traits = {}
    char.inventory = {}
    for _, iid in ipairs(ids) do Character.addItem(char, Item.instantiate(iid)) end
    return char
end

local function itemOf(char, id)
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then return it end
    end
end

local function refresh(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
    for _, stat in ipairs({ "stamina", "mana" }) do
        local res = u.char.stats[stat]
        if type(res) == "table" then res.current = res.max end
    end
end

return {
    {
        name = "Exploit Weakness hits a debuffed foe harder than a healthy one",
        fn = function()
            local caster = withGrid("character_bandit", { "weapon_iron_sword", "ability_exploit" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) },
                { unit("character_bandit", 2, 1), unit("character_bandit", 1, 2) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_exploit")
            local sick = Combat.unitAt(c, 2, 1)
            local well = Combat.unitAt(c, 1, 2)
            Status.apply(c, sick, "status_poison") -- any debuff arms the exploit

            refresh(c, u)
            local wellHp = well.char.stats.health.current
            assert(Combat.useItem(c, u, ab, 1, 2), "strike the healthy foe")
            local wellDmg = wellHp - well.char.stats.health.current

            refresh(c, u)
            local sickHp = sick.char.stats.health.current
            assert(Combat.useItem(c, u, ab, 2, 1), "strike the debuffed foe")
            local sickDmg = sickHp - sick.char.stats.health.current

            assert(sickDmg > wellDmg, "the debuffed foe takes the doubled hit")
        end,
    },
    {
        name = "Exploit Weakness scales with the number of debuffs on the foe",
        fn = function()
            local caster = withGrid("character_bandit", { "weapon_iron_sword", "ability_exploit" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) },
                { unit("character_bandit", 2, 1), unit("character_bandit", 1, 2) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_exploit")
            local one = Combat.unitAt(c, 2, 1)
            local many = Combat.unitAt(c, 1, 2)
            Status.apply(c, one, "status_poison")
            for _, id in ipairs({ "status_poison", "status_burn", "status_blind" }) do Status.apply(c, many, id) end

            refresh(c, u)
            local oneHp = one.char.stats.health.current
            assert(Combat.useItem(c, u, ab, 2, 1), "strike the singly-debuffed foe")
            local oneDmg = oneHp - one.char.stats.health.current

            refresh(c, u)
            local manyHp = many.char.stats.health.current
            assert(Combat.useItem(c, u, ab, 1, 2), "strike the thrice-debuffed foe")
            local manyDmg = manyHp - many.char.stats.health.current

            assert(manyDmg > oneDmg, "more debuffs, wider opening")
        end,
    },
    {
        name = "Shatter Strike doubles against a frozen foe and consumes the freeze",
        fn = function()
            local caster = withGrid("character_bandit", { "weapon_iron_sword", "ability_shatter_strike" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) },
                { unit("character_bandit", 2, 1), unit("character_bandit", 1, 2) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_shatter_strike")
            local frozen = Combat.unitAt(c, 2, 1)
            local plain = Combat.unitAt(c, 1, 2)
            Status.apply(c, frozen, "status_freeze")

            refresh(c, u)
            local plainHp = plain.char.stats.health.current
            assert(Combat.useItem(c, u, ab, 1, 2), "strike the un-frozen foe")
            local plainDmg = plainHp - plain.char.stats.health.current

            refresh(c, u)
            local frozenHp = frozen.char.stats.health.current
            assert(Combat.useItem(c, u, ab, 2, 1), "shatter the frozen foe")
            local frozenDmg = frozenHp - frozen.char.stats.health.current

            assert(frozenDmg > plainDmg, "the frozen foe takes far more")
            assert(not Status.has(frozen, "status_freeze"), "the freeze is shattered (consumed)")
        end,
    },
    {
        name = "Detonate bursts a burning foe into an area blast and consumes the burn",
        fn = function()
            local caster = withGrid("character_mage", { "ability_detonate" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) },
                { unit("character_bandit", 4, 1), unit("character_bandit", 4, 2) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_detonate")
            local burning = Combat.unitAt(c, 4, 1)
            local splash = Combat.unitAt(c, 4, 2)
            Status.apply(c, burning, "status_burn")
            local splashHp = splash.char.stats.health.current

            c.turn = { unit = u, moved = false, moveCost = 0 }
            assert(Combat.useItem(c, u, ab, 4, 1), "the detonation resolves")
            assert(splash.char.stats.health.current < splashHp, "the blast catches the neighbour")
            assert(not Status.has(burning, "status_burn"), "the burn is set off (consumed)")
        end,
    },
    {
        name = "Opportunist: afflicting a foe with a debuff hastes the bearer",
        fn = function()
            local bearer = withGrid("character_bandit", { "utility_opportunists_charm" })
            local c = Combat.new(arena(8, 8), { unit(bearer, 1, 1) }, { unit("character_bandit", 1, 3) })
            local b = c.units[1]
            local foe = Combat.unitAt(c, 1, 3)
            assert(not Status.has(b, "status_hasted"), "the bearer starts un-hasted")
            Status.apply(c, foe, "status_mark", { applier = b })
            assert(Status.has(b, "status_hasted"), "inflicting a debuff seizes the opening (Haste)")
        end,
    },
    {
        name = "Cleansing Ward strips the first debuff to land, then must recharge",
        fn = function()
            local bearer = withGrid("character_knight", { "utility_cleansing_ward" })
            local c = Combat.new(arena(8, 8), { unit(bearer, 1, 1) }, {})
            local b = c.units[1]
            Status.apply(c, b, "status_poison")
            assert(not Status.has(b, "status_poison"), "the first debuff is shrugged off")
            Status.apply(c, b, "status_cripple")
            assert(Status.has(b, "status_cripple"), "a second debuff within the cooldown sticks")
        end,
    },
    {
        name = "Executioner's Eye marks a foe the bearer stuns",
        fn = function()
            local bearer = withGrid("character_bandit", { "utility_executioners_eye" })
            local c = Combat.new(arena(8, 8), { unit(bearer, 1, 1) }, { unit("character_bandit", 1, 3) })
            local b = c.units[1]
            local foe = Combat.unitAt(c, 1, 3)
            Status.apply(c, foe, "status_stun", { applier = b })
            assert(Status.has(foe, "status_mark"), "stunning a foe marks it for the kill")
        end,
    },
}
