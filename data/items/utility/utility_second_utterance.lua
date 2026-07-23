-- Second Utterance: a passive charm that grants the trait of the same name
-- (data/traits/trait_second_utterance.lua). Every channel of the bearer's that LANDS banks a charge, and
-- the next channeled spell spends it to resolve with no wind-up -- and therefore no telegraph anyone can
-- step out of, and nothing a stun can shatter.
--
-- Priced as the Arcanum's most expensive charm because of what it does to the shelf's whole vocabulary.
-- Channel is the mage's defining keyword (docs/classes.md) and every big spell on the rack is built
-- around eating its tell; this hands back the second one free. What keeps it honest is that it is
-- strictly a SECOND: the first Meteor Storm still telegraphs in full, and if that one is interrupted the
-- charge is never banked at all. It rewards a mage who got a channel through, which is the hardest thing
-- the shelf asks anyone to do.
--
-- The name follows the codebase's utility -> trait convention (docs/weapons.md's note on ids that share a
-- word): utility_second_utterance grants trait_second_utterance, exactly as utility_second_wind grants
-- trait_second_wind, and the status the trait banks wears the same name a third time.
return {
    name = "Second Utterance",
    description = "When one of your channels resolves, your next channeled spell needs no wind-up.",
    flavor = "The word said once is a working. Said twice, it is only a habit.",
    sprite = "assets/items/second_utterance.png",
    type = "utility",
    tags = { "charm" },
    class = "mage",
    price = 520,
    repRank = 3,
    traits = { "trait_second_utterance" },
}
