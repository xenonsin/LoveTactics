-- Keen Senses: a TRIGGERED ability -- it is never cast, it answers. Its whole effect is the trait it
-- grants to whoever carries it (models/trait.lua), so it declares no activeAbility and never appears
-- among the bearer's actions; the reflex fires on its own, the moment someone attacks them.
--
-- What it does is unique in the game: the counter resolves BEFORE the attack that provoked it. Every
-- other answer in the game is a trade -- the sword's parry takes the blow and cuts back, the Riposte
-- Blade turns it aside and cuts back -- but a priest with this reads the swing coming and gets there
-- first. Kill the attacker with the answer and the attack simply never happens.
--
-- It is priced in STAMINA rather than a cooldown, which is what makes it a priest's ability and not a
-- duelist's: it answers every attack the bearer can pay for, so standing a priest in the open and
-- letting them be swarmed empties the pool they wanted for healing. The choice of when to stop
-- countering isn't offered -- the choice was made when you walked them into range.
--
-- Kin to data/items/utility/utility_duelists_reflex.lua and reprisal_quiver.lua, which package a reflex the
-- same way; this one is sold as an ability because that is the shelf a priest shops from.
return {
    name = "Keen Senses",
    description = "Triggered: when attacked, strike first for stamina, before the blow lands.",
    flavor = "The choice of when to stop countering is never offered. It was made when you walked into range.",
    sprite = "assets/items/ability_keen_senses.png",
    type = "ability",
    tags = { "holy", "reaction" },
    class = "priest",
    price = 320,
    repRank = 3,
    traits = { "trait_keen_senses" },
}
