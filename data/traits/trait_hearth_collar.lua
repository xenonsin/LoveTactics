-- THE HELLHOUND COLLAR: Hearth-Born handed to a Beastmaster's animals ("The Crown's Bestiary", slice C; carried on
-- data/items/utility/utility_hellhound_collar.lua). "Your beasts and summons are unharmed by fire on the ground and
-- heal 3 standing in it."
--
-- "Your beasts and summons" is every body the bearer SUMMONED (`summoner`), which is how a beastmaster fields an
-- animal at all -- the Second Leash counts its pack the same way. The fire half is read by hazard_fire through
-- GatePit.fireproof; the heal is a turn the summon ends in fire, heard here as somebody else's turn ending. No +3:
-- the hound's damage is the hound's.
local function GatePit() return require("models.gate_and_pit") end

return {
    name = "Hellhound Collar",
    description = "Your summons are unharmed by fire on the ground and heal 3 standing in it.",
    hearthCollar = true,
    notAReaction = true,
    onAnyTurnEnd = function(ctx)
        local a = ctx.actor
        if not (a and a.alive and a.summoner == ctx.unit) then return end
        if GatePit().inFire(ctx.combat, a) then ctx.heal(a, GatePit().COLLAR_HEAL) end
    end,
}
