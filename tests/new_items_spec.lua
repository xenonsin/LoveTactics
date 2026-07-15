-- Tests for the new tactical kit added on top of the summon/status/trait systems: the AoE control
-- bombs, the priest's Banish and Renewal, the banner aura, the Wolfsong Horn's blood-summon, and the
-- rule that a hard-controlled unit cannot react. Pure logic, runs headless. See tests/summon_spec.lua
-- for the fixture style these borrow.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Summon = require("models.summon")
local Status = require("models.status")

local function arena(cols, rows, objective)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = objective or { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

local function itemNamed(char, id)
    for i = 1, Character.MAX_INVENTORY do
        local it = char.inventory[i]
        if it and it.id == id then return it end
    end
    return nil
end

local function equip(char, ids)
    char.inventory = {}
    for _, id in ipairs(ids) do Character.addItem(char, Item.instantiate(id)) end
end

return {
    {
        name = "the Ice Bomb freezes everything in its 3x3 blast",
        fn = function()
            local thrower = Character.instantiate("knight")
            equip(thrower, { "ice_bomb" })
            local c = Combat.new(arena(8, 8), { unit(thrower, 2, 2) },
                { unit("bandit", 4, 2), unit("bandit", 4, 3) })
            local a, b = c.units[2], c.units[3]
            openTurn(c, c.units[1])

            assert(Combat.useItem(c, c.units[1], itemNamed(thrower, "ice_bomb"), 4, 2), "the bomb bursts")
            assert(Status.has(a, "freeze"), "the foe at the center is frozen")
            assert(Status.has(b, "freeze"), "and so is the one caught at the edge of the blast")
        end,
    },
    {
        name = "the Lightning Bomb stuns everything in its 3x3 blast",
        fn = function()
            local thrower = Character.instantiate("knight")
            equip(thrower, { "lightning_bomb" })
            local c = Combat.new(arena(8, 8), { unit(thrower, 2, 2) },
                { unit("bandit", 4, 2), unit("bandit", 4, 3) })
            openTurn(c, c.units[1])

            assert(Combat.useItem(c, c.units[1], itemNamed(thrower, "lightning_bomb"), 4, 2), "the bomb bursts")
            -- Stun's badge is short (5 ticks) and the bomb's own turn resolving ages it past that, so we
            -- read the application from the log rather than the badge: both foes in the blast were stunned
            -- (the lasting effect -- the initiative shove from onApply -- has already landed permanently).
            local stunned = 0
            for _, e in ipairs(c.log) do
                if e.text:find("afflicted with Stun") then stunned = stunned + 1 end
            end
            assert(stunned == 2, "both foes in the blast were stunned, got " .. stunned)
        end,
    },
    {
        name = "Renewal grants an ally Regeneration",
        fn = function()
            local priest = Character.instantiate("priest")
            equip(priest, { "ability_renewal" })
            local c = Combat.new(arena(8, 8), { unit(priest, 2, 2), unit("knight", 3, 2) },
                { unit("bandit", 8, 8) })
            local ally = c.units[2]
            openTurn(c, c.units[1])

            assert(Combat.useItem(c, c.units[1], itemNamed(priest, "ability_renewal"), 3, 2), "the grace lands")
            assert(Status.has(ally, "regen"), "the ally is regenerating")
        end,
    },
    {
        name = "a hard-controlled beast cannot counter a melee blow",
        fn = function()
            -- A wolf carries Feral Instinct (melee_counter): struck in melee, it bites straight back.
            local without = Combat.new(arena(8, 8), { unit("wolf_grunt", 3, 2) }, { unit("bandit", 2, 2) })
            local wolf, bandit = without.units[1], without.units[2]
            local hp0 = bandit.char.stats.health.current
            Combat.dealFlatDamage(without, wolf, 5, { "physical" }, nil, bandit)
            assert(bandit.char.stats.health.current < hp0, "unhindered, the struck beast counters")

            -- The same blow, but the beast is stunned first: its reflex is shut down and it eats the hit.
            local with = Combat.new(arena(8, 8), { unit("wolf_grunt", 3, 2) }, { unit("bandit", 2, 2) })
            local wolf2, bandit2 = with.units[1], with.units[2]
            Status.apply(with, wolf2, "stun")
            local hp1 = bandit2.char.stats.health.current
            Combat.dealFlatDamage(with, wolf2, 5, { "physical" }, nil, bandit2)
            assert(bandit2.char.stats.health.current == hp1, "a stunned beast cannot counter")
        end,
    },
    {
        name = "a Banner pulses its status to allies in the 3x3 around it, but not to foes",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 2, 2), unit("knight", 5, 4) },
                { unit("bandit", 6, 4) })
            local archer, knight, bandit = c.units[1], c.units[2], c.units[3]

            -- Plant a rally banner beside the knight (and one tile from the bandit).
            local banner = Summon.spawn(c, archer, "banner", 4, 4, { control = "none" })
            banner.bannerAura = "inspiration"
            Status.apply(c, banner, "banner_aura")

            Status.onTurnStart(c, banner) -- the banner comes around to pulse
            assert(Status.has(knight, "inspiration"), "the ally beside it is inspired")
            assert(Status.statBonus(knight, "damage") == 4, "which raises its Damage")
            assert(not Status.has(bandit, "inspiration"), "the enemy in range gets nothing")
            assert(not Status.has(banner, "inspiration"), "and the banner does not inspire itself")
        end,
    },
    {
        name = "Banish unmakes summoned creatures in its blast but leaves real ones",
        fn = function()
            local mage = Character.instantiate("mage")
            equip(mage, { "ability_banish" })
            local c = Combat.new(arena(8, 8), { unit(mage, 4, 4) }, { unit("bandit", 5, 6) })
            local bandit = c.units[2]
            local wolf = Summon.spawn(c, bandit, "wolf_grunt", 6, 6) -- an enemy conjuration
            openTurn(c, c.units[1])

            assert(Combat.useItem(c, c.units[1], itemNamed(mage, "ability_banish"), 6, 6), "the word of unmaking lands")
            assert(not wolf.alive, "the summoned wolf is banished")
            assert(bandit.alive, "but the real bandit in the blast is untouched")
        end,
    },
    {
        name = "the Wolfsong Horn calls the Spirit at the cost of half the summoner's current health",
        fn = function()
            local archer = Character.instantiate("archer")
            local horn = itemNamed(archer, "sig_wolfsong_horn")
            horn.traits = {} -- silence the free companion so it can't take the tile we summon onto
            local c = Combat.new(arena(8, 8), { unit(archer, 2, 2) }, { unit("bandit", 8, 8) })
            local u = c.units[1]
            u.char.stats.health.current = 74 -- a clean even number to halve
            openTurn(c, u)

            assert(Combat.useItem(c, u, itemNamed(u.char, "sig_wolfsong_horn"), 3, 2), "the horn sounds")
            local spirit = Combat.unitAt(c, 3, 2)
            assert(spirit and spirit.char.id == "wolfsong_spirit", "the Wolfsong Spirit answers")
            assert(u.char.stats.health.current == 37, "and the archer pays half her current health, got "
                .. u.char.stats.health.current)
        end,
    },
}
