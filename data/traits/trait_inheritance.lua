-- INHERITANCE: the dwarf's racial rule, carried on Stout (data/items/utility/utility_stout.lua).
-- Reviewed 2026-09-24 as written: "the last dwarf standing is the richest".
--
-- WHEN A DWARF FALLS its Share passes on -- every Share it had already taken up, plus its own -- and so
-- do its coffer and its Dragon-Sickness:
--   * to the HEIR OF ALL wherever he stands on the board -- the Hoard-Thane (trait_heir_of_all), or the
--     dwarf that picked up his fallen King's Jewel (`unit.heirOfAll`, data/hazards/hazard_kings_jewel.lua);
--   * otherwise to the NEAREST dwarf within HEIR_REACH tiles (ties broken by board order, which is
--     deterministic).
-- With no heir, the coffer spills as bounty -- the company's on a win (Combat.bounty).
--
-- UNCAPPED, WITH THE MOVEMENT FLOORED (round 2: "Floor the movement"). The weight is stamped onto the
-- heir's instance rather than scaled off the blueprint: every Share adds its damage and defense, and the
-- legs stop one short of the heir's own unburdened pace, never below 1.
--
-- KILL ORDER IS THE PUZZLE. Bring the line down together, kill the one nobody can reach, or face a
-- slow, fat, rich last heir. Gold a dwarf SPENT (Grease Palms) is gone for good, which is the other half:
-- a long fight costs the purse the company was going to be paid out of.
--
-- On the DEATH hook of the one who falls, not a broadcast, so a body that is not a dwarf never pays the
-- scan. Summons count as kin (a hired hand is a dwarf too), and a heir is always a LIVING dwarf on the
-- faller's own side -- a charmed dwarf fights for its charmer and inherits nothing from its old line.
local HEIR_REACH = 3

return {
    name = "Inheritance",
    description = "When you fall, your Share, your coffer and your Dragon-Sickness pass to the nearest dwarf within 3.",
    onDeath = function(ctx)
        local combat, unit = ctx.combat, ctx.unit
        if not (combat and unit) then return end
        local Trait = require("models.trait")
        local Status = require("models.status")
        local Combat = require("models.combat")

        local heir, best
        for _, u in ipairs(combat.units or {}) do
            if u ~= unit and u.alive and u.side == unit.side and Trait.has(u, "trait_inheritance") then
                if u.heirOfAll or Trait.flag(u, "heirOfAll") then heir = u break end
                local d = Combat.unitGap(unit, u)
                if d <= HEIR_REACH and (not best or d < best) then heir, best = u, d end
            end
        end

        local gold = unit.coffer or 0
        unit.coffer = 0
        local name = (unit.char and unit.char.name) or "It"

        if heir then
            local shares = Status.stacksOf(unit, "status_inheritance") + 1
            local held = Status.get(heir, "status_inheritance")
            local total = (held and held.magnitude or 0) + shares
            local cut = held and held.statBonus and -(held.statBonus.movement or 0) or 0
            local pace = Combat.flatStat(heir, "movement") + cut
            local line = { damage = 2 * total, defense = 2 * total,
                           movement = -math.min(total, math.max(0, pace - 1)) }
            Status.apply(combat, heir, "status_inheritance", { magnitude = shares, statBonus = line })
            local sick = Status.stacksOf(unit, "status_dragon_sickness")
            if sick > 0 then Status.apply(combat, heir, "status_dragon_sickness", { magnitude = sick }) end
            if gold > 0 and heir.side ~= "party" then heir.coffer = (heir.coffer or 0) + gold end
            ctx.log("action", string.format("%s takes up %s's Share.",
                (heir.char and heir.char.name) or "A kinsman", name), { heir, unit })
        elseif gold > 0 and unit.side ~= "party" then
            Combat.bounty(combat, gold)
            ctx.log("action", string.format("%s spills %d gold.", name, gold), unit)
        end
    end,
}
