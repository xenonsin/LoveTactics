-- TWO FOR ONE: the Lernaean Hydra's rule (data/items/utility/utility_two_for_one.lua, models/lerna.lua). Approved
-- 2026-10-09 ("The Crown's Bestiary", slice E): "It opens with three heads, one bite each. An edge (slash) blow
-- that crosses a tenth of its bar takes a head, and two grow back (up to 6). Fire or Burn on it cauterises: heads
-- stop growing for 2 turns."
--
-- `notAReaction`: the heads are what the body IS, not an answer to the blow, so a stunned hydra still grows them
-- (models/trait.lua's argument about scripts).
return {
    name = "Two for One",
    description = "Opens with three heads. A big slash takes one and two grow back; fire stops the growing.",
    notAReaction = true,
    onCombatStart = function(ctx)
        require("models.lerna").open(ctx.combat, ctx.unit)
    end,
    onDamaged = function(ctx)
        require("models.lerna").struck(ctx.combat, ctx.unit, ctx.amount, ctx.tags)
    end,
    onStatusApplied = function(ctx)
        if ctx.role == "recipient" and ctx.status and ctx.status.id == "status_burn" then
            require("models.lerna").sear(ctx.combat, ctx.unit)
        end
    end,
}
