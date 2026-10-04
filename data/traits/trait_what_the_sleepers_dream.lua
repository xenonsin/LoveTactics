-- WHAT THE SLEEPERS DREAM: Desidia's, and the Nightmare Lantern's that drops off her ("Sloth's Bestiary", slice G,
-- approved word for word; models/desidia.lua). At the start of each of the bearer's rounds, each of its foes that
-- is asleep dreams, and its nightmare stands up on the bearer's side: a shade with that body's face and kit
-- (Summon.copyOf, wounds and all). The shade lasts until the sleeper wakes.
--
--   onTurnStart      shades whose sleepers have woken go, then every sleeper without one dreams one up
--   onAnyTurnStart   \  a sleeper woken on somebody else's turn takes its shade with it by the next beat
--   onAnyTurnEnd     /
--
-- A shade is the bearer's summon, so it falls with the bearer too.
local function D() return require("models.desidia") end

return {
    name = "What the Sleepers Dream",
    description = "Each round, every sleeping foe dreams a shade of itself onto your side. It lasts until the sleeper wakes.",
    notAReaction = true,
    onTurnStart = function(ctx)
        D().reapShades(ctx.combat, ctx.unit)
        D().dream(ctx.combat, ctx.unit)
    end,
    onAnyTurnStart = function(ctx) D().reapShades(ctx.combat, ctx.unit) end,
    onAnyTurnEnd = function(ctx) D().reapShades(ctx.combat, ctx.unit) end,
}
