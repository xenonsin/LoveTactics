-- Tests for THE ARCHON RACE (2026-10-09, "The Crown's Bestiary", rounds 1-3): Spirit Body, the rule every Archon
-- of the bottom floor is built on, from the author's own note -- "the wisp and the body is separated, and the
-- wisp goes back to the body so you have to stop it".
--
--   Spirit Body   a fallen Archon throws a wisp three tiles clear; the wisp walks home, and ending a turn beside
--                 the body raises it at half health. Once. Stand on the body, kill the wisp, or let the window
--                 close, and the body stays down.
--
-- The bodies that wear the race, and their own rules, are pinned in their line specs.

local Combat = require("models.combat")
local Race = require("models.race")
local Character = require("models.character")
local Trait = require("models.trait")
local Spirit = require("models.spirit")
local AI = require("models.ai")
local Fixture = require("tests.support.fixture")

local unit = Fixture.unit

local function board() return Fixture.new(11, 11) end

-- An Archon-blooded body on the enemy side, its killer beside it, and a second party body standing off.
local function field()
    local a = unit("character_archer", 5, 5, { isolate = "bare", items = { Spirit.ORGAN }, stats = { health = 60 } })
    local killer = unit("character_archer", 5, 6, { isolate = "bare", stats = { health = 100 } })
    local other = unit("character_archer", 1, 1, { isolate = "bare", stats = { health = 100 } })
    local c = Fixture.combat(board(), { killer, other }, { a })
    local e, k, o
    for _, u in ipairs(c.units) do
        if u.side == "enemy" then e = u elseif u.x == 5 and u.y == 6 then k = u else o = u end
    end
    return c, e, k, o
end

local function fell(c, target, attacker)
    target.lastAttacker = attacker
    Combat.dealFlatDamage(c, target, 9999, { "physical" }, nil, attacker)
end

local function wispOf(c, body)
    for _, u in ipairs(c.units) do if u.alive and u.wispOf == body then return u end end
    return nil
end

-- Beside = one step, orthogonally (Combat.unitGap counts steps, so a diagonal is two).
local function besideBody(c, wisp, body)
    for _, d in ipairs({ { 0, -1 }, { 1, 0 }, { -1, 0 }, { 0, 1 } }) do
        local x, y = body.x + d[1], body.y + d[2]
        if Combat.footprintFree(c, 1, 1, x, y) then
            Combat.teleportUnit(c, wisp, x, y)
            return true
        end
    end
    return false
end

