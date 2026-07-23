-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- The first attack that would land is lost in smoke and the wearer blinks two tiles clear
-- (trait_smoke_screen). Once, and then the wrap is spent for the battle -- so it is not survivability,
-- it is a REPOSITION the enemy pays for. A rogue who opens badly gets one free correction.
--
-- consumable_smoke_bomb carries the same reflex as a thrown thing. That one is a fight decision bought
-- by the crate; this is a build decision that costs the armour slot, and the distinction is exactly
-- the charm/coating split docs/classes.md draws for auras, arriving from the defensive side.
--
-- Cloth, so it costs a square of pace. That is the price of every woven thing on the shelf now, and
-- this one is the item where it bites least -- the blink gives the square back the moment it triggers.
return {
    name = "Smokecloth Wrap",
    description = "The first attack that would hit you is lost in smoke, and you blink two tiles clear.",
    flavor = "Woven with the stuff the Undercroft burns when it would rather not be asked anything.",
    sprite = "assets/items/armor_smokecloth_wrap.png",
    type = "armor",
    tags = { "cloth" },
    class = "rogue",
    traits = { "trait_smoke_screen" },
    bonus = { defense = { 2, 2, 3, 3, 4, 4, 4, 5, 5, 6, 6 }, movement = -1 },
}
