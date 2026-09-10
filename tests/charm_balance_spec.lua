-- CHARM, AND THE THREE THINGS THAT WERE WRONG WITH THE FIRST BOSS FIGHT.
--
-- Charming a whole company wipes it: Combat.eliminated counts a side by who is standing on it, and
-- Charm moves a body onto the charmer's side. That is DELIBERATE and this file pins it -- taking a
-- company entire is a way to beat it. What was wrong was everything around it.
--
--   1. The take ignored the dice. Every deliverer applied Charm on the line AFTER the damage, so a
--      missed swing took the body anyway (docs/accuracy.md: a miss takes the on-hit statuses with it).
--   2. The planner would take the last free body, which ends the fight by picking a mark.
--   3. The bodies delivering it had exactly one action each, so a hundred percent of what the Lust
--      circle DID was Charm -- and an add refused one had nothing else to do with its turn.
--
-- Headless, and every case here is about the model rather than about a screen.

local Character = require("models.character")
local Combat = require("models.combat")
local Status = require("models.status")
local Item = require("models.item")
local AI = require("models.ai")

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

local function unit(id, x, y)
    local char = Character.instantiate(id)
    char.traits = {}
    return { char = char, x = x, y = y }
end

local tests = {}

-- The win condition, stated as a test so nobody "fixes" it later. It is the one thing in this file
-- that is unchanged, and it is the reason every other case exists.
tests[#tests + 1] = { name = "a company charmed entire is a company beaten", fn = function()
    local c = Combat.new(arena(8, 8),
        { unit("character_knight", 1, 1), unit("character_archer", 2, 1) },
        { unit("character_petal_drift", 6, 6) })
    assert(Combat.evaluate(c) == nil, "the fight is live to begin with")
    for _, u in ipairs(c.units) do
        if u.side == "party" then Status.apply(c, u, "status_charm", { duration = 10 }) end
    end
    assert(Combat.aliveCount(c, "party") == 0, "nobody is standing on the party's side")
    assert(Combat.evaluate(c) == "loss", "and taking the whole company is how you beat it")
end }

-- 1. THE TAKE ROLLS. Both charming weapons carry the status inside the hit rather than applying it
-- after, so the miss gate in Combat.dealDamage takes it with the wound.
tests[#tests + 1] = { name = "a missed Petal Touch takes nobody", fn = function()
    local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 1) },
        { unit("character_the_suppliant", 1, 1) })
    local supp, knight = c.units[2], c.units[1]
    local touch = Item.instantiate("weapon_petal_touch")

    -- The suite pins the dice open (tests/runner.lua sets Combat.FORCE_HIT); this case is precisely
    -- about what happens when they are not, so it clears the flag and puts it back.
    local was = Combat.FORCE_HIT
    Combat.FORCE_HIT = false
    -- A hit chance of zero is the honest way to force a miss without reaching into the generator:
    -- clamp(Hit - Avoid) floors at 0, so an unreachable Avoid misses every time under 2RN as well.
    local avoid = Combat.avoid
    Combat.avoid = function() return 10000 end
    local ok, err = pcall(function()
        assert(Combat.hitChance(c, supp, knight, touch) == 0, "the swing cannot land")
        Combat.useItem(c, supp, touch, knight.x, knight.y)
        assert(not Status.has(knight, "status_charm"),
            "a swing that drew no blood must take no body -- the charm has to ride the hit")
        assert(knight.side == "party", "and the knight is still the party's")
    end)
    Combat.avoid, Combat.FORCE_HIT = avoid, was
    assert(ok, err)
end }

tests[#tests + 1] = { name = "a landed Petal Touch still takes the body", fn = function()
    local c = Combat.new(arena(8, 8), { unit("character_knight", 2, 1) },
        { unit("character_the_suppliant", 1, 1) })
    local supp, knight = c.units[2], c.units[1]
    Combat.useItem(c, supp, Item.instantiate("weapon_petal_touch"), knight.x, knight.y)
    assert(Status.has(knight, "status_charm"), "the charm still lands on a hit")
    assert(knight.side == "enemy", "and the flip still happens")
end }

