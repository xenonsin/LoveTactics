-- Mana Shield: Final Fantasy Tactics' MP Switch, the reaction that paid a unit's wounds out of its
-- MP instead of its HP. Here it is a worn ward rather than a reflex -- it has no cooldown, no trigger
-- and no chance to fail. Every blow that gets past armor comes out of the pool until the pool is gone.
--
-- WHY IT IS THE KNIGHT'S, and why it could not really be anyone else's. docs/classes.md lists knight
-- as the one class whose resource line is genuinely two pools -- "stamina + mana" -- and then notes
-- that its stat growth barely feeds the second one. That is normally read as a weakness. This item is
-- the sentence read the other way round: a pool the knight was never going to spend is a pool the
-- knight can afford to bleed. A mage carrying this is trading away its casting to buy health it did
-- not need, and will notice immediately; a knight is spending something it had lying around.
--
-- The ratio is 1 -- the FFT original, a point of mana for a point of damage -- and the honesty of the
-- item is that this is a FINITE buffer and not a discount. It does not reduce anything. A knight with
-- 20 mana has 20 extra effective health and then has an ordinary knight's health, and the fight after
-- that it has whatever Focus and the Crozier managed to put back. Nothing about it scales with how
-- hard the blow was, which is what keeps it from being simply better than armor: armor is worth more
-- the more often you are hit, and this is worth exactly the same whether it is spent over one blow or
-- twenty.
--
-- It runs AFTER mitigation (see Combat.soakIntoMana), so it covers the post-armor number. Stacking it
-- with real defense is therefore the correct way to play it -- every point of defense is a point the
-- pool does not have to cover, and the two multiply rather than compete.
--
-- The `maxBonus` is the upgrade path, and it is the only one that made sense: forging this deepens the
-- pool it drains, so a forged shield is a longer shield rather than a cheaper one. Raising the ceiling
-- rather than the ratio keeps the item's promise a single readable sentence.
--
-- THE COUNTERPLAY IS ALREADY IN THE GAME, which is the other reason it can afford to be unconditional:
-- anything that empties a knight's mana turns this off completely. Magic Break, Drain Mana, the
-- Cutpurse Knife's cousin -- a pool is a target, and this item makes the knight's the softest one on
-- the field. Wearing it does not make you harder to kill so much as it tells the enemy how.
return {
    name = "Mana Shield",
    description = "Wounds are paid out of mana until the pool is empty, a point for a point.",
    flavor = "The Bastion holds two pools and spends one. This is the other one, finally earning its keep.",
    sprite = "assets/items/mana_shield.png",
    type = "utility",
    tags = { "charm", "arcane" },
    class = "knight",
    price = 560,
    repRank = 3,
    -- Item-level, not an activeAbility keyword: it describes what carrying the thing does rather than
    -- what casting it does (compare `waitBehavior`, `statusImmunity`). Read by Combat.soakIntoMana.
    manaShield = { ratio = 1 },
    -- Forging deepens the pool the ward drains, so an upgrade buys a longer shield rather than a
    -- cheaper one. Folded into Combat.unreservedMax exactly as Attunement's is.
    maxBonus = { mana = { 6, 7, 8, 9, 10, 12, 13, 14, 15, 16, 18 } },
}
