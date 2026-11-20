-- THE CROSSINGS' DEEDS (data/class_requirements.lua, the counters in models/combat.lua and
-- models/hazard.lua): every crossing asks for one act that needs both its parents at once, ADDED to its
-- level gate. Held here: every crossing carries a deed, every deed is a counter something in the models
-- actually tallies, and the counters fire on the act they name -- driven through real blows and real
-- statuses where a fixture can stand the act up, and through the seam itself where it cannot.

local Class = require("models.class")
local Combat = require("models.combat")
local Status = require("models.status")
local Hazard = require("models.hazard")
local Character = require("models.character")
local Fixture = require("tests.support.fixture")

local function read(path)
    local f = assert(io.open(path, "r"), "cannot open " .. path)
    local s = f:read("*a")
    f:close()
    return s
end

-- A party hero and a foe beside it, the foe at 5 health of 100 so one blow fells it.
local function duel(heroId, foeId, weapon)
    local hero = Fixture.unit(heroId, 2, 2, { isolate = "bare", items = { weapon } })
    local foe = Fixture.unit(foeId, 3, 2, { isolate = "bare", stats = { health = 100, defense = 0 } })
    foe.char.stats.health.current = 5
    local c = Fixture.combat(Fixture.new(8, 8), { hero }, { foe })
    local h, f
    for _, u in ipairs(c.units) do
        if u.char == hero.char then h = u elseif u.char == foe.char then f = u end
    end
    return c, h, f
end

