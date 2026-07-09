-- Quicken an ally: cut its current initiative in half -- a one-off shove up the turn order, so it
-- acts far sooner than it otherwise would -- and leave it Hasted, halving every ability cost it pays
-- for the duration (data/status/hasted.lua).
--
-- The discount does not extend to RESERVATIONS: a hasted summoner still commits a full quarter of
-- its maximum mana, because that resource is sustaining a creature, not paying a price. See
-- Combat.abilityCost / Combat.abilityReserve.
return {
    name = "Haste",
    description = "Rush an ally up the turn order and halve its ability costs for a while.",
    sprite = "assets/items/ability_haste.png",
    type = "ability",
    tags = { "support", "magical" },
    activeAbility = {
        name = "Haste",
        target = "ally", -- includes the caster
        range = 3,
        support = true,  -- friendly cast: previews green, not red
        speed = 4,
        cost = { stat = "mana", amount = 12 },
        effect = function(fx)
            fx.hasten(fx.target, 0.5)
            fx.applyStatus(fx.target, "hasted")
        end,
    },
}
