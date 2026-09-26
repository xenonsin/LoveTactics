-- THE PAYROLL: the rule the Paymaster's disguise hangs on (models/paymaster.lua). The moment the last OTHER
-- dwarf of his crew falls -- a Gilt Wyrm still counts, a skeleton never does -- he turns into what he was all
-- along, and the dwarves of his crew that fell in this fight get up again on his side. Once: the shade he
-- turns into carries no payroll. Killed while his crew still stands, he dies as the Paymaster and nothing
-- rises. Carried on utility_the_payroll; an onAnyDeath broadcast, because the fall it waits on is never his
-- own.
return {
    name = "The Payroll",
    description = "When the last dwarf of your crew falls, the account is settled.",
    onAnyDeath = function(ctx)
        require("models.paymaster").onFall(ctx.combat, ctx.unit, ctx.fallen)
    end,
}
