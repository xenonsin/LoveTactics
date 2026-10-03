-- TURNED TO STONE: a statue in Medusa's garden (character_stone_challenger). It opens the fight Petrified and is
-- held so, the status refreshed at the end of each of its turns, until Medusa's half health cracks it open
-- (trait_her_garden; models/gorgon.lua). `dormantStatue` is the flag the garden reads.
return {
    name = "Turned to Stone",
    description = "Petrified until Medusa falls to half health.",
    dormantStatue = true,
    notAReaction = true,
    onCombatStart = function(ctx) require("models.gorgon").holdStatue(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) require("models.gorgon").holdStatue(ctx.combat, ctx.unit) end,
}
