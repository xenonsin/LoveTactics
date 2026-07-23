-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Stun or freeze a foe and the hide Marks it for the kill (trait_executioners_eye), then recharges.
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
return {
    name = "Quarryhide",
    description = "When you stun or freeze a foe, Mark it for the kill. Then it must recharge.",
    flavor = "The Warren tans it from things that were caught rather than run down. The distinction matters to them.",
    sprite = "assets/items/armor_quarryhide.png",
    type = "armor",
    tags = { "hide" },
    class = "hunter",
    traits = { "trait_executioners_eye" },
    bonus = { defense = { 3, 3, 4, 4, 5, 5, 6, 6, 7, 7, 8 } },
    resist = { physical = { 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3 } },
}
