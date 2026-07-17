-- A dagger, so it owes the family's Bleed and its quickness (docs/weapons.md). What it adds over
-- data/items/weapon/weapon_iron_dagger.lua is greed's most literal reading: it does not spend the
-- victim's strength, it TAKES it. Every cut drains stamina out of them and puts it in the rogue.
--
-- The extra is not the number, it is what stamina buys. Stamina is what a foe pays its reflexes out of --
-- a parry, a riposte, a counter -- and an exhausted swordsman simply eats the blow (see data/traits/
-- trait_parry.lua, and the case pinning it in tests/weapon_spec.lua). So a knifed guard does not merely
-- take damage: a few cuts in, its guard stops answering at all, and every ally swinging at it stops being
-- punished for doing so. The knife opens a foe up for the whole party, and pays the rogue for the work.
--
-- Which makes it the anti-duelist blade, and deliberately weak against everything else: a beast with no
-- reflexes to bankrupt has nothing worth taking, and against one of those this is a worse iron dagger.
-- Bring it to a doorway with a swordsman in it.
return {
    name = "Cutpurse Knife",
    description = "Deals damage, inflicts Bleed, and drains the target's stamina into your own.",
    flavor = "Everyone watches the blade. Nobody watches the other hand.",
    sprite = "assets/items/cutpurse_knife.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "guile", "melee" },
    class = "rogue",
    price = 200,
    repRank = 2,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, as every dagger is
        cost = { stat = "stamina", amount = 4 }, -- cheap, and it usually pays for itself back
        damage = { 4, 4, 5, 5, 6, 7, 7, 8, 9, 9, 10 }, -- under an iron dagger's: what it takes is the point
        effect = function(fx)
            fx.damage(fx.target)
            fx.applyStatus(fx.target, "status_bleed")
            -- Take, then keep: drain reports what was actually there to take (a foe already exhausted
            -- yields nothing), and exactly that much is handed to the rogue -- never more. The Drain
            -- Mana pattern (data/items/ability/ability_drain_mana.lua), pointed at the pool that buys
            -- reflexes instead of the one that buys spells.
            --
            -- Scaled off fx.level rather than a second authored magnitude: an ability names exactly one
            -- (models/item.lua), and this weapon's is its damage. The forge deepens the cut and the
            -- theft together -- 5 at base, one more per level, always above the 4 the swing costs, so a
            -- rogue that keeps knifing the same guard is funded by the man it is bankrupting.
            local took = fx.drain(fx.target, "stamina", 5 + fx.level)
            if took > 0 then fx.restore(fx.user, "stamina", took) end
        end,
    },
}
