-- Brine Bolt: a fistful of the channel, thrown.
--
-- The Tidecaller's setup half, and the smaller of its two casts. It soaks what it hits (status_wet),
-- which is worth almost nothing on its own -- water damages nobody in this game -- and everything as
-- the first of two turns.
--
-- WET IS WHAT IT IS FOR. A soaked body takes +6 from lightning and ice and -6 from fire, and its tile
-- CONDUCTS (status_wet's tileTags), so a soaked cluster is a cluster one bolt can sweep. Read this
-- beside ability_stormwake, which is the second half, and beside data/items/weapon/weapon_wetstone_mace
-- and weapon_conductor, which are the same chain cut across two other shelves.
--
-- THE FIRE RESISTANCE IT HANDS THE TARGET IS REAL AND IS THE COST -- soaking a rank in front of your
-- own fire mage turns their turn off. That is the honest trade of every water effect in the game, and
-- an enemy caster paying it is the player's opening: burn the front rank before the Tidecaller gets to.
local Curve = require("models.curve")

return {
    name = "Brine Bolt",
    description = "A lash of black water. Soaks the target.",
    flavor = "Half of it is the fen. The other half is whatever the fen has been keeping.",
    sprite = "assets/items/brine_bolt.png",
    type = "ability",
    tags = { "water", "magical" },
    class = "mage",
    dropOnly = true,
    dropTier = 5,
    unlockQuests = 3,
    activeAbility = {
        target = "enemy",
        range = 4,
        speed = 4,
        cost = { stat = "mana", amount = 6 },
        damage = Curve.ramp(10, 20),
        effect = function(fx)
            fx.damage(fx.target)
            if fx.target.alive then fx.applyStatus(fx.target, "status_wet") end
        end,
    },
}
