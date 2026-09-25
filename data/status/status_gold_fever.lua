-- GOLD FEVER: blinded by greed. Reviewed 2026-09-24 as written ("The Dwarves of Greed").
--
-- A dwarf that sees the company loot a coin heap (data/hazards/hazard_coin_heap.lua), or a foe that
-- steps on Fool's Gold (data/hazards/hazard_fools_gold.lua), catches it: it must go for the one it holds
-- responsible -- `taunter`, the same field and the same compulsion as a Taunt (AI.preempt reads both) --
-- at +2 Damage and -4 Defense. It sees nothing else, which is the point: the player's lever is taking a
-- heap to pull a line off its plan, and choosing who eats the charge.
--
-- It ends with the one it is fixed on (onTick below) or when it wears off, and Cure lifts it.
return {
    name = "Gold Fever",
    abbr = "Gold",
    description = "Blinded by greed: driven at whoever took the gold. Increase damage, reduce defense.",
    color = { 0.811, 0.700, 0.335 }, -- badge tint (coin gold, greed's colour)
    duration = 15, -- ~3 turns: long enough to cross a room, not the whole fight
    debuff = true,
    statBonus = { damage = 2, defense = -4 },
    onApply = function(ctx)
        if ctx.applier then ctx.status.taunter = ctx.applier end
    end,
    onTick = function(ctx)
        local tt = ctx.status.taunter
        if not (tt and tt.alive and tt.side ~= ctx.unit.side) then ctx.expire() end
    end,
}
