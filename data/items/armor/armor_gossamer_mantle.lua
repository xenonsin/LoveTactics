-- GOSSAMER MANTLE: the spider's feet as something a person can wear (trait_silkfoot). Web does not catch
-- the wearer, and standing on it they act sooner -- so on the Gluttony floors, where every board is
-- strung, this is the answer the circle hands over itself. Off the Giant Spider; a trophy.
--
-- AND IT BURNS, the way the thing it was cut from does (`fire = -4`). The third wearable amplifier in
-- the game (tests/armor_spec.lua names it), and it earns the line for the Scale Hauberk's reason: a
-- company that wears the spider's silk inherits both halves of it. The web is the Gluttony floor's
-- answer and fire is the web's -- so the coat that walks the web freely is the coat a fire cast finds
-- first. The spiders carry the same weakness innately; no spider wears this, so nobody stacks it.
--
-- Silk is light, so it is one square of pace, as every coat is.
local Curve = require("models.curve")

return {
    name = "Gossamer Mantle",
    description = "Walk Web freely, and move farther and act quicker while standing on it.",
    flavor = "It weighs nothing, and it is stronger than the rope it was cut from. Nobody at the Warren cut it.",
    sprite = "assets/items/armor_gossamer_mantle.png",
    type = "armor",
    tags = { "silk" },
    class = "poacher",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_silkfoot" },
    bonus = { defense = Curve.ramp(1, 11), movement = -1 },
    resist = { pierce = Curve.ramp(1, 11), fire = -4 },
}
