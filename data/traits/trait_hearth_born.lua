-- HEARTH-BORN: the Hellhound's rule ("The Crown's Bestiary", slice C, approved 2026-10-09), carried on its organ
-- (data/items/utility/utility_hearth_born.lua). "Its breath leaves fire on the ground. A hellhound standing in fire
-- heals instead of burning and hits for +3."
--
--   * fire on the ground leaves it alone -- hazard_fire reads GatePit.fireproof -- and its planner walks the
--     burning as friendly ground (`welcomes`), so a hound goes to the fire its breath laid;
--   * standing in fire it hits for +3 (a live bonus, so the forecast and the swing agree with the tile it is on:
--     the Goblin Firebrand's Fire-Fed, data/traits/trait_fire_fed.lua, is the same number);
--   * a turn it ends in fire heals it 4, the Burn it would have taken (status_burn's magnitude).
--
-- WET PUTS IT OUT (GatePit.hearthBorn): no heal, no +3, and the fire burns it like anybody. That is the review's own
-- counter -- douse the fire, or make the hound Wet -- and the Blaze's Doused is the precedent for water putting out a
-- body rather than the ground. Wrath's Blaze mends at a turn's end in LAVA (trait_of_the_flows); this is the fire.
local function GatePit() return require("models.gate_and_pit") end

return {
    name = "Hearth-Born",
    description = "Fire on the ground heals you instead of burning you, and you deal 3 more damage standing in it.",
    hearthBorn = true,
    notAReaction = true, -- the fire heals a stunned hound too: this is what it is, not an answer
    live = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return nil end
        if GatePit().hearthBorn(u) and GatePit().inFire(combat, u) then
            return { damage = GatePit().HEARTH_DAMAGE }
        end
        return nil
    end,
    onTurnEnd = function(ctx)
        local u = ctx.unit
        if GatePit().hearthBorn(u) and GatePit().inFire(ctx.combat, u) then
            ctx.heal(u, GatePit().HEARTH_HEAL)
        end
    end,
}
