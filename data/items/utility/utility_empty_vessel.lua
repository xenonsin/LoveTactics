-- Empty Vessel: the mage half of the Spellbreaker (knight x mage). Your blows land far harder against a
-- caster whose mana is spent.
--
-- The payoff Mana Sunder has been missing since the day it shipped. Draining a mage dry did nothing on
-- its own: the mage was inconvenienced, and the spellbreaker had spent a whole turn to inconvenience it.
-- This turns the empty bar into a kill condition, and makes two items that were already sitting on the
-- shelf into a plan -- sunder the pool, then open the body.
--
-- It reads "has a mana pool, and it is empty". A wolf, a construct, a fighter -- things that never had
-- mana -- are not empty vessels, and paying a spellbreaker for hitting the party's dog would make this a
-- flat damage bonus wearing a condition.
--
-- Runs through damageBonusVs, a pure query fired on every damage preview: the number the hover promises
-- is the number the blow lands.
return {
    name = "Empty Vessel",
    description = "You strike far harder against enemies whose mana is spent.",
    flavor = "Empty the jug first. What happens to the jug afterwards is a much shorter conversation.",
    sprite = "assets/items/utility_empty_vessel.png",
    type = "utility",
    tags = { "charm" },
    class = "mage",
    discipline = "spellbreaker",
    price = 420,
    repRank = 4,
    traits = { "trait_empty_vessel" },
}
