-- PAY OUT: the Paymaster's wages (reviewed 2026-09-25/26, "The Paymaster"). At the start of each of his turns
-- a coin heap lands on an open tile within 2 of a living dwarf of his crew -- the gold Vesh salted the deep
-- seams with, thrown where the greedy will find it (models/paymaster.lua). Laid for the whole fight by
-- trait_pay_out, and lifted by the reveal: once he has turned there is nobody left to pay.
--
-- A BADGE AND NOT A SECRET. The company can read that he pays; what it has to notice for itself is that he
-- never pockets a heap, which is the fight's only tell.
return {
    name = "Pay Out",
    abbr = "Pay",
    description = "At the start of his turn, a heap of gold lands within 2 of one of his crew.",
    color = { 0.886, 0.700, 0.250 }, -- the gold he throws
    duration = math.huge,
    hideDuration = true,
    hideLog = true,
    onTurnStart = function(ctx)
        if not (ctx.combat and ctx.unit and ctx.unit.alive) then return end
        require("models.paymaster").turnStart(ctx.combat, ctx.unit)
    end,
}
