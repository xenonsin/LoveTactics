-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Stun or freeze a foe and the hide Marks it for the kill (trait_executioners_eye), then cools down.
-- Armor that turns the party's CONTROL into the party's damage, which is the hunter's own loop --
-- mark, then collect -- arriving from a slot that has never been able to say it.
--
-- The build it makes is the interesting part, because the trigger is not the wearer's own: any stun
-- or freeze the hide's bearer lands counts, and the shelf that reliably lands those is the fighter's
-- (hammers) and the mage's (ice). So a hunter in this is asking the rest of the party to set up for
-- them, which is the inverse of every other hunter item, where the bow is the setup and the hunter is
-- also the payoff. Gluttony as a party contract rather than a personal appetite.
--
-- Mark drops defense AND magic defense (status_mark), so what it invites is whichever finisher is
-- already in the grid rather than a particular school. Nothing here cares what kills it.
local Curve = require("models.curve")

return {
    name = "Quarryhide",
    description = "On inflicting Stun or Freeze: inflict Mark, then go on cooldown.",
    flavor = "The Warren tans it from things that were caught rather than run down. The distinction matters to them.",
    sprite = "assets/items/armor_quarryhide.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    dropTier = 4,
    traits = { "trait_executioners_eye" },
    bonus = { defense = Curve.ramp(3, 13), movement = -1 },
    resist = { physical = 1 },
}
