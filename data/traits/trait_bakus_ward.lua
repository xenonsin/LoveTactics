-- BAKU'S WARD: Baku's trophy rule (data/items/utility/utility_bakus_ward.lua; "Sloth's Bestiary", 2026-10-04).
-- Allies within 2 cannot be put to Sleep, and each sleep turned away heals the bearer.
--
-- Status.allyWard's own shape -- `wardsAllies`, the Sire's Signet's -- held to a reach (`wardsRadius`) and answered
-- (`onWarded`): a sleep refused before it lands shoves nobody and refunds nothing, which a sleep lifted after it
-- landed would have to. The heal is a tenth of the bearer's health a sleep (Baku's own measure of a meal).
local HEAL = 0.1

return {
    name = "Baku's Ward",
    description = "Allies within 2 cannot be put to Sleep. Each sleep you turn away heals you.",
    wardsAllies = { "status_sleep" },
    wardsRadius = 2,
    onWarded = function(combat, bearer)
        if not (bearer and bearer.alive) then return end
        local Combat = require("models.combat")
        local max = Combat.unreservedMax(bearer.char, "health")
        Combat.applyHeal(combat, bearer, math.max(1, math.floor(max * HEAL)))
    end,
}
