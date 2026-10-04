-- POPPY CENSER: the Poppy-Moth's trophy rule (data/items/utility/utility_poppy_censer.lua; "Sloth's Bestiary",
-- 2026-10-04). When the bearer is struck, the foes beside it fall Asleep; then it rests for 3 turns.
--
-- A REFLEX, unlike the moth's dust: a charm in a company's hand is swung by the hand, so a bearer the cloud has
-- already put under does not answer. Foes only -- the company is not a moth and its line is not its cloud. The
-- rest is a cooldown keyed on this trait's own id, so the grid slot reads as spent while it rests.
local REST = 15 -- three turns at Status.TICKS_PER_TURN

return {
    name = "Poppy Censer",
    description = "When you are struck, foes beside you fall Asleep. Then it rests for 3 turns.",
    cooldown = REST,
    onDamaged = function(ctx)
        if not (ctx.unit and ctx.unit.alive) then return end
        if ctx.onCooldown("trait_poppy_censer") then return end
        if require("models.sloth_dreamers").burst(ctx.combat, ctx.unit, true) > 0 then
            ctx.setCooldown("trait_poppy_censer", ctx.param("cooldown", REST))
        end
    end,
}
