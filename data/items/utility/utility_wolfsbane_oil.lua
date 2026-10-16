-- A passive aura in the Dawn Chrism's shape (data/items/utility/utility_dawn_chrism.lua): it anoints the weapons
-- beside it in the 3x3 grid, and what the anointing buys is a BANE -- the `beastbane` tag, which a body of
-- the beast race answers with Combat.BANE's flat bonus and every other body ignores (Combat.mitigatedDamage).
--
-- IT REPLACED THE CHRISM AS ACT 0's AURA LESSON (2026-10-16). The shrine stop teaches that a charm pays
-- every item it touches, and the Chrism's proof was holy against the demons that lined the route. The
-- route is floor one now, and floor one is Gluttony's wood: the bodies on it are beasts and the Champion
-- is the one demon. A holy aura would have paid out once, at the end of the trail. This pays on the next
-- swing at anything the wood sends.
--
-- The Lodge's: a hunter keeps the oil for the quarry, not for the field.
return {
    name = "Wolfsbane Oil",
    description = "Adjacent weapons deal +3 damage to beasts.",
    flavor = "Pressed from the blue hood that grows where the wood is thickest. Hunters work it into the edge before they go in after anything with teeth.",
    sprite = "assets/items/utility_wolfsbane_oil.png",
    type = "utility",
    tags = { "trinket" },
    class = "hunter",
    unlockLevel = 2,
    aura = {
        appliesTo = { "weapon" },
        grantTags = { "beastbane" },
    },
}