-- The Bride's sweep is the same rule at three bodies wide, and she is the body it matters most on --
-- she takes a rank at a time, so a sweep outside the dice was the one action a party's Avoid bought
-- nothing against. Fought on a real board rather than read off Combat.abilityOutput, which pins its
-- dummy at (0,0) and so never enters an AoE loop at all (the sweep would report no statuses and the
-- case would pass for the wrong reason).
tests[#tests + 1] = { name = "the Antler Crown's sweep takes what it hits and misses what it misses", fn = function()
    local crown = Item.instantiate("weapon_antler_crown")

    local c = Combat.new(arena(10, 10), { unit("character_knight", 4, 3) },
        { unit("character_the_hartwood_bride", 2, 3) })
    local bride, knight = c.units[2], c.units[1]
    Combat.useItem(c, bride, crown, knight.x, knight.y)
    assert(Status.has(knight, "status_charm"), "a landed sweep still takes the body it caught")

    local c2 = Combat.new(arena(10, 10), { unit("character_knight", 4, 3) },
        { unit("character_the_hartwood_bride", 2, 3) })
    local bride2, knight2 = c2.units[2], c2.units[1]
    local was, avoid = Combat.FORCE_HIT, Combat.avoid
    Combat.FORCE_HIT = false
    Combat.avoid = function() return 10000 end
    local ok, err = pcall(function()
        Combat.useItem(c2, bride2, crown, knight2.x, knight2.y)
        assert(not Status.has(knight2, "status_charm"),
            "a sweep that missed must take nobody -- the charm has to ride each catch")
    end)
    Combat.avoid, Combat.FORCE_HIT = avoid, was
    assert(ok, err)
end }

-- 2. THE PLANNER WILL NOT TAKE THE LAST ONE.
tests[#tests + 1] = { name = "AI.lastFreeBody names the last un-charmed body and only then", fn = function()
    local c = Combat.new(arena(8, 8),
        { unit("character_knight", 1, 1), unit("character_archer", 2, 1) },
        { unit("character_petal_drift", 6, 6) })
    local knight, archer = c.units[1], c.units[2]
    assert(AI.lastFreeBody(c, "party") == nil, "two free bodies: there is nothing to protect yet")
    Status.apply(c, knight, "status_charm", { duration = 10 })
    assert(AI.lastFreeBody(c, "party") == archer,
        "one taken, so the archer is the last body the party still owns")
    -- ...and it reads through the flip rather than around it: the charmed knight is standing on the
    -- enemy's side and is still one of the party's, which is what Status.ownSide is for.
    assert(knight.side == "enemy" and Status.ownSide(knight) == "party",
        "the charmed knight belongs to the party while it fights for the enemy")
    Status.apply(c, archer, "status_charm", { duration = 10 })
    assert(AI.lastFreeBody(c, "party") == nil, "with none left free there is nothing to name")
end }

tests[#tests + 1] = { name = "the planner refuses to charm a side's last free body", fn = function()
    local c = Combat.new(arena(8, 8),
        { unit("character_knight", 1, 1), unit("character_archer", 1, 2) },
        { unit("character_the_suppliant", 2, 1) })
    local knight, archer, supp = c.units[1], c.units[2], c.units[3]

    -- Both free: the touch is the Suppliant's best line and it takes it.
    local plan = AI.plan(c, supp)
    assert(plan and plan.item, "the Suppliant plans an action with the party intact")
    assert(plan.item.id == "weapon_petal_touch",
        "with two free bodies the charm is its best move: got " .. tostring(plan.item.id))

    -- Take the archer, leaving the knight as the party's last. The charm must now be off the table --
    -- and the Suppliant must still act, which is what the second weapon is for.
    Status.apply(c, archer, "status_charm", { duration = 20, applier = supp })
    assert(AI.lastFreeBody(c, "party") == knight, "the knight is the last free body")
    local plan2 = AI.plan(c, supp)
    assert(plan2 and plan2.item, "it still finds something to do rather than standing idle")
    assert(plan2.item.id ~= "weapon_petal_touch",
        "it must not reach for the last free body with a charm: got " .. tostring(plan2.item.id))
    assert(plan2.target == knight or plan2.tx == knight.x,
        "and what it does instead is still aimed at the knight")
end }

