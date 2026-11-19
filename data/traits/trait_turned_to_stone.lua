-- TURNED TO STONE: a statue in Medusa's garden (character_stone_challenger). It opens the fight Petrified and is
-- held so, the status refreshed at the end of each of its turns, until Medusa's half health cracks it open
-- (trait_her_garden; models/gorgon.lua). `dormantStatue` is the flag the garden reads.
--
-- AND IT CARRIES HER GAZE IN ITS FISTS (creature identity pass, 2026-11-19). Once it stepped down it was a plain
-- Stone-Fists bruiser, and its timing was Medusa's, not its own. Now every blow a woken challenger lands puts a
-- Stone on the body it struck (Gorgon.giveStone -- the gaze's own status, so 3 is Petrified for 2 turns by the
-- same rule). Its lever is ORDER: three of them stepping down at her half health can stone a front line in a
-- round, so they are killed before Medusa is finished, or the company keeps its Stone low going into her half.
-- (The row's other option, "impact shatters it outright", was passed over: Medusa's own fight already asks for
-- anything but blades, and the challengers would have repeated that question instead of adding one.)
return {
    name = "Turned to Stone",
    description = "Petrified until Medusa falls to half health. Once woken, each blow it lands gives the target 1 Stone.",
    dormantStatue = true,
    notAReaction = true,
    onCombatStart = function(ctx) require("models.gorgon").holdStatue(ctx.combat, ctx.unit) end,
    onTurnEnd = function(ctx) require("models.gorgon").holdStatue(ctx.combat, ctx.unit) end,
    onBlowLanded = function(ctx)
        local u, t = ctx.unit, ctx.target
        if not (u and u.statueWoken and t and t.alive and t.side ~= u.side) then return end
        require("models.gorgon").giveStone(ctx.combat, t, u)
    end,
}
