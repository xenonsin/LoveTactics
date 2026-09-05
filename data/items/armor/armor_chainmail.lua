-- Passive armor: no active ability (so no speed, ignored by initiative). Its bonus is
-- folded into the wearer's stats at combat setup, and its tag-keyed resist reduces
-- incoming damage whose source carries a matching tag.
local Curve = require("models.curve")

return {
    name = "Chainmail",
    description = "Medium armor. Blunts slashing and piercing blows.",
    flavor = "Ring by ring, the cheapest honest promise the Bastion knows how to make.",
    sprite = "assets/items/chainmail.png",
    type = "armor",
    class = "knight",
    unlockQuests = 2,
    dropTier = 4,
    -- Medium tier: better all-round steel than leather, still one square slower. Defense and resists
    -- are per-level tables (levels 0..10) the forge steps up; the movement penalty is flat.
    bonus = {
        defense = Curve.ramp(2, 12),
        movement = -1,
    },
    resist = {
        slash = 3,
        pierce = 3,
        physical = 2,
    },
}
