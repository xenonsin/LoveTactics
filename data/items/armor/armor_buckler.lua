-- A shield: a small passive defense bonus, and it swaps the holder's Wait action into Defend --
-- end the turn to raise physical defense (the Defending status) until this unit's next turn.
-- See Combat.waitBehavior / Combat.defend and data/status/defending.lua.
local Curve = require("models.curve")

return {
    name = "Buckler",
    description = "Replaces Wait with Defend.",
    flavor = "The Bastion issues one to every recruit, before it issues them an opinion.",
    sprite = "assets/items/buckler.png",
    type = "armor",
    tags = { "shield" }, -- a Shield Bash item beside it in the grid can bash with it
    class = "knight",
    price = 475,
    unlockQuests = 3, -- a family's base weapon is always rank 1 (docs/weapons.md); the buckler is the shield's
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    resist = { physical = 1 },
    -- Defend brace: the temporary +defense while braced, tuned here and climbing with the forge.
    waitBehavior = { kind = "defend", speed = 3, defense = Curve.ramp(6, 16) },
}
