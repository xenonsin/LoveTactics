-- Quest-only: `class` with no `price` (docs/classes.md).
--
-- Shrugs off the first debuff to touch the wearer, then recharges (trait_cleansing_ward). The
-- Cathedral's `cleanse` verb, moved from something you spend a turn casting on somebody else to
-- something that happens to you without being asked.
--
-- What it is really worth is measured in TURNS rather than in the debuff: a Polymorph, a Sleep or a
-- Charm shrugged off here is not "some damage prevented", it is a whole turn that would not have
-- existed. Which makes it wildly swingy -- against an enemy line that opens with hard control it is
-- the best thing in this file, and against one that opens with a Bleed it burns the charge on a
-- rounding error and has nothing left when the Sleep lands.
--
-- No way to hold the charge, deliberately. A ward the player could aim would be a second Panacea; this
-- one answers whatever arrives first, which is the difference between a reflex and a decision.
--
-- Compare trait_unyielding (armor_unyielding_harness, the knight's): that one refuses EVERY debuff and
-- bills mana each time, so it is a pool rather than a cooldown. Same problem, two economies, two
-- shelves.
return {
    name = "Reliquary Mantle",
    description = "Shrugs off the first debuff to touch you, then must recharge.",
    flavor = "There is a bone in the collar. The Cathedral will not say whose and does not consider the question devout.",
    sprite = "assets/items/armor_reliquary_mantle.png",
    type = "armor",
    tags = { "cloth", "holy" },
    class = "priest",
    traits = { "trait_cleansing_ward" },
    bonus = { magicDefense = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 }, defense = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 }, movement = -1 },
    resist = { magical = { 2, 2, 2, 3, 3, 3, 3, 3, 4, 4, 4 } },
}