-- 3. THE ADDS HAVE MORE THAN ONE THING TO DO. Stated as a floor rather than as an inventory: what
-- matters is that no body whose only action Charms can be left with nothing when that action is
-- refused, which is the shape the rule above would otherwise create.
tests[#tests + 1] = { name = "every body that charms carries an attack that does not", fn = function()
    local charmers = { "character_petal_drift", "character_chorister", "character_the_suppliant",
                       "character_the_hartwood_bride", "character_the_beloved" }
    for _, id in ipairs(charmers) do
        local char = Character.instantiate(id)
        local plain = 0
        for _, item in ipairs(Character.eachItem(char)) do
            local ab = item.activeAbility
            if ab and ab.target == "enemy" then
                local out = Combat.abilityOutput(item)
                local charms = false
                for _, s in ipairs((out and out.statuses) or {}) do
                    if s.id == "status_charm" then charms = true end
                end
                if not charms then plain = plain + 1 end
            end
        end
        assert(plain > 0, id .. " charms with everything it swings -- a body refused a charm by "
            .. "AI.lastFreeBody would have no turn at all. Give it a plain attack.")
    end
end }

-- ...and what those two new actions actually do, named by id so tests/item_coverage_spec.lua counts
-- them as covered rather than as debt.
tests[#tests + 1] = { name = "the Briar Lash strikes at reach and takes nobody", fn = function()
    local c = Combat.new(arena(10, 10), { unit("character_knight", 4, 1) },
        { unit("character_the_suppliant", 2, 1) })
    local supp, knight = c.units[2], c.units[1]
    local lash = Item.instantiate("weapon_briar_lash")
    assert(lash.activeAbility.range == 2, "the lash is the circle's reach option")

    local before = knight.char.stats.health.current
    -- Two tiles away, which the Petal Touch (range 1) could not answer at all.
    assert(Combat.useItem(c, supp, lash, knight.x, knight.y) ~= false, "the lash reaches two tiles")
    assert(knight.char.stats.health.current < before, "and it wounds")
    assert(not Status.has(knight, "status_charm"), "the lash takes nobody -- that is its whole job")
    assert(knight.side == "party", "so the knight is still the party's")
end }

tests[#tests + 1] = { name = "the Beckoning Bough hauls a foe out of the line without taking it", fn = function()
    local c = Combat.new(arena(12, 12), { unit("character_knight", 6, 1) },
        { unit("character_the_suppliant", 2, 1) })
    local supp, knight = c.units[2], c.units[1]
    local bough = Item.instantiate("weapon_beckoning_bough")

    assert(Combat.unitGap(supp, knight) == 4, "the knight starts four tiles off")
    assert(Combat.useItem(c, supp, bough, knight.x, knight.y) ~= false, "the bough reaches four tiles")
    assert(knight.alive, "the haul does not kill from full health")
    assert(Combat.unitGap(supp, knight) == 1, "and it drags the body to the Suppliant's feet: gap is "
        .. tostring(Combat.unitGap(supp, knight)))
    -- The whole point of it as a second beat: the line is broken and the body is still yours, which
    -- is a problem to solve on the turn it happens rather than a turn you do not get.
    assert(not Status.has(knight, "status_charm"), "a haul is not a take")
    assert(knight.side == "party" and knight.control ~= "ai", "the hauled body still takes orders")
end }