return {
    { name = "the archon race grants Spirit Body, is humanoid, and carries no demon's fire or holy line", fn = function()
        local def = Race.get("archon")
        assert(def and def.kind == "humanoid", "the archon race is humanoid")
        local grants = Race.grantsOf("archon")
        assert(Spirit.ORGAN == "utility_archon_spirit", "the organ is utility_archon_spirit")
        assert(grants[1] == "utility_archon_spirit", "the race grants Spirit Body")
        assert(not (def.resist and def.resist.holy), "an Archon has no holy line")
        local wisp = Character.instantiate(Spirit.WISP)
        local found = false
        for _, item in ipairs(Character.eachItem(wisp)) do if item.id == Spirit.ORGAN then found = true end end
        assert(found, "the wisp wears the race too, and is refused its own wisp by the summon guard")
        local homeward = false
        for _, item in ipairs(Character.eachItem(wisp)) do
            if item.id == "utility_wisp_homeward" then homeward = true end
        end
        assert(homeward, "the wisp carries utility_wisp_homeward, its walk home")
    end },

    { name = "a fallen archon lies down and throws a living wisp three tiles clear, away from its killer", fn = function()
        local c, e, k = field()
        fell(c, e, k)
        assert(not e.alive and e.incapacitated, "the body lies down in its window")
        local w = wispOf(c, e)
        assert(w, "a wisp is thrown")
        assert(w.side == "enemy" and not w.summoner, "the wisp is the court's, and nobody's summon")
        assert(math.max(math.abs(w.x - e.x), math.abs(w.y - e.y)) == Spirit.THROW, "three tiles clear")
        assert(math.abs(w.y - k.y) + math.abs(w.x - k.x) > Spirit.THROW, "thrown away from the killer")
        assert(Combat.outcomeFor(c, "party") == nil, "a walking wisp keeps the fight going")
    end },

    { name = "the wisp walks toward its body", fn = function()
        local c, e, k = field()
        fell(c, e, k)
        local w = wispOf(c, e)
        assert(Spirit.goal(c, w) == e, "home is the body")
        assert(Trait.flag(w, "seeksBody"), "the wisp carries the seeksBody flag the gather walk reads")
        assert(AI.posture(w) == AI.POSTURES.gather, "the wisp walks the gather posture")
        -- And the planner really walks it: closer to the body, not toward the company.
        local before = Combat.unitGap(w, e)
        local act = AI.plan(c, w)
        assert(act and act.move, "the wisp moves")
        local after = math.abs(act.move.x - e.x) + math.abs(act.move.y - e.y)
        assert(after < before, "toward its body: " .. before .. " -> " .. after)
    end },

    { name = "ending a turn beside the body raises it at half health, and spends the wisp", fn = function()
        local c, e, k = field()
        fell(c, e, k)
        local w = wispOf(c, e)
        assert(besideBody(c, w, e), "a tile beside the body")
        Trait.onAnyTurnEnd(c, w)
        assert(e.alive, "the body stands")
        local hp = e.char.stats.health
        assert(hp.current == math.floor(Combat.unreservedMax(e.char, "health") * Spirit.RAISE_AT + 0.5),
            "at half health")
        assert(not w.alive, "the wisp went back in")
    end },

    { name = "a body somebody stands on cannot be raised: the wisp waits beside it", fn = function()
        local c, e, k = field()
        fell(c, e, k)
        local w = wispOf(c, e)
        Combat.teleportUnit(c, k, e.x, e.y)
        assert(besideBody(c, w, e), "a tile beside the body")
        Trait.onAnyTurnEnd(c, w)
        assert(not e.alive, "the body stays down while a foe stands on it")
        assert(w.alive, "the wisp waits")
    end },

    { name = "a wisp that is not beside its body yet does nothing at its turn's end", fn = function()
        local c, e, k = field()
        fell(c, e, k)
        local w = wispOf(c, e)
        Trait.onAnyTurnEnd(c, w)
        assert(not e.alive and w.alive, "still walking")
    end },

    { name = "killing the wisp leaves the body down, and its death throws no second wisp", fn = function()
        local c, e, k = field()
        fell(c, e, k)
        local w = wispOf(c, e)
        fell(c, w, k)
        assert(not w.alive, "the wisp is dead")
        assert(not e.alive, "the body stays down")
        local n = 0
        for _, u in ipairs(c.units) do if u.alive and u.wispOf then n = n + 1 end end
        assert(n == 0, "a wisp's death is final")
        assert(Combat.outcomeFor(c, "party") == "win", "with the wisp gone, the fight is won")
    end },

    { name = "a body that went cold sends its wisp away", fn = function()
        local c, e, k = field()
        fell(c, e, k)
        local w = wispOf(c, e)
        e.incapacitated, e.corpse = false, true
        Trait.onAnyTurnEnd(c, w)
        assert(not w.alive, "nothing to go back to")
    end },

    { name = "an archon raised once stays down the second time", fn = function()
        local c, e, k = field()
        fell(c, e, k)
        local w = wispOf(c, e)
        besideBody(c, w, e)
        Trait.onAnyTurnEnd(c, w)
        assert(e.alive, "raised once")
        fell(c, e, k)
        assert(not e.alive and wispOf(c, e) == nil, "no second wisp")
    end },

    -- (What the other goal DOES with a wisp -- onWispTaken -- is pinned by the bodies that take them: the Archon
    -- Duke's line spec and the Hollow Crown's.)
    { name = "a wisp called elsewhere walks there instead, is spent there, and its body stays down", fn = function()
        local c, e, k, o = field()
        fell(c, e, k)
        local w = wispOf(c, e)
        w.wispGoal = o
        assert(Spirit.goal(c, w) == o, "the override goal wins while it stands")
        Combat.teleportUnit(c, w, o.x + 1, o.y)
        Spirit.tryArrive(c, w)
        assert(not w.alive, "the wisp is spent on the other goal")
        assert(not e.alive, "and its body stays down")
    end },
}
