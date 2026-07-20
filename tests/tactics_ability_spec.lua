-- Tests for the new tactical abilities and items: Feather Boots (ignore traps), Overwatch (reaction
-- fire), Smoke Bomb (negate + blink), Coup de Grace (execute + boss immunity), Shadow Step, Swap,
-- Drain Mana, Pinning/Hobbling Shot, Mark Target + Called Shot, Flash Bomb, and Charm. Pure, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Trap = require("models.trap")

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

-- A character with a clean 3x3 grid holding exactly `ids` in order (slots 1,2,3...), so a weapon and
-- the ability that requires it adjacent land in neighbouring cells. Innate traits are cleared.
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

local function openTurn(c, u)
    c.turn = { unit = u, moved = false, moveCost = 0 }
end

-- Reopen a fresh turn for a caster and top up its stamina/mana, so a test can fire several casts.
local function refresh(c, u)
    openTurn(c, u)
    for _, stat in ipairs({ "stamina", "mana" }) do
        local res = u.char.stats[stat]
        if type(res) == "table" then res.current = res.max end
    end
end

return {
    {
        name = "Feather Boots carry the wearer over a trap unharmed; without them it triggers",
        fn = function()
            -- With the boots: cross the spike trap at (1,3) on the way to (1,4), take no damage.
            local booted = withGrid("character_archer", { "utility_feather_boots" })
            local c = Combat.new(arena(8, 8), { unit(booted, 1, 1) }, {})
            Trap.place(c, 1, 3, "spike_trap", "enemy")
            local u = c.units[1]
            local hp0 = u.char.stats.health.current
            openTurn(c, u)
            assert(Combat.moveUnit(c, u, 1, 4), "the move succeeds")
            assert(u.char.stats.health.current == hp0, "feather boots cross the trap unharmed")
            assert(Trap.at(c, 1, 3) ~= nil, "the trap is not spent by a feather-booted mover")

            -- Control: the same walk without boots springs the trap.
            local bare = withGrid("character_archer", {})
            local c2 = Combat.new(arena(8, 8), { unit(bare, 1, 1) }, {})
            Trap.place(c2, 1, 3, "spike_trap", "enemy")
            local u2 = c2.units[1]
            local hp2 = u2.char.stats.health.current
            openTurn(c2, u2)
            assert(Combat.moveUnit(c2, u2, 1, 4), "the bare move succeeds")
            assert(u2.char.stats.health.current < hp2, "without boots the trap deals damage")
        end,
    },
    {
        name = "Overwatch fires on each step a foe takes through range, until stamina runs out",
        fn = function()
            local watcher = withGrid("character_archer", { "weapon_iron_bow" }) -- bow: range 3, minRange 2
            local c = Combat.new(arena(8, 8), { unit(watcher, 1, 1) }, { unit("character_bandit", 5, 1) })
            local w = c.units[1]
            local mover = Combat.unitAt(c, 5, 1)
            w.char.stats.stamina.current = 20
            w.overwatch = { staminaPerShot = 6 }
            local hp0 = mover.char.stats.health.current
            openTurn(c, mover)
            -- Walk (5,1)->(2,1): in range at (4,1) [d3] and (3,1) [d2], out of range at (2,1) [d1].
            assert(Combat.moveUnit(c, mover, 2, 1), "the foe walks across the firing line")
            assert(Combat.resource(w.char, "stamina") == 8, "two shots cost 12 stamina (20 -> 8)")
            assert(mover.char.stats.health.current < hp0, "the foe was shot for it")
        end,
    },
    {
        name = "Overwatch stops firing once the watcher can no longer pay a shot",
        fn = function()
            local watcher = withGrid("character_archer", { "weapon_iron_bow" })
            local c = Combat.new(arena(8, 8), { unit(watcher, 1, 1) }, { unit("character_bandit", 5, 1) })
            local w = c.units[1]
            local mover = Combat.unitAt(c, 5, 1)
            w.char.stats.stamina.current = 6 -- exactly one shot
            w.overwatch = { staminaPerShot = 6 }
            openTurn(c, mover)
            assert(Combat.moveUnit(c, mover, 2, 1), "the foe walks across the firing line")
            assert(Combat.resource(w.char, "stamina") == 0, "only one shot was affordable")
        end,
    },
    {
        name = "Smoke Bomb negates the first attack and blinks the bearer clear, then is spent",
        fn = function()
            local bearer = withGrid("character_knight", { "consumable_smoke_bomb" })
            local c = Combat.new(arena(8, 8), { unit(bearer, 3, 3) }, { unit("character_bandit", 2, 3) })
            local b = c.units[1]
            local attacker = Combat.unitAt(c, 2, 3)
            local hp0 = b.char.stats.health.current
            -- First incoming attack: negated, and the bearer blinks away from the attacker (+x).
            local dealt = Combat.dealFlatDamage(c, b, 20, { "physical" }, "test", attacker)
            assert(dealt == 0, "the first attack is negated")
            assert(b.char.stats.health.current == hp0, "no damage got through")
            assert(b.x > 3, "the bearer blinked away from the attacker")
            -- The charge is spent: a second attack lands normally.
            local again = Combat.dealFlatDamage(c, b, 20, { "physical" }, "test", attacker)
            assert(again > 0, "the second attack lands")
            assert(b.char.stats.health.current < hp0, "the second attack deals damage")
        end,
    },
    {
        name = "Coup de Grace executes a foe below a quarter health, but not above it",
        fn = function()
            local caster = withGrid("character_bandit", { "weapon_iron_sword", "ability_coup_de_grace" })
            local ab = itemOf(caster, "ability_coup_de_grace")

            -- Below threshold: a clean kill.
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) }, { unit("character_bandit", 2, 1) })
            local u = c.units[1]
            local low = Combat.unitAt(c, 2, 1)
            low.char.stats.health.current = 5 -- well under 25% of 60
            openTurn(c, u)
            assert(Combat.useItem(c, u, ab, 2, 1), "the strike lands")
            assert(not low.alive, "a foe below a quarter health is executed")

            -- Above threshold: a heavy but survivable hit.
            local c2 = Combat.new(arena(8, 8), { unit(withGrid("character_bandit", { "weapon_iron_sword", "ability_coup_de_grace" }), 1, 1) },
                { unit("character_bandit", 2, 1) })
            local u2 = c2.units[1]
            local ab2 = itemOf(u2.char, "ability_coup_de_grace")
            local healthy = Combat.unitAt(c2, 2, 1)
            local hp0 = healthy.char.stats.health.current
            openTurn(c2, u2)
            assert(Combat.useItem(c2, u2, ab2, 2, 1), "the strike lands")
            assert(healthy.alive, "a healthy foe is not executed")
            assert(healthy.char.stats.health.current < hp0, "but it still takes damage")
        end,
    },
    {
        name = "Coup de Grace never executes a boss",
        fn = function()
            local caster = withGrid("character_bandit", { "weapon_iron_sword", "ability_coup_de_grace" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) }, { unit("character_warlord", 2, 1) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_coup_de_grace")
            local boss = Combat.unitAt(c, 2, 1)
            boss.char.stats.health.current = 10 -- deep in "execute" territory for a normal foe
            openTurn(c, u)
            assert(Combat.useItem(c, u, ab, 2, 1), "the strike lands")
            assert(boss.alive, "a boss survives the finisher (execute is denied)")
        end,
    },
    {
        name = "Shadow Step blinks the caster adjacent to the target and damages it",
        fn = function()
            local caster = withGrid("character_bandit", { "ability_shadow_step" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) }, { unit("character_bandit", 4, 1) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_shadow_step")
            local foe = Combat.unitAt(c, 4, 1)
            local hp0 = foe.char.stats.health.current
            openTurn(c, u)
            assert(Combat.useItem(c, u, ab, 4, 1), "the step lands")
            local d = math.abs(u.x - foe.x) + math.abs(u.y - foe.y)
            assert(d == 1, "the caster ends adjacent to the target")
            assert(foe.char.stats.health.current < hp0, "and the target is struck")
        end,
    },
    {
        name = "Swap trades the caster's tile with the target's",
        fn = function()
            local caster = withGrid("character_bandit", { "ability_swap" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) }, { unit("character_bandit", 3, 1) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_swap")
            local foe = Combat.unitAt(c, 3, 1)
            openTurn(c, u)
            assert(Combat.useItem(c, u, ab, 3, 1), "the swap resolves")
            assert(u.x == 3 and u.y == 1, "the caster took the target's tile")
            assert(foe.x == 1 and foe.y == 1, "the target took the caster's tile")
        end,
    },
    {
        name = "Drain Mana moves mana from the target to the caster",
        fn = function()
            local caster = withGrid("character_mage", { "ability_drain_mana" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) }, { unit("character_mage", 3, 1) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_drain_mana")
            local foe = Combat.unitAt(c, 3, 1)
            u.char.stats.mana.current = 10
            foe.char.stats.mana.current = 10
            openTurn(c, u)
            assert(Combat.useItem(c, u, ab, 3, 1), "the siphon resolves")
            assert(foe.char.stats.mana.current == 2, "the target lost 8 mana (level-0 siphon)")
            assert(u.char.stats.mana.current == 18, "the caster gained exactly what was taken")
        end,
    },
    {
        name = "Pinning Shot roots the target; Hobbling Shot cripples it",
        fn = function()
            local pinner = withGrid("character_archer", { "weapon_iron_bow", "ability_pinning_shot" })
            local c = Combat.new(arena(8, 8), { unit(pinner, 1, 1) }, { unit("character_bandit", 1, 4) })
            local u = c.units[1]
            u.char.stats.stamina.current = 40
            local ab = itemOf(u.char, "ability_pinning_shot")
            local foe = Combat.unitAt(c, 1, 4)
            local hp0 = foe.char.stats.health.current
            openTurn(c, u)
            assert(Combat.useItem(c, u, ab, 1, 4), "the pinning shot lands")
            assert(Status.has(foe, "status_root"), "the target is rooted")
            assert(foe.char.stats.health.current < hp0, "and takes damage")

            local hobbler = withGrid("character_archer", { "weapon_iron_bow", "ability_hobbling_shot" })
            local c2 = Combat.new(arena(8, 8), { unit(hobbler, 1, 1) }, { unit("character_bandit", 1, 4) })
            local u2 = c2.units[1]
            u2.char.stats.stamina.current = 40
            local ab2 = itemOf(u2.char, "ability_hobbling_shot")
            local foe2 = Combat.unitAt(c2, 1, 4)
            openTurn(c2, u2)
            assert(Combat.useItem(c2, u2, ab2, 1, 4), "the hobbling shot lands")
            assert(Status.has(foe2, "status_cripple"), "the target is crippled")
        end,
    },
    {
        name = "Mark Target marks a foe; Called Shot hits a marked foe harder than an unmarked one",
        fn = function()
            local caster = withGrid("character_archer", { "ability_mark_target", "weapon_iron_bow", "ability_called_shot" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) },
                { unit("character_bandit", 1, 4), unit("character_bandit", 2, 4) })
            local u = c.units[1]
            u.char.stats.stamina.current = 60
            local mark = itemOf(u.char, "ability_mark_target")
            local called = itemOf(u.char, "ability_called_shot")
            local marked = Combat.unitAt(c, 1, 4)
            local plain = Combat.unitAt(c, 2, 4)

            refresh(c, u)
            assert(Combat.useItem(c, u, mark, 1, 4), "the mark lands")
            assert(Status.has(marked, "status_mark"), "the target is marked")

            refresh(c, u)
            local plainHp = plain.char.stats.health.current
            assert(Combat.useItem(c, u, called, 2, 4), "called shot on the unmarked foe")
            local plainDmg = plainHp - plain.char.stats.health.current

            refresh(c, u)
            local markHp = marked.char.stats.health.current
            assert(Combat.useItem(c, u, called, 1, 4), "called shot on the marked foe")
            local markDmg = markHp - marked.char.stats.health.current

            assert(markDmg > plainDmg, "the marked foe takes more (double + the defense cut)")
        end,
    },
    {
        name = "Flash Bomb blinds everything in its blast",
        fn = function()
            local caster = withGrid("character_bandit", { "consumable_flash_bomb" })
            local c = Combat.new(arena(8, 8), { unit(caster, 4, 1) },
                { unit("character_bandit", 4, 4), unit("character_bandit", 4, 5) })
            local u = c.units[1]
            local flash = itemOf(u.char, "consumable_flash_bomb")
            local a = Combat.unitAt(c, 4, 4)
            local b = Combat.unitAt(c, 4, 5)
            openTurn(c, u)
            assert(Combat.useItem(c, u, flash, 4, 4), "the flash bomb bursts")
            assert(Status.has(a, "status_blind") and Status.has(b, "status_blind"), "both foes in the blast are blinded")
        end,
    },
    {
        name = "Charm turns a wounded foe, respects a resist roll, and is denied against a boss",
        fn = function()
            local realRandom = Combat.random

            -- Success: a badly wounded foe, with the roll forced to succeed, flips to the party side.
            local caster = withGrid("character_mage", { "ability_charm" })
            local c = Combat.new(arena(8, 8), { unit(caster, 1, 1) }, { unit("character_bandit", 1, 3) })
            local u = c.units[1]
            local ab = itemOf(u.char, "ability_charm")
            local foe = Combat.unitAt(c, 1, 3)
            foe.char.stats.health.current = 6 -- near death: a high landing chance
            openTurn(c, u)
            Combat.random = function() return 1 end -- force the roll under any threshold
            local ok = Combat.useItem(c, u, ab, 1, 3)
            Combat.random = realRandom
            assert(ok, "the charm resolves")
            assert(Status.has(foe, "status_charm"), "the wounded foe is charmed")
            assert(foe.side == "party" and foe.control == "ai", "it fights for the party under AI control")

            -- Boss immunity: a boss is never turned, whatever the roll.
            local caster2 = withGrid("character_mage", { "ability_charm" })
            local c2 = Combat.new(arena(8, 8), { unit(caster2, 1, 1) }, { unit("character_warlord", 1, 3) })
            local u2 = c2.units[1]
            local ab2 = itemOf(u2.char, "ability_charm")
            local boss = Combat.unitAt(c2, 1, 3)
            boss.char.stats.health.current = 6
            openTurn(c2, u2)
            Combat.random = function() return 1 end
            Combat.useItem(c2, u2, ab2, 1, 3)
            Combat.random = realRandom
            assert(not Status.has(boss, "status_charm"), "a boss is not charmed")
            assert(boss.side == "enemy", "the boss stays on the enemy side")
        end,
    },
}
