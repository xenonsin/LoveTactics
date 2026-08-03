-- Throatcut: the Poacher's execute (rogue x hunter). A held body -- Rooted or Crippled -- taken below a
-- third is killed outright, and a kill hands the turn straight back.
--
-- The condition is what separates it from the Undercroft's own Coup de Grace, which executes anything
-- under a quarter on adjacency alone. This one asks for MORE health (a third, not a quarter) but demands
-- the quarry be held first -- which is the discipline's whole method stated as a threshold. A Poacher
-- does not open throats opportunistically; it opens the throat of something that has already stopped
-- being able to leave.
--
-- The refund is the interesting half. fx.grantExtraAction on a kill turns a cleared snare into the next
-- snare: the classic poacher's round is trap, cut, and move on to the next wire in the same breath,
-- which the shelf could not express until free actions existed. It is granted only on a KILL, so a blow
-- that merely wounds ends the turn like anything else -- the tempo is the reward for being right about
-- the threshold, not for pressing the button.
--
-- Bosses are exempt from the instant kill exactly as they are from Coup de Grace: a fight authored
-- around one body does not end because somebody brought rope.
local Curve = require("models.curve")

return {
    name = "Throatcut",
    description = "Executes a Rooted or Crippled foe below a third of its health. A kill returns your action.",
    flavor = "The wire did the waiting. This part takes no time at all.",
    sprite = "assets/items/ability_throatcut.png",
    type = "ability",
    tags = { "pierce", "physical", "guile" },
    class = "rogue",
    discipline = "poacher",
    price = 400,
    unlockQuests = 10,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 7 },
        damage = Curve.ramp(7, 17),
        description = "Kills a held foe under a third; a kill hands the turn back.",
        effect = function(fx)
            local t = fx.target
            if not t then return end
            local held = fx.hasStatus(t, "status_root") or fx.hasStatus(t, "status_cripple")
            local hp = t.char.stats.health
            local frac = (hp.max > 0) and (hp.current / hp.max) or 1
            if held and not t.char.boss and frac <= 0.34 then
                fx.damage(t, { amount = hp.max, raw = true }) -- a clean kill: full health, past armour
            else
                fx.damage(t)
            end
            -- The next wire, in the same breath. Only on a kill, and only ever one -- Combat's own
            -- per-turn accounting decides whether a second is honoured.
            if not t.alive then fx.grantExtraAction(1) end
        end,
    },
}
