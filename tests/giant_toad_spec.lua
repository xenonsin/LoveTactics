-- THE GIANT TOAD (data/characters/character_giant_toad.lua), Gluttony's seat-floor ambusher, and the two
-- engine seams it brought: a body that MOVES ONLY BY HOPPING (Combat.hopReady -- Blink's teleport, always
-- on) and a body that can be SWALLOWED ALIVE (status_swallowed, Combat.swallow / Combat.disgorge). Settled
-- on review 2026-09-25 ("The Giant Toad" artifact). Pure logic, runs headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Status = require("models.status")
local Encounter = require("models.encounter")
local Descent = require("models.descent")

local function arena(cols, rows)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do
            tiles[y][x] = { type = "ground", moveCost = 1, walkable = true, sightCost = 0 }
        end
    end
    return { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" } }
end

local function unit(charOrId, x, y)
    local char = type(charOrId) == "string" and Character.instantiate(charOrId) or charOrId
    return { char = char, x = x, y = y }
end

local function itemOf(u, id)
    for _, it in ipairs(Character.eachItem(u.char)) do
        if it.id == id then return it end
    end
    error(id .. " is not in " .. tostring(u.char.id) .. "'s grid")
end

local function hp(u) return u.char.stats.health end
local function stamina(u) return u.char.stats.stamina.current end

-- A toad at (4,4) with a bandit beside it, the toad's turn open.
local function toadAndBandit()
    local c = Combat.new(arena(9, 9), { unit("character_bandit", 5, 4) }, { unit("character_giant_toad", 4, 4) })
    local bandit, toad = c.units[1], c.units[2]
    c.turn = { unit = toad, moved = false, moveCost = 0 }
    return c, toad, bandit
end

local function swallow(c, toad, bandit)
    local ok, why = Combat.useItem(c, toad, itemOf(toad, "ability_swallow"), bandit.x, bandit.y)
    assert(ok, "the swallow lands, got: " .. tostring(why))
end

return {
    -- -----------------------------------------------------------------------
    -- The hop
    -- -----------------------------------------------------------------------
    { name = "the toad hops (utility_toad_legs): at 0 movement it reaches a 3-tile diamond, over bodies", fn = function()
        local c, toad = toadAndBandit()
        assert(toad.char.stats.movement == 0 or (toad.char.stats.movement.current or 0) == 0
            or Combat.moveBudget(toad) == 0, "the toad walks nowhere")
        local reach = Combat.reachable(c, toad)
        assert(reach["7,4"], "three tiles out along a row")
        assert(reach["6,4"], "and past the bandit standing beside it")
        assert(not reach["8,4"], "but not four")
        assert(not reach["5,4"], "and never onto a body")
    end },

    { name = "a hop is one jump through Combat.blink: 8 stamina, the move spent, the turn still open", fn = function()
        local c, toad = toadAndBandit()
        local before = stamina(toad)
        local ok = Combat.moveUnit(c, toad, 7, 4)
        assert(ok, "the hop is legal")
        assert(toad.x == 7 and toad.y == 4, "it lands where it was aimed")
        assert(stamina(toad) == before - 8, "and pays 8 stamina, got " .. tostring(before - stamina(toad)))
        assert(c.turn and c.turn.moved, "the turn's one move is spent")
        assert(c.turn.moveCost == 0, "a hop owes no move initiative")
    end },

    { name = "a toad that cannot pay for a hop stays where it is, and a rooted one does too", fn = function()
        local c, toad = toadAndBandit()
        toad.char.stats.stamina.current = 7
        assert(next(Combat.reachable(c, toad)) == nil, "no stamina for a hop, and no walk to fall back on")
        toad.char.stats.stamina.current = 30
        Status.apply(c, toad, "status_root")
        assert(Combat.hopReady(toad) == nil, "Root holds a hopper")
        assert(not Combat.moveUnit(c, toad, 6, 4), "and the move is refused")
    end },

    { name = "the Bog-Hopper Greaves hop a knight 3 whatever its movement, and walk it when it cannot pay", fn = function()
        local knight = Character.instantiate("character_rowan")
        knight.inventory = {}
        Character.addItem(knight, Item.instantiate("utility_bog_hopper_greaves"))
        local c = Combat.new(arena(9, 9), { unit(knight, 2, 4) }, { unit("character_bandit", 9, 9) })
        local ku = c.units[1]
        c.turn = { unit = ku, moved = false, moveCost = 0 }
        local reach = Combat.reachable(c, ku)
        assert(reach["5,4"] and not reach["6,4"], "exactly three, not the knight's own walk")
        assert(Combat.moveUnit(c, ku, 5, 4), "the hop lands")
        assert(ku.x == 5, "on the aimed tile")
        -- ...and broke, it walks.
        c.turn = { unit = ku, moved = false, moveCost = 0 }
        ku.char.stats.stamina.current = 0
        assert(Combat.hopReady(ku) == nil, "no hop without the stamina")
        assert(next(Combat.reachable(c, ku)) ~= nil, "so the ordinary walk comes back")
    end },

    -- -----------------------------------------------------------------------
    -- The swallow
    -- -----------------------------------------------------------------------
    { name = "Swallow takes a foe off the board alive, and the toad is heavily Full", fn = function()
        local c, toad, bandit = toadAndBandit()
        swallow(c, toad, bandit)
        assert(bandit.alive, "swallowed is not dead")
        assert(bandit.swallowedBy == toad and toad.swallowing == bandit, "it is inside the toad")
        assert(Combat.unitAt(c, 5, 4) == nil, "its old tile is empty")
        assert(bandit.x == toad.x and bandit.y == toad.y, "its position is read through the toad")
        assert(Status.has(bandit, "status_swallowed"), "and it wears the status that says so")
        assert(Status.has(toad, "status_full"), "the toad is Full")
        assert(Status.statBonus(toad, "damage") >= 6, "and a meal is +6 damage")
        assert(Status.statBonus(toad, "defense") >= 6, "and +6 defense")
    end },

    { name = "a swallowed body moves with the toad and cannot be found on any tile", fn = function()
        local c, toad, bandit = toadAndBandit()
        swallow(c, toad, bandit)
        c.turn = { unit = toad, moved = false, moveCost = 0 }
        assert(Combat.moveUnit(c, toad, 4, 7), "a full toad still hops")
        assert(bandit.x == 4 and bandit.y == 7, "and carries its meal")
        for _, u in ipairs(Combat.unitsNear(c, 4, 7, 2)) do
            assert(u ~= bandit, "nothing near the toad finds the body inside it")
        end
    end },

    { name = "one meal at a time, and never a boss", fn = function()
        local c, toad, bandit = toadAndBandit()
        swallow(c, toad, bandit)
        local ok = itemOf(toad, "ability_swallow").activeAbility.usable(toad)
        assert(not ok, "a full mouth cannot swallow again")
        local boss = Character.instantiate("character_general_gluttony")
        local c2 = Combat.new(arena(9, 9), { unit(boss, 5, 4) }, { unit("character_giant_toad", 4, 4) })
        assert(not Combat.canSwallow(c2, c2.units[2], c2.units[1]), "a quest's ending does not go down a toad")
    end },

    { name = "a heavy blow makes the toad spit: the body lands beside it, Wet, and the Full goes too", fn = function()
        local c, toad, bandit = toadAndBandit()
        swallow(c, toad, bandit)
        local max = hp(toad).max
        Combat.dealFlatDamage(c, toad, math.ceil(max * 0.3), { "slash" }, "test", nil, { raw = true })
        assert(bandit.swallowedBy == nil and toad.swallowing == nil, "it is out")
        assert(not Status.has(bandit, "status_swallowed"), "and no longer Swallowed")
        assert(Combat.unitAt(c, bandit.x, bandit.y) == bandit, "it stands on a tile of its own again")
        assert(math.max(math.abs(bandit.x - toad.x), math.abs(bandit.y - toad.y)) == 1, "beside the toad")
        assert(Status.has(bandit, "status_wet"), "Wet")
        assert(not Status.has(toad, "status_full"), "and the toad's meal came out with it")
    end },

    { name = "a light blow does not", fn = function()
        local c, toad, bandit = toadAndBandit()
        swallow(c, toad, bandit)
        Combat.dealFlatDamage(c, toad, 3, { "slash" }, "test", nil, { raw = true })
        assert(bandit.swallowedBy == toad, "chip damage leaves the meal where it is")
    end },

    { name = "a stun makes it spit, and so does its death", fn = function()
        local c, toad, bandit = toadAndBandit()
        swallow(c, toad, bandit)
        Status.apply(c, toad, "status_stun")
        assert(bandit.swallowedBy == nil, "stunned, it lets go")

        local c2, toad2, bandit2 = toadAndBandit()
        swallow(c2, toad2, bandit2)
        Combat.dealFlatDamage(c2, toad2, hp(toad2).current + 50, { "slash" }, "test", nil, { raw = true })
        assert(not toad2.alive, "the toad is dead")
        assert(bandit2.alive and bandit2.swallowedBy == nil, "and the body inside walks out")
        assert(Combat.unitAt(c2, bandit2.x, bandit2.y) == bandit2, "onto a tile")
    end },

    { name = "digestion heals the toad by what it deals, and never kills: at the last point it spits", fn = function()
        local c, toad, bandit = toadAndBandit()
        swallow(c, toad, bandit)
        hp(toad).current = hp(toad).current - 20
        local toadBefore, banditBefore = hp(toad).current, hp(bandit).current
        Status.tick(c, 5) -- one turn
        local dealt = banditBefore - hp(bandit).current
        assert(dealt > 0, "a turn of digestion hurts")
        assert(hp(toad).current - toadBefore == dealt, "and heals the toad by exactly that much")

        hp(bandit).current = 2
        Status.tick(c, 5)
        assert(bandit.alive and hp(bandit).current >= 1, "it never digests a body to death")
        Status.tick(c, 1)
        assert(bandit.swallowedBy == nil, "it spits out what it cannot finish")
    end },

    { name = "the time running out spits it too", fn = function()
        local c, toad, bandit = toadAndBandit()
        swallow(c, toad, bandit)
        hp(bandit).current = 500
        hp(bandit).max = 500
        Status.tick(c, 16)
        assert(bandit.swallowedBy == nil, "three turns and it comes back out")
    end },

    { name = "the Gullet (ability_the_gullet) swallows for a person, at the Sated's size", fn = function()
        local knight = Character.instantiate("character_rowan")
        knight.inventory = {}
        local gullet = Item.instantiate("ability_the_gullet")
        Character.addItem(knight, gullet)
        local c = Combat.new(arena(9, 9), { unit(knight, 4, 4) }, { unit("character_bandit", 5, 4) })
        local ku, bandit = c.units[1], c.units[2]
        c.turn = { unit = ku, moved = false, moveCost = 0 }
        assert(Combat.useItem(c, ku, gullet, 5, 4), "the swallow lands")
        assert(bandit.swallowedBy == ku, "the bandit is inside the knight")
        local st = Status.get(ku, "status_full")
        assert(st, "the knight is Full")
        Status.tick(c, 11)
        assert(bandit.swallowedBy == nil, "and gives it back after two turns")
    end },

    -- -----------------------------------------------------------------------
    -- Its kit and its drops
    -- -----------------------------------------------------------------------
    { name = "the toad's kit: Tongue Lash poisons at 2, Spit mires at 3-4, Pull is its palate", fn = function()
        local def = Character.defs.character_giant_toad
        assert(def.defaultAction == "weapon_tongue_lash", "the tongue is its basic attack")
        local lash = Item.defs.weapon_tongue_lash.activeAbility
        assert(lash.range == 2, "reach 2")
        local spit = Item.defs.ability_toad_spit.activeAbility
        assert(spit.minRange == 3 and spit.range == 4, "Spit starts where the tongue ends")
        assert(def.palate == "ability_tongue_pull", "Gula takes its Pull")
        assert(Item.defs.ability_tongue_pull.activeAbility == Item.defs.ability_pull.activeAbility,
            "and the Tongue Pull is the shelf Pull's own verb, not a copy")
        local mb = Item.defs.utility_toad_legs.moveBehavior
        assert(mb.always and mb.movement == 3 and mb.cost.amount == 8, "the hop: 3 tiles, 8 stamina")
        local c, toad, bandit = toadAndBandit()
        bandit.x = 6
        assert(Combat.useItem(c, toad, itemOf(toad, "weapon_tongue_lash"), 6, 4), "the lash reaches 2")
        assert(Status.has(bandit, "status_poison"), "and poisons")
        -- Spit (ability_toad_spit) mires a body three or four out, and Toad Legs (utility_toad_legs) are
        -- in the grid that hops.
        local c2, toad2, far = toadAndBandit()
        far.x = 7
        assert(Combat.useItem(c2, toad2, itemOf(toad2, "ability_toad_spit"), 7, 4), "Spit reaches 3")
        assert(Status.has(far, "status_mired"), "and mires")
        assert(itemOf(toad2, "utility_toad_legs").moveBehavior.always, "the legs are always on")
        -- The Tongue Pull (ability_tongue_pull) fetches the far body next to the toad.
        c2.turn = { unit = toad2, moved = false, moveCost = 0 }
        far.char.stats.health.current = far.char.stats.health.max
        assert(Combat.useItem(c2, toad2, itemOf(toad2, "ability_tongue_pull"), far.x, far.y), "the tongue hooks")
        assert(math.abs(far.x - toad2.x) <= 1, "and hauls it in")
    end },

    { name = "it drops its hop and its swallow, both trophies, shallow to deep", fn = function()
        local drops = Character.defs.character_giant_toad.drops
        assert(drops[1] == "utility_bog_hopper_greaves" and drops[2] == "ability_the_gullet", "the two, in order")
        for _, id in ipairs(drops) do
            local d = Item.defs[id]
            assert(d.unstocked and not d.price, id .. " is rift-only")
        end
        assert(Item.defs.utility_bog_hopper_greaves.unlockLevel <= Item.defs.ability_the_gullet.unlockLevel,
            "shallow to deep")
    end },

    -- -----------------------------------------------------------------------
    -- Where it stands
    -- -----------------------------------------------------------------------
    { name = "the Wallow is floor two's own fight: a toad and moss slimes, never on the approach", fn = function()
        local def = Encounter.get("encounter_the_wallow")
        assert(def.rung == 2 and def.kind == "combat", "homed on the seat")
        local ids = def.composition({ depth = 2, biome = "forest" })
        local toads, slimes = 0, 0
        for _, id in ipairs(ids) do
            if id == "character_giant_toad" then toads = toads + 1 end
            if id == "character_moss_slime" then slimes = slimes + 1 end
        end
        assert(toads == 1 and slimes >= 1, "one toad and its slimes")
        local function inPool(rung)
            for _, e in ipairs(Encounter.pool({ biome = "forest", rung = rung, depth = rung })) do
                if e.id == "encounter_the_wallow" then return true end
            end
            return false
        end
        assert(inPool(2) and not inPool(1), "dealt on the seat, never above it")
    end },

    { name = "the toad walks into Gula's glade with the rest of the wood", fn = function()
        local gluttony
        for _, s in ipairs(Descent.SINS) do if s.id == "gluttony" then gluttony = s end end
        local found, ats = false, {}
        for _, w in ipairs(gluttony.guardian.waves) do
            ats[w.at] = (ats[w.at] or 0) + 1
            for _, id in ipairs(w.composition) do
                if id == "character_giant_toad" then found = true end
            end
        end
        assert(found, "a toad stream in her waves")
        for at, n in pairs(ats) do assert(n == 1, "two streams arrive at once at " .. at) end
    end },
}
