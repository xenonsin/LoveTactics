-- THE SIRE'S SIGNET: the Sire's drop (data/items/utility/utility_sires_signet.lua). Blood Bond in a company's
-- hands. While the bearer stands, no ally can be Charmed, Seeing Red or in Bloodlust (Status.allyWard reads
-- `wardsAllies`). When the bearer falls, every ally enters Bloodlust for two turns: more damage, and the game
-- takes their turn to bite whoever is nearest.
return {
    name = "Sire's Signet",
    description = "Allies cannot be Charmed, Seeing Red or in Bloodlust. When you fall, they are in Bloodlust for 2 turns.",
    wardsAllies = { "status_charm", "status_seeing_red", "status_bloodlust" },
    notAReaction = true,
    onDeath = function(ctx)
        local u, combat = ctx.unit, ctx.combat
        if not (u and combat) then return end
        local Thirst = require("models.thirst")
        for _, other in ipairs(combat.units or {}) do
            if other.alive and other ~= u and other.side == u.side then Thirst.enterBloodlust(combat, other, 10) end
        end
    end,
}
