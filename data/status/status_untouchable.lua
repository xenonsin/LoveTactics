-- UNTOUCHABLE: the Elf Bladedancer's reflex worn off the Mask of Champions (data/traits/trait_mask_of_champions.lua).
-- Reviewed 2026-10-01..03 ("Envy's Bestiary", round 2).
--
-- The Bladedancer's own Untouchable is a trait gated on the elf's Unblemished (data/traits/trait_untouchable.lua);
-- a person wearing the mask is not an elf and is never Unblemished, so the reflex is carried here as the
-- condition itself: every attack that rolls to hit is evaded (Combat.hitChance answers 0) until the first wound,
-- and a mask that has been marred does not put it on again this fight (`untouchableMarred`). Only what does not
-- ask the dice can mar it -- a spell, an area, a hazard -- exactly as with the elf.
return {
    name = "Untouchable",
    abbr = "Untc",
    description = "Untouchable: evade every attack that rolls to hit, until wounded.",
    color = { 0.900, 0.860, 0.620 }, -- badge tint (the elf's pale gold)
    duration = math.huge,
    hideDuration = true,
    onDamaged = function(ctx)
        if (ctx.amount or 0) > 0 then
            ctx.unit.untouchableMarred = true
            ctx.expire()
        end
    end,
}
