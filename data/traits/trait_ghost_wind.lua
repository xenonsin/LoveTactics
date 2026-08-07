-- Ghost-Wind: the standing rule of the Shaman's charm of the same name. Everything the bearer summons
-- arrives already Hasted.
--
-- A flag (Trait.flag) read by Combat.summonRiders at the moment a creature stands up. It answers the
-- one real complaint about the reserve-summon economy the Shaman inherits from the Arcanum: a spirit
-- costs a fifth of your mana for as long as it stands, and then spends its first existence walking. A
-- Hasted arrival is the difference between a summon that participates in the turn you paid for it and
-- one that participates in the next.
--
-- Written against `summoned` generally, like the Ancestor Mask beside it, so it hastens a wolf, a
-- construct or a raised corpse just as readily as a wind spirit. A `discipline` field names one owner;
-- the behaviour never asks which shelf sold it.
return {
    name = "Ghost-Wind",
    description = "Everything you summon arrives already Hasted.",
    hastensSummons = true,
}
