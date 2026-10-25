-- THE FIGHT'S DRESSING (approved 2026-10-24, "variety in the fight itself"): affixes on bodies, a rolled
-- objective, a fight condition -- models/dressing.lua, models/affix.lua, models/condition.lua.
--
-- What is held here: the rolls are deterministic off (seed, floor, cell) and never carry all three; the
-- excluded fights are never dressed; every affix does what its line says; a rolled objective is made real
-- against the roster and played to a decision inside the objective pass's own budget; and every condition
-- applies its rule -- Fog to the AI as well as to the player.
local Affix = require("models.affix")
local AI = require("models.ai")
local Arena = require("models.arena")
local Character = require("models.character")
local Combat = require("models.combat")
local Condition = require("models.condition")
local Dressing = require("models.dressing")
local Encounter = require("models.encounter")
local EncounterBattle = require("models.encounter_battle")
local Status = require("models.status")
local Trait = require("models.trait")

-- The objective pass's own budget (tests/objective_fight_spec.lua): a fight with a clock in it must END,
-- at a length a sitting can hold.
local OBJECTIVE_TURN_BUDGET = 70

local function board(cols, rows, extra)
    local tiles = {}
    for y = 1, rows do
        tiles[y] = {}
        for x = 1, cols do tiles[y][x] = { type = "ground", moveCost = 1, walkable = true } end
    end
    local a = { cols = cols, rows = rows, tiles = tiles, objective = { type = "killAll" }, seed = 99 }
    for k, v in pairs(extra or {}) do a[k] = v end
    return a
end

local function body(id, x, y) return { char = Character.instantiate(id), x = x, y = y } end

-- A two-body fight with the enemy at (x, y) wearing `affix`.
local function affixed(affix, ex, ey)
    ex, ey = ex or 4, ey or 5
    local a = board(8, 8, { enemies = { { id = "character_bandit", x = ex, y = ey, affix = affix } } })
    local c = Combat.new(a, { body("character_rowan", 4, 4) }, { body("character_bandit", ex, ey) })
    return c, c.units[1], c.units[2]
end

