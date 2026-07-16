-- Tests for the hazard system (models/hazard.lua) and its combat hooks: on-entry effect delivery via
-- statuses (Burn/Wet/Regen), placement on occupied ground, duration refresh (no stacking), fire
-- spread into burnable terrain, water dousing, Wet's lightning vulnerability, and the enemy AI's
-- avoid-hostile / seek-friendly tile bias. Also the summoning abilities (Fireball leaving fire, Rain,
-- Sanctuary). Pure logic, headless.

local Character = require("models.character")
local Item = require("models.item")
local Combat = require("models.combat")
local Hazard = require("models.hazard")
local Status = require("models.status")

-- A flat, all-walkable ground arena (mirrors tests/trap_spec.lua's fixture).
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

local function countStatus(u, id)
    local n = 0
    for _, s in ipairs(u.statuses or {}) do if s.id == id then n = n + 1 end end
    return n
end

local function findItem(char, id)
    for _, it in ipairs(Character.eachItem(char)) do
        if it.id == id then return it end
    end
    return nil
end

return {
    {
        name = "a hazard may be placed on an occupied tile but not on a wall; a repeat refreshes it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, {})
            -- Occupied tile: unlike a trap, a hazard is meant to be stood in.
            assert(Hazard.place(c, 4, 4, "hazard_rain"), "a hazard can sit on an occupied tile")
            c.arena.tiles[3][3].walkable = false
            assert(Hazard.place(c, 3, 3, "hazard_rain") == nil, "a hazard refuses an impassable tile")

            local first = Hazard.at(c, 6, 6, "hazard_fire")
            assert(first == nil, "no fire yet at (6,6)")
            local a = Hazard.place(c, 6, 6, "hazard_fire")
            a.remaining = 1 -- run it low
            local b = Hazard.place(c, 6, 6, "hazard_fire")
            assert(a == b, "a repeat placement returns the same hazard, not a second one")
            assert(a.remaining == (Hazard.defs.hazard_fire.duration or 1), "the duration refreshed, not stacked")
        end,
    },
    {
        name = "walking onto a fire hazard applies Burn, which then damages at the next turn start",
        fn = function()
            -- Archer (movement 4, less 1 for leather = 3) walks (1,1)->(1,4) across fire at (1,3).
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, {})
            Hazard.place(c, 1, 3, "hazard_fire")
            local archer = c.units[1]
            local hp0 = archer.char.stats.health.current
            openTurn(c, archer)

            assert(Combat.moveUnit(c, archer, 1, 4), "the move across the fire succeeds")
            assert(Status.has(archer, "burn"), "entering the fire applied Burn")
            assert(archer.char.stats.health.current == hp0, "Burn deals no damage on entry (it ticks at turn start)")

            Combat.startTurn(c) -- opens the archer's next turn -> Burn's onTurnStart fires
            assert(archer.char.stats.health.current < hp0, "Burn dealt fire damage at the turn start")
        end,
    },
    {
        name = "crossing several fire tiles refreshes Burn rather than stacking a second instance",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("archer", 1, 1) }, {})
            Hazard.place(c, 1, 2, "hazard_fire")
            Hazard.place(c, 1, 3, "hazard_fire")
            local archer = c.units[1]
            openTurn(c, archer)

            assert(Combat.moveUnit(c, archer, 1, 4), "walk across both fire tiles")
            assert(countStatus(archer, "burn") == 1, "only one Burn instance despite crossing two fire tiles")
        end,
    },
    {
        name = "a hazard summoned onto a unit affects it immediately (Fireball-on-foe path)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, {})
            local knight = c.units[1]
            assert(Hazard.place(c, 4, 4, "hazard_heal"), "drop a sanctuary under the knight")
            assert(Status.has(knight, "regen"), "standing where it was summoned granted Regeneration at once")
        end,
    },
    {
        name = "sanctuary Regeneration ends the moment its unit leaves the hallowed ground",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, {})
            local knight = c.units[1]
            -- A 3x1 strip of sanctuary; the knight starts on the middle tile.
            Hazard.place(c, 3, 4, "hazard_heal")
            Hazard.place(c, 4, 4, "hazard_heal")
            assert(Status.has(knight, "regen"), "standing in the sanctuary grants Regeneration")

            -- Sidestep to the adjacent sanctuary tile: still hallowed, so the blessing holds.
            openTurn(c, knight)
            assert(Combat.moveUnit(c, knight, 3, 4), "the knight steps to the neighboring sanctuary tile")
            assert(Status.has(knight, "regen"), "moving within the zone keeps Regeneration")

            -- Step off onto ordinary ground: the blessing ends on the very beat it leaves.
            openTurn(c, knight)
            assert(Combat.moveUnit(c, knight, 2, 4), "the knight steps off the hallowed ground")
            assert(not Status.has(knight, "regen"), "leaving the sanctuary ends Regeneration at once")
        end,
    },
    {
        name = "a source-less Regeneration (a spell/potion buff) is not an aura and survives moving",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, {})
            local knight = c.units[1]
            Status.apply(c, knight, "regen") -- no `source`: a plain buff, not tied to any tile
            openTurn(c, knight)
            assert(Combat.moveUnit(c, knight, 3, 4), "the knight walks across open ground")
            assert(Status.has(knight, "regen"), "a source-less Regeneration lingers, unaffected by leaving")
        end,
    },
    {
        name = "a sanctuary blesses only its caster's side; a foe standing in it gains nothing",
        fn = function()
            -- The priest consecrates its own tile: the 3x3 blast also covers the bandit at (3,4).
            local c = Combat.new(arena(8, 8), { unit("priest", 3, 3) }, { unit("bandit", 3, 4) })
            local priest, bandit = c.units[1], c.units[2]
            local sanctuary = findItem(priest.char, "ability_sanctuary")
            assert(sanctuary, "the priest carries Sanctuary")
            openTurn(c, priest)

            assert(Combat.useItem(c, priest, sanctuary, 3, 3), "Sanctuary lands on the priest's own tile")
            assert(Hazard.at(c, 3, 4, "hazard_heal"), "hallowed ground covers the bandit's tile too")
            assert(Status.has(priest, "regen"), "the caster is blessed by its own sanctuary")
            assert(not Status.has(bandit, "regen"), "the foe standing in it gains no Regeneration")
        end,
    },
    {
        name = "an enemy walking onto the party's sanctuary is not healed, but onto its own it is",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, { unit("bandit", 4, 1) })
            local bandit = c.units[2]
            Hazard.place(c, 4, 3, "hazard_heal", { side = "party" })
            Hazard.place(c, 4, 5, "hazard_heal", { side = "enemy" })
            openTurn(c, bandit)

            assert(Combat.moveUnit(c, bandit, 4, 3), "the bandit walks onto the party's sanctuary")
            assert(not Status.has(bandit, "regen"), "the party's hallowed ground does not mend a foe")

            openTurn(c, bandit)
            assert(Combat.moveUnit(c, bandit, 4, 5), "the bandit walks onto its own sanctuary")
            assert(Status.has(bandit, "regen"), "its own hallowed ground mends it")
        end,
    },
    {
        name = "an unowned (arena-authored) sanctuary blesses whoever stands in it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 4, 4) }, { unit("bandit", 5, 5) })
            local knight, bandit = c.units[1], c.units[2]
            Hazard.place(c, 4, 4, "hazard_heal") -- no side: hallowed ground that was always there
            Hazard.place(c, 5, 5, "hazard_heal")
            assert(Status.has(knight, "regen") and Status.has(bandit, "regen"),
                "with no owner to take a side, it mends both")
        end,
    },
    {
        name = "Wet makes a lightning hit deal more damage (and the preview shares the same math)",
        fn = function()
            -- Mage's Jolt (tags lightning+magical) against a knight, before and after soaking it.
            local c = Combat.new(arena(8, 8), { unit("mage", 1, 1) }, { unit("knight", 1, 2) })
            local mage, knight = c.units[1], c.units[2]
            local jolt = findItem(mage.char, "ability_jolt")
            assert(jolt, "the mage carries Jolt")

            local before = Combat.computeDamage(c, mage, knight, jolt)
            Status.apply(c, knight, "wet")
            local after = Combat.computeDamage(c, mage, knight, jolt)
            local bonus = Status.defs.wet.vulnerable.lightning
            assert(after == before + bonus,
                string.format("Wet adds %d lightning damage (%d -> %d)", bonus, before, after))
        end,
    },
    {
        name = "Regeneration restores health at the start of the afflicted unit's turn",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            local knight = c.units[1]
            local hp = knight.char.stats.health
            hp.current = hp.max - 20 -- wound it so a heal has room
            Status.apply(c, knight, "regen")

            local before = hp.current
            Combat.startTurn(c) -- Regen's onTurnStart heals
            assert(hp.current > before, "Regeneration mended health at the turn start")
            assert(hp.current == before + Status.defs.regen.magnitude, "healed exactly its magnitude")
        end,
    },
    {
        name = "a water-tagged cast douses fire in its footprint (direct and via the Rain spell)",
        fn = function()
            -- Direct: Hazard.douse clears a dousable hazard on the given cells.
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            Hazard.place(c, 5, 5, "hazard_fire")
            assert(Hazard.douse(c, { { x = 5, y = 5 } }, { "water" }) == 1, "water doused the fire")
            assert(Hazard.at(c, 5, 5, "hazard_fire") == nil, "the fire is gone")

            -- Via a cast: the mage's Rain (water-tagged AoE) both douses fire and lays down rain.
            local c2 = Combat.new(arena(8, 8), { unit("mage", 3, 3) }, {})
            local mage = c2.units[1]
            local rain = findItem(mage.char, "ability_rain")
            assert(rain, "the mage carries Rain")
            Hazard.place(c2, 3, 3, "hazard_fire")
            Hazard.place(c2, 3, 4, "hazard_fire")
            openTurn(c2, mage)
            assert(Combat.useItem(c2, mage, rain, 3, 3), "casting Rain on its own tile is allowed (allowOccupied)")
            assert(Hazard.at(c2, 3, 3, "hazard_fire") == nil, "Rain doused the fire it fell on")
            assert(Hazard.at(c2, 3, 3, "hazard_rain"), "Rain left a downpour behind")
        end,
    },
    {
        name = "fire spreads to an adjacent burnable tile on tick, but not onto plain ground",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            c.arena.tiles[2][3].tags = { "burnable" } -- (3,2) is forest-like; (1,2) stays plain ground
            Hazard.place(c, 2, 2, "hazard_fire")

            Hazard.tick(c, 1) -- counts duration down, then spreads
            assert(Hazard.at(c, 3, 2, "hazard_fire"), "fire crept into the adjacent burnable tile")
            assert(Hazard.at(c, 1, 2, "hazard_fire") == nil, "fire did not spread onto plain ground")
        end,
    },
    {
        name = "tileBias reads negative under fire, positive under sanctuary, zero under rain",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            Hazard.place(c, 1, 1, "hazard_fire")
            Hazard.place(c, 2, 2, "hazard_heal")
            Hazard.place(c, 3, 3, "hazard_rain")
            assert(Hazard.tileBias(c, 1, 1) < 0, "fire is hostile (avoid)")
            assert(Hazard.tileBias(c, 2, 2) > 0, "sanctuary is friendly (seek)")
            assert(Hazard.tileBias(c, 3, 3) == 0, "rain is neutral")
            assert(Hazard.tileBias(c, 8, 8) == 0, "a clear tile has no bias")
        end,
    },
    {
        name = "tileBias only rewards a sanctuary's owning side, but fire burns whoever stands in it",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("knight", 1, 1) }, {})
            Hazard.place(c, 2, 2, "hazard_heal", { side = "party" })
            Hazard.place(c, 4, 4, "hazard_fire", { side = "party" })
            assert(Hazard.tileBias(c, 2, 2, "party") > 0, "the party seeks its own sanctuary")
            assert(Hazard.tileBias(c, 2, 2, "enemy") == 0, "the enemy has no reason to stand in it")
            assert(Hazard.tileBias(c, 4, 4, "party") < 0, "fire repels even the side that lit it")
        end,
    },
    {
        name = "offered two sanctuaries, the enemy AI advances onto its own and ignores the party's",
        fn = function()
            -- The two closest advance tiles (5,4) and (4,5) tie on distance, so ownership decides:
            -- only the enemy's own hallowed ground scores a bias, so it must take that tile.
            local enemyChar = Character.instantiate("bandit")
            enemyChar.inventory = {}
            local c = Combat.new(arena(8, 8), { unit("knight", 7, 7) }, { { char = enemyChar, x = 4, y = 4 } })
            local enemy = c.units[2]
            enemy.char.stats.movement = 1
            Hazard.place(c, 4, 5, "hazard_heal", { side = "party" })
            Hazard.place(c, 5, 4, "hazard_heal", { side = "enemy" })

            local plan = Combat.planEnemyAction(c, enemy)
            assert(plan.move, "the enemy plans to advance")
            assert(plan.move.x == 5 and plan.move.y == 4,
                string.format("it steps onto its own sanctuary, got (%d,%d)", plan.move.x, plan.move.y))
        end,
    },
    {
        name = "the enemy AI steps to the safe tile when its two best advance tiles tie except for fire",
        fn = function()
            -- Movement-1 enemy at (4,4), foe at (7,7): the two closest advance tiles (5,4) and (4,5)
            -- tie on distance, so the hazard bias decides. Fire on (5,4) -> it takes (4,5).
            local enemyChar = Character.instantiate("bandit")
            enemyChar.inventory = {} -- strip kit so only the range-1 unarmed remains (forces an advance)
            local c = Combat.new(arena(8, 8), { unit("knight", 7, 7) }, { { char = enemyChar, x = 4, y = 4 } })
            local enemy = c.units[2]
            enemy.char.stats.movement = 1
            Hazard.place(c, 5, 4, "hazard_fire")

            local plan = Combat.planEnemyAction(c, enemy)
            assert(plan.move, "the enemy plans to advance")
            assert(plan.move.x == 4 and plan.move.y == 5,
                string.format("it avoids the fire tile, got (%d,%d)", plan.move.x, plan.move.y))
        end,
    },
    {
        name = "the enemy AI steps toward a sanctuary when its two best advance tiles otherwise tie",
        fn = function()
            local enemyChar = Character.instantiate("bandit")
            enemyChar.inventory = {}
            local c = Combat.new(arena(8, 8), { unit("knight", 7, 7) }, { { char = enemyChar, x = 4, y = 4 } })
            local enemy = c.units[2]
            enemy.char.stats.movement = 1
            Hazard.place(c, 5, 4, "hazard_heal")

            local plan = Combat.planEnemyAction(c, enemy)
            assert(plan.move, "the enemy plans to advance")
            assert(plan.move.x == 5 and plan.move.y == 4,
                string.format("it steps onto the sanctuary, got (%d,%d)", plan.move.x, plan.move.y))
        end,
    },
    {
        name = "casting Fireball leaves a Fire hazard across its blast (and still damages foes)",
        fn = function()
            local c = Combat.new(arena(8, 8), { unit("mage", 3, 1) }, { unit("bandit", 3, 3) })
            local mage, bandit = c.units[1], c.units[2]
            local fireball = findItem(mage.char, "ability_fireball")
            assert(fireball, "the mage carries Fireball")
            local hp0 = bandit.char.stats.health.current
            openTurn(c, mage)

            assert(Combat.useItem(c, mage, fireball, 3, 3), "Fireball begins channeling")
            assert(Combat.resolveChannel(c, mage), "the wound-up blast lands on the bandit")
            assert(bandit.char.stats.health.current < hp0, "the blast damaged the foe")
            assert(Hazard.at(c, 3, 3, "hazard_fire"), "the blast centre is ablaze")
            assert(Hazard.at(c, 2, 2, "hazard_fire") and Hazard.at(c, 4, 4, "hazard_fire"),
                "fire covers the corners of the 3x3 blast")
        end,
    },
    {
        name = "Sanctuary scales its heal and lifespan with the item's upgrade level (from the item, in the tooltip)",
        fn = function()
            local priest = Character.instantiate("priest")
            priest.inventory = {}
            Character.addItem(priest, Item.instantiate("ability_sanctuary", 1, 4))
            local c = Combat.new(arena(8, 8), { unit(priest, 3, 3) }, { unit("bandit", 8, 8) })
            local caster = c.units[1]
            caster.char.stats.mana.current = caster.char.stats.mana.max
            local sanct = findItem(caster.char, "ability_sanctuary")
            assert(sanct and sanct.level == 4, "the priest carries a +4 Sanctuary")

            -- The tooltip dry run quotes the level-scaled lifespan and heal the item hands the hazard.
            local out = Combat.abilityOutput(caster, sanct)
            assert(out.hazard == "hazard_heal", "the tooltip names the ground it lays")
            assert(out.hazardDuration == 8, "lifespan = base 4 + level 4 = 8, got " .. tostring(out.hazardDuration))
            assert(out.hazardAmount == 12, "heal = base 8 + level 4 = 12, got " .. tostring(out.hazardAmount))

            -- And the live cast grants the caster a Regeneration of that scaled magnitude (un-ticked
            -- fields, so this is robust against the turn-end clock): the placed hazard's `amount` and the
            -- Regeneration it confers both read 12, not regen's blueprint base 8.
            openTurn(c, caster)
            assert(Combat.useItem(c, caster, sanct, 3, 3), "Sanctuary lands on the priest's tile")
            local hz = Hazard.at(c, 3, 3, "hazard_heal")
            assert(hz and hz.amount == 12, "the placed hazard carries the scaled heal magnitude")
            local reg = Status.get(caster, "regen")
            assert(reg and reg.magnitude == 12, "the blessing heals for the scaled magnitude (12), not 8")
        end,
    },
    {
        name = "Hazard.preview reports a hazard's applied status and scaled magnitude (for tooltips)",
        fn = function()
            -- Sanctuary previewed at heal 15: it grants Regeneration whose per-turn magnitude is that.
            local hp = Hazard.preview("hazard_heal", 15)
            assert(hp and #hp.statuses == 1 and hp.statuses[1].id == "regen", "it previews the Regeneration it grants")
            assert(hp.statuses[1].magnitude == 15, "and quotes the scaled per-turn magnitude, got " .. tostring(hp.statuses[1].magnitude))
            -- With no amount it falls back to the status's own blueprint magnitude.
            assert(Hazard.preview("hazard_heal").statuses[1].magnitude == Status.defs.regen.magnitude,
                "no amount -> regen's blueprint magnitude")
            assert(Hazard.preview("no_such_hazard") == nil, "an unknown hazard previews nothing")
        end,
    },
    {
        name = "hazard, status and ability blueprints all load headlessly",
        fn = function()
            for _, id in ipairs({ "hazard_fire", "hazard_rain", "hazard_heal" }) do
                assert(Hazard.defs[id], "hazard def loaded: " .. id)
            end
            assert(Status.defs.wet and Status.defs.regen, "wet + regen statuses loaded")
            for _, id in ipairs({ "ability_rain", "ability_sanctuary" }) do
                local it = Item.instantiate(id)
                assert(it and it.activeAbility, "ability loaded: " .. id)
            end
        end,
    },
}
