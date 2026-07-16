-- A duelist's blade that does not trade. `traits` on an item reach whoever carries it
-- (models/trait.lua), so any character -- not just a born counter-fighter -- can build a retaliation
-- loadout around it. A fighter-class weapon, sold at the Colosseum. The strike it answers with is the
-- wielder's DEFAULT weapon, so pairing it with a heavier blade sharpens the answer.
--
-- A sword, so it owes the family's counter-reaction (docs/weapons.md) -- but it REPLACES the ordinary
-- data/traits/parry.lua with data/traits/riposte.lua rather than carrying both. That swap is the whole
-- of what the price buys, and it is a difference in KIND, not degree. Both are priced in stamina and a
-- cooldown, like every triggered reflex; what differs is what the stamina buys:
--
--   an ordinary sword parries -- takes the blow, then answers it. A trade.
--   this blade ripostes       -- turns the blow aside so it deals nothing, and answers it anyway.
--
-- Which is what the word has always meant with a sword in hand, and what this blade was missing back
-- when its only claim was a shorter cooldown than the sword every recruit carries. Standing a duelist
-- in a doorway is a real tactic: adjacent attackers simply fail, one every 16 ticks -- for as long as
-- the duelist's stamina holds out, which is the second thing the doorway costs.
--
-- The counter-play is written into the reflex rather than into a number: it only turns aside a
-- MATERIAL blow from an ADJACENT foe. Shoot it, burn it, or stand two tiles off and swing a spear,
-- and the guard is worth nothing at all.
return {
    name = "Riposte Blade",
    description = "A duelist's sword. A melee blow it sees coming is turned aside entirely -- and answered.",
    sprite = "assets/items/riposte_blade.png",
    type = "weapon",
    tags = { "sword", "slash", "physical", "melee" },
    hands = 1,
    class = "fighter",
    price = 220,
    repRank = 2,
    traits = { "riposte" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 8 },
        damage = { 6, 7, 7, 8, 8, 9, 10, 10, 11, 11, 12 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
