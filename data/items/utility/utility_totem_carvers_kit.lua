-- Totem-Carver's Kit: the hunter half of the Totemist (hunter x priest). Everything you plant stands up
-- with sixteen more health and keeps it.
--
-- It answers the discipline's actual weakness, which was never damage. A totem is control-"none" and
-- timeless -- it never moves, never strikes, never takes a turn, and holds its ground open purely by
-- continuing to exist. It has twenty-four health. That is two swings. Before this, the entire build
-- could be deleted by an enemy walking over and hitting a post.
--
-- Health rather than radius, which is the revision worth recording: the draft said "totems gain health
-- and one more tile of radius", and the radius half belongs to the ability that plants the zone rather
-- than to the totem standing in it. Splitting one item across two systems to deliver a sentence is how
-- you get a mechanic nobody can predict. The kit makes the post harder to cut down; Ley Line is what
-- makes the ground go further.
--
-- Written against `summoned` generally (Combat.summonRiders), so a Totemist fielding anything else gets
-- the same benefit -- the Beastlord's Bond precedent, and the reason a discipline field names an owner
-- rather than a restriction.
return {
    name = "Totem-Carver's Kit",
    description = "Everything you summon stands up with +16 health.",
    flavor = "Green wood splits in the first frost. She has never once been in a hurry.",
    sprite = "assets/items/utility_totem_carvers_kit.png",
    type = "utility",
    tags = { "charm" },
    class = "hunter",
    discipline = "totemist",
    price = 400,
    unlockQuests = 10,
    traits = { "trait_totem_carvers_kit" },
}
