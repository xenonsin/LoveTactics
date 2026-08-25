-- Tests for models/wound.lua -- the meter that took over from killing people.
--
-- A descent briefly lost a body outright when its downed count ran out. It does not any more: the only
-- thing that ever costs a body is a WIPE, and even then they lie where they fell to be fetched. What
-- carries the stake instead is the wound, which now has two halves -- a RESERVE on the body's health
-- pool, and DEBUFFS that stack as they accumulate -- and both are pinned here.

local Character = require("models.character")
local Combat = require("models.combat")
local Descent = require("models.descent")
local Player = require("models.player")
local Wound = require("models.wound")

local function company(n)
    local ids = { "character_knight", "character_archer", "character_rogue", "character_mage" }
    local chars = {}
    for i = 1, (n or 1) do chars[i] = Character.instantiate(ids[i]) end
    return Descent.newProfile(chars)
end

return {
    { name = "a wound reserves part of the body, in the fight as well as out of it", fn = function()
        -- THE HALF THAT IS NEW. It used to cap only the hub's REFILL, so a wounded body started short
        -- and could then be healed straight back to full by anything on the board -- which said the
        -- injury was real and immediately showed it was not. It is a reservation now: the pool is the
        -- size it always was and part of it cannot be reached, by a potion or by anything else.
        local p = company(1)
        local char = p.roster[1]
        local whole = Combat.unreservedMax(char, "health")

        Wound.inflict(p, { char })
        local hurt = Combat.unreservedMax(char, "health")
        assert(hurt < whole, "one wound takes the ceiling down: " .. hurt .. " vs " .. whole)

        Wound.inflict(p, { char })
        assert(Combat.unreservedMax(char, "health") < hurt, "and two take it further")

        -- `max` itself is NEVER touched. That is the whole reason this is a reservation rather than a
        -- penalty on the ceiling: max health is derived from level, growth and gear, so a wound written
        -- into it would have to be un-written exactly on the way out and would fight every
        -- recomputation in between.
        assert(char.stats.health.max == p.roster[1].stats.health.max, "the pool is the size it was")
    end },

    { name = "the reserve stops at a floor, so a body is never unfieldable", fn = function()
        -- A descent has no bench. A wound deep enough to make somebody not worth fielding takes a
        -- quarter of the company off the board as surely as killing them would, which is the exact
        -- thing this meter exists instead of.
        local p = company(1)
        local char = p.roster[1]
        for _ = 1, 12 do Wound.inflict(p, { char }) end
        assert(Wound.healShare(p, char.id) == Wound.FLOOR, "twelve wounds bottom out at the floor")
        assert(Combat.unreservedMax(char, "health") >= math.floor(char.stats.health.max * Wound.FLOOR) - 1,
            "and the body keeps at least the floor's share of itself")
    end },

    { name = "the debuffs stack with the count, and the first wound is the reserve alone", fn = function()
        local p = company(1)
        local char = p.roster[1]

        assert(#Wound.combatEffects(p, char.id) == 0, "an unhurt body fights under nothing")

        Wound.inflict(p, { char })
        assert(#Wound.combatEffects(p, char.id) == 0,
            "one wound is the reserve and nothing else -- the first fall should cost, not start a spiral")

        Wound.inflict(p, { char })
        local two = Wound.combatEffects(p, char.id)
        assert(#two == 1 and two[1].id == "status_wounded", "the second wound brings Wounded")
        assert(two[1].opts.magnitude < 0, "which is a penalty, not a gift")

        Wound.inflict(p, { char })
        local three = Wound.combatEffects(p, char.id)
        assert(#three == 2, "the third brings a second debuff on top")
        assert(three[1].opts.magnitude < two[1].opts.magnitude, "and Wounded bites harder than it did")
        local ids = {}
        for _, e in ipairs(three) do ids[e.id] = true end
        assert(ids["status_cripple"], "the second one is Cripple: a hurt body moves worse")
    end },

    { name = "every effect a wound applies names a status that exists and lasts the fight", fn = function()
        -- A wound is a condition the body ARRIVED with, not a tempo cost measured in ticks -- so it must
        -- not tick away mid-battle and leave a wounded veteran fighting whole. And a typo'd id would be
        -- an assert inside Status.apply, at the worst possible moment: the opening of a fight.
        local Status = require("models.status")
        local p = company(1)
        local char = p.roster[1]
        for _ = 1, 5 do Wound.inflict(p, { char }) end
        local effects = Wound.combatEffects(p, char.id)
        assert(#effects > 0, "a body this hurt fights under something")
        for _, e in ipairs(effects) do
            assert(Status.defs[e.id], e.id .. " is not a status blueprint")
            assert((e.opts.duration or 0) > 500, e.id .. " would tick away inside a fight")
        end
    end },

    { name = "setting the bone gives the body back, reserve and debuffs alike", fn = function()
        local p = company(1)
        local char = p.roster[1]
        local whole = Combat.unreservedMax(char, "health")
        for _ = 1, 3 do Wound.inflict(p, { char }) end
        assert(#Wound.combatEffects(p, char.id) == 2, "precondition: three wounds, two debuffs")

        -- Three days in a bed, which is what three wounds costs now (tests/wound_rest_spec.lua).
        p.gold = 10000
        require("models.gate").lodge(p, char.id)
        for _ = 1, 3 do Wound.rest(p) end
        require("models.gate").dischargeMended(p)

        assert(Wound.count(p, char.id) == 0, "the wounds are gone")
        assert(#Wound.combatEffects(p, char.id) == 0, "and so are the debuffs")
        assert(Combat.unreservedMax(char, "health") == whole, "and the body is its whole size again")
    end },

    { name = "a night at the inn clears the whole ledger at once", fn = function()
        -- The descent's mender, against the campaign's per-wound bill. A four-body company with no bench
        -- cannot field around a wounded member, so pricing each wound separately would just mean a
        -- player who could not afford the second one stopped descending.
        local Gate = require("models.gate")
        local p = company(2)
        p.gold = 1000
        for _ = 1, 3 do Wound.inflict(p, { p.roster[1], p.roster[2] }) end
        assert(Gate.rest(p), "the room is paid for")
        for _, char in ipairs(p.roster) do
            assert(Wound.count(p, char.id) == 0, (char.id) .. " is still carrying wounds")
            assert(Combat.unreservedMax(char, "health") == char.stats.health.max,
                (char.id) .. " did not get their whole body back")
            assert(char.stats.health.current == char.stats.health.max, (char.id) .. " is not whole")
        end
    end },

    { name = "the reserve is stamped onto bodies, never read off the player by combat", fn = function()
        -- Wounds are keyed by char id on the PLAYER; Combat.unreservedMax takes a CHARACTER and no
        -- player, which is right -- it is asked about summons, enemies and duel rosters that have no
        -- player behind them at all. So the share arrives on the character the way `maxBonus` does.
        local p = company(1)
        local char = p.roster[1]
        Wound.inflict(p, { char })
        assert((char.woundShare or 0) > 0, "the share is written onto the body")

        -- An unwounded body carries no field at all, so the fast path is a single nil test.
        local clean = company(1)
        assert(clean.roster[1].woundShare == nil, "an unhurt body carries no share")

        -- And a body with no player behind it is untouched by any of this.
        local loose = Character.instantiate("character_bandit")
        assert(Combat.unreservedMax(loose, "health") == loose.stats.health.max,
            "a body with no player is not wounded by association")
    end },
}