-- ---------------------------------------------------------------------------
-- WHAT A FIGHT IS NAMED AFTER IS NOT TAKEN
--
-- `boss = true` is this codebase's word for "this unit is the objective" (models/status.lua,
-- Status.isImmune), and it buys exactly one thing: no route removes the body from the fight it IS --
-- not Charm, not Polymorph, not the three executes. Every general and every mini sin already declared
-- it. The fourteen bodies the sin circles are BUILT around did not, so the shortest answer to a
-- circle's apex was to take it and point it at its own escort.
-- ---------------------------------------------------------------------------

-- The gate itself, proven through a real deliverer rather than through Status.apply, so what is tested
-- is the path a player actually takes: a landed blow that carries Charm.
tests[#tests + 1] = { name = "a boss is not taken by a blow that carries Charm", fn = function()
    local c = Combat.new(arena(8, 8), { unit("character_the_suppliant", 2, 1) },
        { unit("character_petal_drift", 1, 1) })
    local supp, drift = c.units[1], c.units[2]
    assert(supp.char.boss, "the Suppliant is a quest objective")
    local before = supp.char.stats.health.current
    Combat.useItem(c, drift, Item.instantiate("weapon_petal_touch"), supp.x, supp.y)
    assert(supp.char.stats.health.current < before, "the blow still lands and still wounds")
    assert(not Status.has(supp, "status_charm"), "but a quest objective is never turned")
    assert(supp.side == "party", "and it does not change hands")
end }

-- ...and the same refusal reached through the player's own Charm, which is the other end of it.
tests[#tests + 1] = { name = "the Charm ability cannot take a boss either", fn = function()
    local c = Combat.new(arena(8, 8), { unit("character_thief", 1, 1) },
        { unit("character_the_hartwood_bride", 4, 1) })
    local thief, bride = c.units[1], c.units[2]
    -- Wounded to the point where the roll is at its kindest (25% at full health, up to 85% near
    -- death), so a case that passed merely because the spell fizzled would be vanishingly unlikely.
    bride.char.stats.health.current = 1
    for _ = 1, 20 do
        Status.remove(c, bride, "status_charm")
        Combat.useItem(c, thief, Item.instantiate("ability_charm"), bride.x, bride.y)
        thief.char.stats.mana.current = thief.char.stats.mana.max
        assert(not Status.has(bride, "status_charm"), "an apex is never turned by the spell either")
    end
end }

-- THE SET IS DERIVED, NOT RESTATED. A list written out here would be a list somebody adds the eighth
-- circle's apex to and forgets, and the case would stay green over the one body it was written for.
-- So it reads the encounter table: whatever a sin circle deals as its `elite` centrepiece is what has
-- to carry the flag, and a new apex authored next month is covered by existing.
tests[#tests + 1] = { name = "every sin circle's apex is a body the fight cannot lose", fn = function()
    local Encounter = require("models.encounter")
    local Descent = require("models.descent")

    local sins = {}
    for _, id in ipairs(Descent.INFERNO) do sins[id] = true end

    local checked, missing = 0, {}
    for id, def in pairs(Encounter.defs) do
        local sin = id:match("^encounter_([a-z]+)_")
        if sin and sins[sin] and def.kind == "elite" and type(def.composition) == "function" then
            -- A composition is handed the run's context; day 1 is enough to name the lead, which is
            -- always the first entry (the escort is appended after it).
            local list = def.composition({ day = 1, biome = def.biome })
            local lead = list and list[1]
            local char = lead and Character.instantiate(lead)
            if char then
                checked = checked + 1
                if not char.boss then missing[#missing + 1] = id .. " -> " .. lead end
            end
        end
    end

    -- THE CEILING, asserted so the loop above cannot pass by walking nothing. Fourteen is two apexes
    -- per circle across the seven; a derivation that quietly found none would otherwise report a clean
    -- sweep over an empty set, which is the most comfortable way for a guard like this to be a lie.
    assert(checked == 14, "expected 14 sin-circle apexes to check, walked " .. checked
        .. " -- the derivation above has drifted from the encounter table")
    assert(#missing == 0, "a circle's apex can be taken or executed, so the fight can be won by "
        .. "turning the thing it is named after: " .. table.concat(missing, ", "))
end }

return tests
