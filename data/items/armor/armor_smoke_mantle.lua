-- Smoke Mantle: the Ninja (rogue x mage) selling patience. Spend a turn without drawing blood and you
-- open the next one Invisible.
--
-- Every other way this shelf hides you costs mana: Mirror Image, Vanishing Strike, Scatterlight. This
-- one costs a turn of damage instead, which makes it the piece that still works in the third hour of a
-- fight when the mage half of the build has nothing left. A ninja out of mana is still a ninja.
--
-- Light leather cut for movement, so it pays no square (docs/classes.md's tier table) -- and grants
-- none either, because no armour in this game does.
--
-- One interaction worth knowing before you buy it: a Marked ninja cannot vanish at all. status_mark
-- `forbids` status_invisible, so a hunter who paints you shuts the mantle off until somebody cleanses
-- it. That is the counterplay, and it is deliberately a thing the enemy has to spend an action on.
local Curve = require("models.curve")

return {
    name = "Smoke Mantle",
    description = "If you drew no blood last turn, you begin this one Invisible.",
    flavor = "The trick is not the smoke. The trick is being willing to do nothing for a whole minute.",
    sprite = "assets/items/armor_smoke_mantle.png",
    type = "armor",
    tags = { "leather", "illusion" },
    class = "rogue",
    discipline = "ninja",
    price = 420,
    unlockQuests = 10,
    bonus = { defense = Curve.paired(3, 8) },
    traits = { "trait_smoke_mantle" },
}