-- Every ordinary fight Dressing is allowed to dress, sorted.
local function ordinaryIds()
    local ids = {}
    for id, def in pairs(Encounter.defs) do
        if Dressing.eligible({ id = id, kind = def.kind }) then ids[#ids + 1] = id end
    end
    table.sort(ids)
    return ids
end

return {
    { name = "a dressing is dealt off the seed, the floor and the cell, and stamped once", fn = function()
        local ids = ordinaryIds()
        assert(#ids > 20, "there are ordinary fights to dress (" .. #ids .. ")")
        local enc = { id = ids[1], kind = Encounter.get(ids[1]).kind }
        local ctx = { seed = 424242, floor = 7, x = 5, y = 9, biome = "forest" }
        local a = Dressing.roll(enc, ctx)
        local b = Dressing.roll(enc, ctx)
        assert(Dressing.count(a) == Dressing.count(b), "same cell, same count")
        assert(a.objective == b.objective and a.condition == b.condition, "same cell, same objective and ground")
        assert(table.concat(a.affixes or {}, ",") == table.concat(b.affixes or {}, ","), "same affixes")
        local stamped = Dressing.stamp(enc, ctx)
        enc.dressing.condition = "condition_fog"
        assert(Dressing.stamp(enc, ctx) == stamped and stamped.condition == "condition_fog",
            "a stamped fight is never re-rolled")
        -- And a different cell can come out differently: across a floor, the dressings are not all one.
        local seen = {}
        for x = 1, 12 do
            local d = Dressing.roll(enc, { seed = 424242, floor = 7, x = x, y = 3 })
            seen[(d.objective or "-") .. (d.condition or "-") .. Dressing.count(d)] = true
        end
        local n = 0
        for _ in pairs(seen) do n = n + 1 end
        assert(n > 1, "twelve cells dealt one dressing")
    end },

    { name = "no fight carries all three, and each rides its own curve", fn = function()
        local ids = ordinaryIds()
        local shallow, deep, objectives, conditions, total = 0, 0, 0, 0, 0
        for i = 1, 400 do
            local id = ids[(i % #ids) + 1]
            local enc = { id = id, kind = Encounter.get(id).kind }
            for _, floor in ipairs({ 1, 10 }) do
                local d = Dressing.roll(enc, { seed = 77 + i, floor = floor, x = i % 13, y = i % 7 })
                assert(Dressing.count(d) <= 2, "three dressings on one fight: " .. id)
                assert(not d.affixes or #d.affixes <= Affix.MAX, "more than two affixes")
                if floor == 1 then
                    assert(not d.affixes or #d.affixes == 1, "floor one affixes one body")
                    if d.affixes then shallow = shallow + 1 end
                    if d.objective then objectives = objectives + 1 end
                    if d.condition then conditions = conditions + 1 end
                    total = total + 1
                else
                    assert(not d.affixes or #d.affixes == 2, "floor ten affixes two")
                    if d.affixes then deep = deep + 1 end
                end
            end
        end
        assert(deep > shallow * 1.8, "affixes thicken with depth: " .. shallow .. " shallow, " .. deep .. " deep")
        assert(Affix.chanceAt(1) == 0.25 and Affix.chanceAt(10) == 0.75 and Affix.chanceAt(15) == 0.75)
        assert(objectives > total * 0.1 and objectives < total * 0.4, "objectives about 30%: " .. objectives .. "/" .. total)
        assert(conditions > total * 0.1 and conditions < total * 0.4, "conditions about 25%: " .. conditions .. "/" .. total)
    end },

    { name = "a stair, an authored objective, a party, an escort and a scripted stop are never dressed", fn = function()
        assert(not Dressing.eligible({ kind = "stair" }))
        assert(not Dressing.eligible({ kind = "objective", id = "encounter_rest" }))
        local authored, party, escort
        for id, def in pairs(Encounter.defs) do
            if (def.kind == "combat" or def.kind == "elite") then
                if def.objective and not authored then authored = id end
                if def.party and not party then party = id end
                if def.allies and not escort then escort = id end
            end
        end
        for _, id in ipairs({ authored, party, escort }) do
            assert(id, "a fight of that sort exists to test")
            local enc = { id = id, kind = Encounter.get(id).kind }
            assert(not Dressing.eligible(enc), id .. " is dressed")
            assert(Dressing.stamp(enc, { seed = 1, floor = 9 }) == nil and enc.dressing == nil, id .. " was stamped")
        end
        local ordinary = ordinaryIds()[1]
        for _, flag in ipairs({ "leadIn", "wardFor", "questId", "opening", "mimic" }) do
            local enc = { id = ordinary, kind = "combat" }
            enc[flag] = true
            assert(not Dressing.eligible(enc), "a stop carrying " .. flag .. " is dressed")
        end
        -- And the walked-off path: a rolled objective has a win clock, so it is never auto-resolved.
        local cell = { encounter = { id = ordinary, kind = "combat", dressing = { objective = "survive" } } }
        assert(not EncounterBattle.cellEligible(cell) and EncounterBattle.cellRated(cell))
    end },

    { name = "a floor's seated fights are stamped, and the same floor deals the same dressing", fn = function()
        local id = ordinaryIds()[1]
        local function grid()
            local cells = {}
            for y = 1, 4 do
                cells[y] = {}
                for x = 1, 4 do cells[y][x] = { x = x, y = y } end
            end
            cells[2][3].encounter = { id = id, kind = "combat" }
            cells[4][1].encounter = { kind = "stair" }
            return { rows = 4, cols = 4, cells = cells }
        end
        local g1, g2 = grid(), grid()
        Dressing.floor(g1, { seed = 5150, floor = 4 })
        Dressing.floor(g2, { seed = 5150, floor = 4 })
        assert(g1.cells[2][3].encounter.dressing, "the fight is stamped")
        assert(g1.cells[4][1].encounter.dressing == nil, "the stair is not")
        local d1, d2 = g1.cells[2][3].encounter.dressing, g2.cells[2][3].encounter.dressing
        assert(Dressing.count(d1) == Dressing.count(d2) and d1.objective == d2.objective
            and d1.condition == d2.condition, "a reload deals the same dressing")
    end },

    { name = "an affix goes to the sturdiest body that can wear it, and never to the mark", fn = function()
        local enemies = {
            { id = "character_wolf_grunt", x = 1, y = 1 },
            { id = "character_bandit_chief", x = 2, y = 1 },
            { id = "character_totem", x = 3, y = 1 },
        }
        local obj = { type = "assassinate", targets = { "character_bandit_chief" } }
        Affix.assign(enemies, { "affix_swift", "affix_armored" }, obj)
        assert(enemies[2].affix == nil, "the assassination's mark wears nothing")
        assert(enemies[3].affix == nil, "an object wears nothing")
        assert(enemies[1].affix == "affix_swift", "the wolf takes the first")
        local plain = { { id = "character_bandit", x = 1, y = 1 }, { id = "character_bandit", x = 2, y = 1 },
                        { id = "character_bandit", x = 3, y = 1 } }
        assert(Affix.assign(plain, { "affix_swift", "affix_armored", "affix_thorned" }, nil) == 2,
            "never more than two")
    end },

    { name = "the board seats a fight's affixes and they reach the units", fn = function()
        local found
        for _, id in ipairs(ordinaryIds()) do
            local def = Encounter.get(id)
            if def.kind == "combat" then
                local built = EncounterBattle.build({
                    encounter = { id = id, kind = "combat", dressing = { affixes = { "affix_thorned" } } },
                    biome = "forest", depth = 3, party = { Character.instantiate("character_rowan") }, seed = 31,
                })
                for _, u in ipairs(built.combat.units) do if u.affix then found = u end end
                if found then
                    Combat.openBattle(built.combat)
                    break
                end
            end
        end
        assert(found and found.affix == "affix_thorned", "an affixed body stands on the board")
        assert(Trait.has(found, "trait_thorns"), "and it wears the thorns")
    end },

    { name = "every affix does what its line says", fn = function()
        local c, hero, foe = affixed("affix_swift")
        assert((foe.bonus.movement or 0) == 2, "Swift: +2 Move")
        assert(Status.has(foe, "status_hasted"), "Swift: opens Hasted")

        c, hero, foe = affixed("affix_armored")
        assert(Status.has(foe, "status_physical_barrier"), "Armored: opens behind a barrier")
        local hp0 = foe.char.stats.health.current
        assert(Combat.dealFlatDamage(c, foe, 20, { "physical" }, "test") == 0, "the first blow is stopped")
        assert(Combat.dealFlatDamage(c, foe, 20, { "physical" }, "test") == 0, "and the second")
        assert(foe.char.stats.health.current == hp0)

        c, hero, foe = affixed("affix_thorned")
        assert(Trait.has(foe, "trait_thorns"), "Thorned wears the thorns")
        c, hero, foe = affixed("affix_volatile")
        assert(Trait.has(foe, "trait_volatile"), "Volatile wears the imp's burst")
        c, hero, foe = affixed("affix_steadfast")
        assert(Trait.flag(foe, "unmoved"), "Steadfast cannot be moved")

        c, hero, foe = affixed("affix_vampiric")
        foe.char.stats.health.current = foe.char.stats.health.current - 12
        local before = foe.char.stats.health.current
        Trait.onBlowLanded(c, foe, hero, { amount = 12, before = 50 })
        assert(foe.char.stats.health.current == before + 4, "Vampiric heals a third of the blow: "
            .. before .. " -> " .. foe.char.stats.health.current)

        c, hero, foe = affixed("affix_hexing")
        Trait.onBlowLanded(c, foe, hero, { amount = 5, before = 50 })
        assert(Status.has(hero, "status_cursed"), "Hexing leaves its target Cursed")

        c, hero, foe = affixed("affix_warded")
        Status.apply(c, foe, "status_cursed")
        assert(not Status.has(foe, "status_cursed"), "Warded shrugs off the first hex")
        Status.apply(c, foe, "status_cursed")
        assert(Status.has(foe, "status_cursed"), "and only the first")

        do -- Rallying: an ally starting its turn beside the rallier is Empowered.
            local a = board(8, 8, { enemies = { { id = "character_bandit", x = 4, y = 5, affix = "affix_rallying" } } })
            local cc = Combat.new(a, { body("character_rowan", 1, 1) },
                { body("character_bandit", 4, 5), body("character_bandit", 5, 5), body("character_bandit", 8, 8) })
            local near, far = cc.units[3], cc.units[4]
            Trait.onAnyTurnStart(cc, near)
            Trait.onAnyTurnStart(cc, far)
            assert(Status.has(near, "status_empowered"), "the ally beside it is Empowered")
            assert(not Status.has(far, "status_empowered"), "the ally across the board is not")
        end

        c, hero, foe = affixed("affix_splitting")
        local n0 = #c.units
        local max = foe.char.stats.health.max
        foe.char.stats.health.current = math.floor(max / 2) + 1
        Combat.dealFlatDamage(c, foe, 4, { "true" }, "test")
        assert(foe.alive, "the body survives the blow")
        assert(#c.units == n0 + 1, "a copy steps out at half health")
        local copy = c.units[#c.units]
        assert(copy.side == "enemy" and copy.char.id == foe.char.id and not copy.summoned, "a real body of its kind")
        Combat.dealFlatDamage(c, foe, 1, { "true" }, "test")
        assert(#c.units == n0 + 1, "and only once")

        for id in pairs(Affix.defs) do
            local def = Affix.defs[id]
            assert(type(def.name) == "string" and type(def.description) == "string" and #def.description <= 120,
                id .. " names itself in one line")
            assert(def.mark and def.color, id .. " has a mark to draw")
        end
    end },

    { name = "a rolled objective is made real against the roster, and refused where it cannot fit", fn = function()
        local lead = Dressing.materialize("assassinate", { "character_wolf_grunt", "character_wolf_grunt", "character_bandit_chief" })
        local chiefTier = (Character.defs.character_bandit_chief.tier or 0)
        local wolfTier = (Character.defs.character_wolf_grunt.tier or 0)
        if chiefTier > wolfTier then
            assert(lead and lead.targets[1] == "character_bandit_chief" and lead.type == "assassinate", "the chief leads")
        end
        assert(Dressing.materialize("assassinate", { "character_bandit" }) == nil, "a lone body is no assassination")
        assert(Dressing.materialize("break", { "character_bandit", "character_bandit" }) == nil, "nothing to break")
        local br = Dressing.materialize("break", { "character_totemist", "character_totem" })
        assert(br and br.targets[1] == "character_totem" and br.verb == "Break")
        local hold = Dressing.materialize("hold", { "character_bandit", "character_bandit" })
        assert(hold.type == "hold" and hold.orKillAll and hold.duration == Dressing.HOLD_TICKS)
        local built = Arena.build({ depth = 3, biome = "forest" }, {
            party = { "character_rowan" }, seed = 12,
            composition = { "character_bandit", "character_bandit", "character_bandit" },
            rolledObjective = "survive",
        })
        assert(built.objective.type == "survive" and built.objective.waves, "a rolled survive gets the tide")
        local authored = Arena.build({ depth = 3, biome = "forest" }, {
            party = { "character_rowan" }, seed = 12,
            composition = { "character_bandit", "character_bandit" },
            objective = { type = "killAll" }, rolledObjective = "survive",
        })
        assert(authored.objective.type == "killAll", "never over an authored objective")
    end },

    { name = "rolled objective fights finish inside the objective budget when a real company plays them", fn = function()
        local Run = require("tests.support.objective_run")
        local ids = ordinaryIds()
        local played, undecided, long = 0, {}, {}
        for k, kind in ipairs(Dressing.KINDS) do
            local tried = 0
            for i = 1, #ids do
                if tried >= 2 then break end
                local id = ids[((i * 7 + k * 13) % #ids) + 1]
                local def = Encounter.get(id)
                local _, floor = Run.placeOf(def)
                local roster = Dressing.rosterOf({ id = id, kind = def.kind }, { depth = floor })
                if Dressing.compatible(kind, roster) then
                    tried = tried + 1
                    local r = Run.fight(id, { dressing = { objective = kind } })
                    played = played + 1
                    print(string.format("    %-10s %-44s %-5s %3d turns  %s", kind, id, tostring(r.result), r.turns,
                        tostring(r.combat.objective.type)))
                    if r.result == nil then undecided[#undecided + 1] = kind .. ":" .. id
                    elseif r.turns > OBJECTIVE_TURN_BUDGET then long[#long + 1] = kind .. ":" .. id .. " (" .. r.turns .. ")" end
                end
            end
        end
        assert(played >= 6, "a sample of rolled objectives was played (" .. played .. ")")
        assert(#undecided == 0, "never decided: " .. table.concat(undecided, ", "))
        assert(#long == 0, "past the budget of " .. OBJECTIVE_TURN_BUDGET .. ": " .. table.concat(long, ", "))
    end },

    { name = "fog caps every aim at three tiles, for the planner as well as the player", fn = function()
        local function fight(condition)
            local a = board(10, 10, { condition = condition })
            local archer = body("character_archer", 5, 1)
            archer.char.archetype = "holdGround"
            -- A longbow, so clear air reaches five and the fog has something to cut.
            Character.addItem(archer.char, require("models.item").instantiate("weapon_churchyard_yew"))
            local c = Combat.new(a, { body("character_rowan", 5, 6) }, { archer })
            return c, c.units[1], c.units[2]
        end
        local function reachable(c, u)
            local far = 0
            for _, item in ipairs(Character.eachItem(u.char)) do
                for _, t in ipairs(Combat.abilityTargets(c, u, item)) do
                    if t.side ~= u.side then far = math.max(far, Combat.unitGap(u, t)) end
                end
            end
            return far
        end
        local clear, hero, archer = fight(nil)
        assert(reachable(clear, archer) >= 5, "in clear air the archer reaches the knight five tiles off")
        local fog
        fog, hero, archer = fight("condition_fog")
        assert(hero.rules and hero.rules.longShadow == 3 and archer.rules.longShadow == 3, "both sides wear the cap")
        assert(Status.concealedAt(hero, fog, 5), "the knight cannot be aimed at from five")
        assert(reachable(fog, archer) == 0, "nothing on the archer's list five tiles off")
        local plan = AI.plan(fog, archer)
        if plan and plan.item and plan.tx then
            local from = plan.move or { x = archer.x, y = archer.y }
            assert(math.abs(from.x - plan.tx) + math.abs(from.y - plan.ty) <= 3, "the planner fires from inside the fog")
        end
        assert(not hero.char.rules or not hero.char.rules.longShadow, "the weather does not follow a body home")
    end },

    { name = "every condition applies its rule", fn = function()
        -- Darkness: the cap at two, every reach a tile shorter.
        local c = Combat.new(board(8, 8, { condition = "condition_darkness" }),
            { body("character_rowan", 1, 1) }, { body("character_bandit", 8, 8) })
        assert(c.units[1].rules.longShadow == 2 and c.units[1].rules.abilityRange == -1, "Darkness")

        -- Rain: everybody Wet at the bell, and again after a Cure.
        c = Combat.new(board(8, 8, { condition = "condition_rain" }),
            { body("character_rowan", 1, 1) }, { body("character_bandit", 8, 8) })
        for _, u in ipairs(c.units) do assert(Status.has(u, "status_wet"), "Rain soaks " .. u.char.id) end
        Status.remove(c, c.units[1], "status_wet")
        c.clock = 10
        assert(Condition.tick(c), "a turn's clock has passed")
        assert(Status.has(c.units[1], "status_wet"), "and the rain soaks again")

        -- Burning ground: two empty tiles catch each turn, never under a body.
        c = Combat.new(board(8, 8, { condition = "condition_burning_ground" }),
            { body("character_rowan", 1, 1) }, { body("character_bandit", 8, 8) })
        local before = #c.hazards
        c.clock = 5
        Condition.tick(c)
        local fires = 0
        for _, h in ipairs(c.hazards) do
            if h.alive and h.id == "hazard_fire" then
                fires = fires + 1
                assert(not Combat.unitAt(c, h.x, h.y), "a fire under a body")
            end
        end
        assert(fires == 2 and #c.hazards == before + 2, "two fires a turn, got " .. fires)
        assert(not Condition.tick(c), "and not twice on one clock")

        -- Tremors: rubble falls on an empty tile.
        c = Combat.new(board(8, 8, { condition = "condition_tremors" }),
            { body("character_rowan", 1, 1) }, { body("character_bandit", 8, 8) })
        c.clock = 5
        Condition.tick(c)
        assert(#c.walls == 1 and c.walls[1].id == "rubble" and c.walls[1].blocksMove, "a slab falls")

        -- Deep water: a band of water across the cut board, between the lines.
        local built = Arena.build({ depth = 2, biome = "forest" }, {
            party = { "character_rowan" }, seed = 2026,
            composition = { "character_bandit", "character_bandit" }, condition = "condition_deep_water",
        })
        local water = 0
        for y = 1, built.rows do
            for x = 1, built.cols do if built.tiles[y][x].type == "water" then water = water + 1 end end
        end
        assert(water >= 3, "a band of water is laid (" .. water .. " tiles)")
        assert(built.condition == "condition_deep_water")
        local again = Arena.build({ depth = 2, biome = "forest" }, {
            party = { "character_rowan" }, seed = 2026, composition = { "character_bandit", "character_bandit" },
        })
        local dry = 0
        for y = 1, again.rows do
            for x = 1, again.cols do if again.tiles[y][x].type == "water" then dry = dry + 1 end end
        end
        assert(dry < water, "the same board without it is drier: the band was not written into a shared layout")

        for id, def in pairs(Condition.defs) do
            assert(type(def.name) == "string" and type(def.description) == "string" and #def.description <= 120,
                id .. " says what it does in one line")
        end
        assert(Dressing.notice({ condition = "condition_fog" }, nil):find("^Fog: "), "the deploy notice names it")
        assert(Dressing.hudSuffix({ condition = "condition_fog" }) == " -- Fog")
    end },
    { name = "the condition and the Oath are two notices, each fitted on rows of its own", fn = function()
        local Relic = require("models.relic")
        local DeployPhase = require("ui.deploy_phase")
        local lines = Dressing.noticeLines({ condition = "condition_fog" }, Relic.ROOTED_NOTICE)
        assert(#lines == 2, "two things said are two lines, got " .. #lines)
        assert(lines[1]:find("^Fog: "), "the condition comes first")
        assert(lines[2] == Relic.ROOTED_NOTICE, "the Oath comes second, whole")
        assert(#Dressing.noticeLines({}, nil) == 0, "nothing to say is an empty list")

        -- A stub that WRAPS (six pixels a character, greedy on words), so a fold can be measured.
        local font = {}
        function font:getWidth(t) return #t * 6 end
        function font:getWrap(text, limit)
            local out, cur = {}, nil
            for word in text:gmatch("%S+") do
                local try = cur and (cur .. " " .. word) or word
                if cur and #try * 6 > limit then out[#out + 1] = cur; cur = word else cur = try end
            end
            out[#out + 1] = cur
            return limit, out
        end
        local width = 300 -- 50 characters: the Oath alone needs two rows
        -- Room for everything: the condition keeps its row and the Oath is never cut.
        local rows = DeployPhase.noticeRows(lines, font, width, 6)
        assert(rows[1]:find("^Fog: "), "the condition's row comes first")
        local tail = table.concat(rows, " ", 2)
        assert(not tail:find("...", 1, true), "with the room, nothing is ellipsized: " .. tail)
        assert(tail:find("abilities that move", 1, true), "the Oath's warning is read to its end")
        for _, r in ipairs(rows) do assert(font:getWidth(r) <= width, "every row fits its width: " .. r) end
        -- Two rows: one each, the condition first, neither run on into the other.
        rows = DeployPhase.noticeRows(lines, font, width, 2)
        assert(#rows == 2 and rows[1]:find("^Fog: ") and rows[2]:find("^The company"),
            "two rows give each notice its own")
        -- One row: the Oath keeps it -- it is what a ground fight turns on.
        rows = DeployPhase.noticeRows(lines, font, width, 1)
        assert(#rows == 1 and rows[1]:find("^The company"), "one row goes to the Oath")
        assert(#DeployPhase.noticeRows(lines, font, width, 0) == 0, "no room draws nothing")
    end },
}
