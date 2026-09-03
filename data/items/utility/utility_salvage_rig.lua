-- Salvage Rig: the alchemist half of the Artificer (mage x alchemist). A construct of yours that is
-- destroyed bursts, and the wreckage is refunded as mana.
--
-- The third thing wrong with turrets, answered: they die for nothing. An emplacement that has been cut
-- down has cost a cast, a reservation and a turn, and paid out only whatever it managed first. With this
-- charm, losing one is a plan -- you emplace a sentry INTO a line knowing that the enemy's answer to it
-- is an explosion in their own rank, and that the mana comes back either way.
--
-- Together with Recall Construct and Field Assembly it makes the shelf a complete argument about
-- emplacements: they are in the wrong place (recall them), they are generic (build them out of your
-- own stock), and they die for nothing (they do not any more).
--
-- The burst has no caster and provokes no answer. A wreck is not a swing.
return {
    name = "Salvage Rig",
    description = "On a construct's death: it bursts, damaging neighbours and refunding mana.",
    flavor = "Everything in the workshop is built to come apart. It saves so much time later.",
    sprite = "assets/items/utility_salvage_rig.png",
    type = "utility",
    tags = { "charm" },
    class = "alchemist",
    discipline = "artificer",
    price = 410,
    unlockQuests = 4,
    traits = { "trait_salvage_rig" },
    -- a construct's death, harvested
    bonus = { magicDamage = 1 },
}
