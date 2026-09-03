-- The Unspent Heart: a heavy cuirass with something still beating behind the breastplate. It heals its
-- wearer hard while nobody is touching them, and stops dead the moment anybody does
-- (data/traits/trait_unspent_heart.lua).
--
-- SUSTAIN PRICED ON BEING LEFT ALONE, which this game had no way to sell. Every other recovery in the
-- catalog pays out on the clock regardless -- staminaRegen, a Sanctuary's Regeneration, the priest's
-- presence -- so all of them are worth most to the character being focused, which is backwards,
-- because that character is also the one the enemy has already decided to kill.
--
-- This pays the opposite unit: the flanker nobody is looking at, the knight who broke off, the wounded
-- fighter who spent two turns walking the long way round. Which makes it the first item that rewards
-- DISENGAGING -- a verb this game's whole design pushes against, and one it is much better for having.
--
-- Four health a tick, against the priest's one. That gap is allowed to be large precisely because it
-- is the only recovery in the game the enemy can switch off by hitting somebody -- and a poison tick,
-- a fire underfoot or a stray arrow shuts it just as hard as a greatsword.
--
-- No status and no badge, deliberately. The shutting is a cooldown on the wearer rather than a debuff
-- (see the trait), so the enemy's information is exactly what it should be -- "I hit them recently" --
-- with no timer attached to it, and a Cure cannot restart the heart, which would be a strange thing
-- for a cure to do.
local Curve = require("models.curve")

return {
    name = "The Unspent Heart",
    description = "Heals its wearer hard while untouched; any wound stops it for several turns.",
    flavor = "The Crucible sold it as salvage and did not say salvage of what.",
    sprite = "assets/items/armor_unspent_heart.png",
    type = "armor",
    tags = { "heavy" },
    class = "barbarian", -- deeper cut of the shelf: buyable only once the barbarian gate is cleared
    price = 495,
    unlockQuests = 5,
    traits = { "trait_unspent_heart" },
    bonus = {
        health = Curve.ramp(10, 30),
        defense = Curve.ramp(2, 12),
        movement = -2, -- heavy: the salvage is a lump of someone else's chest, and it weighs like one
    },
}
