-- BLOODLUST: a vampire whose Thirst ran out (models/thirst.lua), and the company under a fallen Sire's Signet.
-- Wrath's vampires (2026-09-26): "Frenzy" is taken by an axe keyword, so the state is Bloodlust.
--
-- More damage (the applier hands in +30% of the body's own Damage) and +1 Movement. It may use only a weapon
-- (Combat.itemBlockReason), and it bites the NEAREST body, whichever side (AI.preempt -> Thirst.plan; the side
-- check is waived in Combat.useItem). Drawing blood from a living body ends it.
--
-- ON A COMPANY BODY THE GAME TAKES THE TURN, the way Seeing Red and Charm do: control is stashed and handed to
-- the AI for as long as this lasts. A debuff, so a Cure lifts it and the Signet can refuse it.
return {
    name = "Bloodlust",
    abbr = "Lust",
    description = "Bloodlust: more damage and movement. Uses only a weapon, on the nearest body, friend or foe.",
    color = { 0.820, 0.060, 0.120 }, -- badge tint (arterial)
    duration = math.huge,
    hideDuration = true,
    debuff = true,
    onApply = function(ctx)
        local u = ctx.unit
        if u.side ~= "party" then return end
        if u._bloodlustControl == nil then u._bloodlustControl = u.control or false end
        u.control = "ai"
    end,
    onExpire = function(ctx)
        local u = ctx.unit
        if u._bloodlustControl ~= nil then
            u.control = u._bloodlustControl or nil
            u._bloodlustControl = nil
        end
    end,
}
