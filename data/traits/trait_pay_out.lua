-- PAY OUT: lays status_pay_out on the Paymaster for the whole fight, whose turn-start hook throws a coin heap
-- beside one of his crew (models/paymaster.lua). Carried on utility_pay_out.
return {
    name = "Pay Out",
    description = "At the start of your turn, a heap of gold lands within 2 of a dwarf of your crew.",
    onCombatStart = function(ctx)
        require("models.status").apply(ctx.combat, ctx.unit, "status_pay_out")
    end,
}