return {
    { name = "every crossing carries a deed, and the gate still asks a subclass of each", fn = function()
        local crossings = 0
        for id in pairs(Class.defs) do
            if Class.isPlayable(id) and not Class.isStarter(id) and Class.arity(id) >= 2 then
                crossings = crossings + 1
                local req = Class.requirementOf(id)
                assert(req, id .. " has no deed")
                assert(type(req.deed) == "string" and req.count > 0 and type(req.label) == "string",
                    id .. ": a malformed requirement")
            end
        end
        assert(crossings == 21, "21 crossings, found " .. crossings)
        -- The deed is ADDED: a body with both parents' levels and the deed, but no subclass, is still shut.
        local a = Character.instantiate("character_avatar")
        a.technique = { fighter = Class.classLevelCost(20), priest = Class.classLevelCost(20) }
        a.unlocked = { novice = true, fighter = true, priest = true }
        a.deeds = { killHoly = 99 }
        assert(Class.deedMet(a, "crusader"), "the deed is met")
        assert(not Class.levelGateMet(a, "crusader"), "and the subclass half of the gate still stands")
    end },

    { name = "every deed a class asks for is a counter the models actually tally", fn = function()
        local src = read("models/combat.lua") .. read("models/hazard.lua") .. read("models/trap.lua")
        for id, req in pairs(Class.requirements) do
            assert(src:find('"' .. req.deed .. '"', 1, true),
                id .. " asks for '" .. req.deed .. "', which nothing in the models tallies")
        end
    end },

    { name = "a melee kill on the undead is the Crusader's; on a taunted, rooted, blessed foe, three more", fn = function()
        local c, h, f = duel("character_knight", "character_ghoul", "weapon_iron_sword")
        assert(Character.isUndead(f.char), "the ghoul is undead")
        Status.apply(c, f, "status_taunt", { applier = h })
        Status.apply(c, f, "status_root", { applier = h })
        Status.apply(c, f, "status_heroism", { applier = f })
        assert(Fixture.strike(c, h, f, "weapon_iron_sword"), "the blow is struck")
        assert(not f.alive or f.incapacitated, "the foe falls")
        assert(Combat.tallyCount(h, "killHoly") == 1, "a melee kill on the undead is holy work")
        assert(Combat.tallyCount(h, "killTaunted") == 1, "it was taunted onto the striker")
        assert(Combat.tallyCount(h, "killRooted") == 1, "it was Rooted")
        assert(Combat.tallyCount(h, "killBlessed") == 1, "it wore a boon")
        assert(Combat.tallyCount(h, "killCursed") == 0, "the striker carried no hex")
    end },

    { name = "a kill with a hex in the grid is the Shaman's; a kill after a long walk the Skirmisher's", fn = function()
        local c, h, f = duel("character_knight", "character_bandit", "weapon_iron_sword")
        local sword = Fixture.itemNamed(h.char, "weapon_iron_sword")
        sword.curse = "curse_dead_weight"
        assert(Combat.carriesCurse(h), "a cursed piece is in the grid")
        Fixture.openTurn(c, h)
        c.turn.walked = 3
        assert(Combat.useItem(c, h, sword, f.x, f.y), "the blow is struck")
        assert(Combat.tallyCount(h, "killCursed") == 1, "felled while carrying a hex")
        assert(Combat.tallyCount(h, "killMoving") == 1, "felled on a turn that walked three tiles")
        assert(Combat.tallyCount(h, "killHoly") == 0, "a bandit is neither demon nor undead")
    end },

    { name = "an innate nature is not a boon: an affix or an immunity blesses nobody", fn = function()
        local c, h, f = duel("character_knight", "character_bandit", "weapon_iron_sword")
        assert(not Combat.carriesBoon(f), "a bare bandit wears nothing")
        Status.apply(c, f, "status_immune_fire", {})
        assert(not Combat.carriesBoon(f), "an immunity is what it is, not a blessing")
        Status.apply(c, f, "status_poison", { applier = h })
        assert(not Combat.carriesBoon(f), "a debuff is not a boon")
        Status.apply(c, f, "status_heroism", { applier = f })
        assert(Combat.carriesBoon(f), "Heroism is")
    end },

    { name = "a poison laid from the next tile is the Plague Knight's; a Sunder the Vanguard's", fn = function()
        local c, h, f = duel("character_knight", "character_bandit", "weapon_iron_sword")
        Combat.tallyStatusDeed(h, f, "status_poison", {}, f.side)
        assert(Combat.tallyCount(h, "poisonBeside") == 1, "poisoned from beside it")
        f.x = 6
        Combat.tallyStatusDeed(h, f, "status_poison", {}, f.side)
        assert(Combat.tallyCount(h, "poisonBeside") == 1, "but not from across the board")
        assert(Combat.tallyCount(h, "poisonApplied") == 2, "while the Poisoner's counts both")
        Combat.tallyStatusDeed(h, f, "status_sundered", {}, f.side)
        assert(Combat.tallyCount(h, "sunderApplied") == 1, "a Sunder landed")
    end },

    { name = "a Root or Halt counts for the Warden only while the foe is walking", fn = function()
        local _, h, f = duel("character_knight", "character_bandit", "weapon_iron_sword")
        Combat.tallyStopDeed(h, f, "status_root", {})
        assert(Combat.tallyCount(h, "stoppedMidWalk") == 0, "a foe standing still was not stopped")
        f.walking = true
        Combat.tallyStopDeed(h, f, "status_root", {})
        Combat.tallyStopDeed(h, f, "status_halted", {})
        Combat.tallyStopDeed(h, f, "status_poison", {})
        assert(Combat.tallyCount(h, "stoppedMidWalk") == 2, "a Root and a Halt mid-walk, and nothing else")
        Combat.tallyStopDeed(h, f, "status_root", nil)
        assert(Combat.tallyCount(h, "stoppedMidWalk") == 2, "a status that did not land stops nobody")
    end },

    { name = "a walk marks its walker only for as long as it lasts", fn = function()
        local c, h = duel("character_knight", "character_bandit", "weapon_iron_sword")
        Fixture.openTurn(c, h)
        assert(Combat.moveUnit(c, h, 2, 5), "the knight walks three tiles")
        assert(h.walking == nil, "and is no longer walking once it arrives")
        assert(c.turn.walked == 3, "three tiles on its own feet this turn")
    end },

    { name = "breaking a foe's wind-up on your turn is the Spellbreaker's; killing it is not", fn = function()
        local c, h, f = duel("character_knight", "character_bandit", "weapon_iron_sword")
        Fixture.openTurn(c, h)
        f.channel = { item = {}, ab = {} }
        assert(Combat.interruptChannel(c, f, "stunned"), "the channel breaks")
        assert(Combat.tallyCount(h, "channelBroken") == 1, "on the breaker's turn, banked on the breaker")
        f.channel = { item = {}, ab = {} }
        Combat.interruptChannel(c, f, "death")
        assert(Combat.tallyCount(h, "channelBroken") == 1, "a death is not a broken spell")
    end },

    { name = "the Duelist's streak is counted in the striker's own turns", fn = function()
        local c, h, f = duel("character_knight", "character_bandit", "weapon_iron_sword")
        local other = { side = f.side }
        local function turnOn(target)
            Fixture.openTurn(c, h)
            Combat.tally(h, "turnTaken", 1)
            Combat.noteDuel(c, h, target)
            Combat.noteDuel(c, h, target) -- a second blow in one turn is the same turn
        end
        turnOn(f); turnOn(f)
        assert(Combat.tallyCount(h, "duelHeld") == 0, "two turns is not yet a duel")
        turnOn(f)
        assert(Combat.tallyCount(h, "duelHeld") == 1, "three turns running on one foe is")
        turnOn(f); turnOn(other); turnOn(f); turnOn(f)
        assert(Combat.tallyCount(h, "duelHeld") == 1, "a turn on somebody else starts it over")
        turnOn(f)
        assert(Combat.tallyCount(h, "duelHeld") == 2, "and three more banks the next")
    end },

    { name = "the Herbalist banks one fight that both poisoned and healed with consumables", fn = function()
        local u = {}
        Combat.noteBrew(u, "poison")
        Combat.noteBrew(u, "poison")
        assert(Combat.tallyCount(u, "brewedBothWays") == 0, "poison alone is half of it")
        Combat.noteBrew(u, "heal")
        Combat.noteBrew(u, "heal")
        Combat.noteBrew(u, "poison")
        assert(Combat.tallyCount(u, "brewedBothWays") == 1, "both ways, once a fight")
    end },

    { name = "a potion poured for the ally beside you is the Apothecary's and the Paladin's, not the Totemist's", fn = function()
        local healer = Fixture.unit("character_knight", 2, 2, { isolate = "bare", items = { "consumable_healing_potion" } })
        local ally = Fixture.unit("character_knight", 3, 2, { isolate = "bare", stats = { health = 200 } })
        ally.char.stats.health.current = 50
        local foe = Fixture.unit("character_bandit", 7, 7, { isolate = "bare" })
        local c = Fixture.combat(Fixture.new(8, 8), { healer, ally }, { foe })
        local h, a
        for _, u in ipairs(c.units) do
            if u.char == healer.char then h = u elseif u.char == ally.char then a = u end
        end
        assert(Fixture.strike(c, h, a, "consumable_healing_potion"), "the potion is poured")
        local healed = Combat.tallyCount(h, "healGiven")
        assert(healed > 0, "the ally was healed")
        assert(Combat.tallyCount(h, "healByDraught") == healed, "every point of it by a consumable")
        assert(Combat.tallyCount(h, "healBeside") == healed, "on the next tile")
        assert(Combat.tallyCount(h, "healFromAfar") == 0, "and not from afar")
        assert(h.brewed and h.brewed.heal, "the Herbalist's heal half is marked")
    end },

    { name = "a heal CAST at a distant ally is not the Totemist's: only ground, a summon or a throw is", fn = function()
        local healer = Fixture.unit("character_xin", 2, 2, { isolate = "bare", items = { "ability_heal" },
            stats = { mana = 200 } })
        local ally = Fixture.unit("character_knight", 5, 2, { isolate = "bare", stats = { health = 200 } })
        ally.char.stats.health.current = 50
        local foe = Fixture.unit("character_bandit", 7, 7, { isolate = "bare" })
        local c = Fixture.combat(Fixture.new(8, 8), { healer, ally }, { foe })
        local h, a
        for _, u in ipairs(c.units) do
            if u.char == healer.char then h = u elseif u.char == ally.char then a = u end
        end
        assert(Fixture.strike(c, h, a, "ability_heal"), "the heal is cast three tiles off")
        assert(Combat.tallyCount(h, "healGiven") > 0, "the ally was healed")
        assert(Combat.tallyCount(h, "healFromAfar") == 0, "but by the healer's own cast")
        assert(Combat.tallyCount(h, "healBeside") == 0 and Combat.tallyCount(h, "healByDraught") == 0,
            "and neither beside it nor from a bottle")
    end },

    { name = "a stat-raising draught drunk beside a foe is the Warbrewer's, and only beside one", fn = function()
        local function drink(foeX)
            local brewer = Fixture.unit("character_knight", 2, 2, { isolate = "bare",
                items = { "consumable_elixir_of_heroism" } })
            local foe = Fixture.unit("character_bandit", foeX, 2, { isolate = "bare" })
            local c = Fixture.combat(Fixture.new(8, 8), { brewer }, { foe })
            local b
            for _, u in ipairs(c.units) do if u.char == brewer.char then b = u end end
            assert(Fixture.strike(c, b, b, "consumable_elixir_of_heroism"), "the elixir is drunk")
            assert(Status.has(b, "status_heroism"), "and lands")
            return Combat.tallyCount(b, "draughtInMelee")
        end
        assert(drink(3) == 1, "beside a foe")
        assert(drink(7) == 0, "not across the board")
    end },

    { name = "ground credits whoever laid it, and an owner stands in for a layer", fn = function()
        assert(Hazard.maker({ laidBy = "a", owner = "b" }) == "a", "the layer first")
        assert(Hazard.maker({ owner = "b" }) == "b", "else the body holding it open")
        assert(Hazard.maker({}) == nil and Hazard.maker(nil) == nil, "weather nobody laid has no maker")
    end },
}
