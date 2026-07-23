-- A sword, so it owes the family's contract (docs/weapons.md): one-handed, and it answers an adjacent
-- melee blow. What it answers WITH is the extra -- data/traits/trait_binding_parry.lua replaces the
-- ordinary Parry's cut with a bind, so whoever swings at this blade cannot walk away from the exchange
-- (status_duelbound).
--
-- The sword shelf's capstone (rank 5), and the third of the three answers the family sells: the Iron
-- Sword trades a blow for a blow, the Riposte Blade refuses the blow outright, and this one keeps the
-- body. Read as a set they are the same reflex pointed at damage, at defense and at POSITION -- and the
-- third is the one the other two cannot do anything about, because a skirmisher who takes one swing and
-- steps back out of reach has beaten both of them.
--
-- Its own damage is under an iron sword's. It should be: the sword is not what this weapon does.
return {
    name = "Duelist's Edge",
    description = "Strikes an adjacent foe. When struck in melee, binds the attacker in place instead of cutting back.",
    flavor = "The Bastion's fencing masters teach that the hard part was never landing the blow. It was making them stay for the second one.",
    sprite = "assets/items/duelists_edge.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1, -- a sword is one-handed, and this one wants the free slot for whatever finishes the duel
    traits = { "trait_binding_parry" }, -- NOT trait_parry: the bind replaces the cut, it does not join it
    class = "knight", -- a blade that answers is the Bastion's argument (docs/classes.md)
    price = 620,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        -- Under the iron sword's curve on purpose: an answer that removes a foe's whole retreat plan is
        -- worth more than the two points of Power it gives up for it.
        damage = { 5, 6, 7, 8, 8, 9, 10, 11, 12, 13, 14 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
