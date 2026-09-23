-- A CIRCLE GETS HARDER GOING DOWN, AND ITS ORDINARY FIGHTS SAY WHICH FLOOR THEY BELONG TO.
--
-- Both floors of a circle wear one ground, so a pool keyed on the biome alone dealt the approach's fights
-- again on the seat at a higher level -- the same wolves, twice. An ordinary fight's `rung` is its HOME
-- (models/encounter.lua): never dealt above it, and dealt on the floor under it at Encounter.STRAY_SHARE.
-- Measured through Descent.floorPool over a walked rift, which is the wiring, rather than read back out
-- of the blueprints.

local Descent = require("models.descent")
local Encounter = require("models.encounter")
local Player = require("models.player")

local function walk(seed)
    local player = Player.new()
    local run = Descent.new(player, seed)
    local floors = {}
    for floor = 1, Descent.FLOORS do
        run.floor = floor
        local quest = Descent.floorQuest(run, player)
        local ctx = { depth = floor, rung = Descent.floorWithinCircle(floor),
            biome = quest.map.biome, quest = quest }
        local fights = {}
        for _, e in ipairs(Descent.floorPool(ctx)) do
            if e.kind == "combat" then fights[e.id] = e.weight end
        end
        floors[floor] = { floor = floor, rung = ctx.rung, biome = ctx.biome, fights = fights }
    end
    return floors
end

return {
    { name = "no ordinary fight is dealt above its home floor", fn = function()
        for _, f in ipairs(walk(1)) do
            for id in pairs(f.fights) do
                local home = Encounter.get(id).rung
                if home then
                    assert(f.rung >= home, string.format(
                        "%s is homed on rung %d and dealt on rung %d (%s)", id, home, f.rung, f.biome))
                end
            end
        end
    end },

    { name = "a fight strays onto the floor below its home at the stray share", fn = function()
        local seen = 0
        for _, f in ipairs(walk(1)) do
            for id, w in pairs(f.fights) do
                local def = Encounter.get(id)
                if def.rung and f.rung > def.rung then
                    seen = seen + 1
                    assert(math.abs(w - def.weight * Encounter.STRAY_SHARE) < 1e-9, string.format(
                        "%s strays onto rung %d at %s, not %s", id, f.rung, tostring(w),
                        tostring(def.weight * Encounter.STRAY_SHARE)))
                end
            end
        end
        assert(seen > 0, "no fight strays anywhere -- the rule is measuring nothing")
    end },

    { name = "a floor with fights of its own is mostly its own fights", fn = function()
        -- A stray is the floor above wandering down, and it stays the exception: where a floor has fights
        -- homed on it (or unhomed, which live on both), those outweigh everything that strayed in.
        --
        -- OWED lists the grounds whose deeper floor has NO fight of its own yet, and so deals nothing but
        -- strays -- the same fights as the floor above, only rarer. It is a ratchet: a ground on it must
        -- still be owed, so the entry is deleted the day that floor gets its first fight.
        local OWED = {}
        local owedSeen = {}
        for _, f in ipairs(walk(1)) do
            local own, stray = 0, 0
            for id, w in pairs(f.fights) do
                local home = Encounter.get(id).rung
                if home and home < f.rung then stray = stray + w else own = own + w end
            end
            if own == 0 and stray > 0 then
                assert(OWED[f.biome], string.format(
                    "floor %d (%s, rung %d) deals only strays -- it has no fight of its own",
                    f.floor or 0, f.biome, f.rung))
                owedSeen[f.biome] = true
            elseif own > 0 then
                assert(stray < own, string.format(
                    "%s rung %d: strays weigh %.2f against its own %.2f", f.biome, f.rung, stray, own))
            end
        end
        for biome in pairs(OWED) do
            assert(owedSeen[biome], biome .. " is listed as owed floor fights and no longer is -- "
                .. "delete it from OWED")
        end
    end },
}
