-- Mandrake Sprout: plant a Mandrake of your own. It roots foes from three tiles off (weapon_taproot),
-- and when it dies it screams, Stunning everything within two tiles -- both sides, your own line
-- included (trait_mandrake_shriek).
--
-- WHAT THE MANDRAKE LINE IS KNOWN FOR, handed over as the whole body rather than as a piece of it
-- (docs/drops.md): a planted turret that holds, and a mine the enemy has to decide whether to cut. Where
-- you plant it is the decision -- beside your anvil it holds what closes on him and stuns him when it
-- falls; out in front it is a scream the enemy has to walk past.
--
-- `unstocked`: a trophy, off the Mandrake line and nowhere else, and no counter deals one in either
-- direction (tests/discovery_spec.lua names it). One stands at a time.
return {
    name = "Mandrake Sprout",
    description = "Plants a Mandrake of yours. It inflicts Root, and Stuns everything within 2 tiles when it dies.",
    flavor = "The herbals say to tie a dog to it. You have a company. That is close enough.",
    sprite = "assets/items/ability_mandrake_sprout.png",
    type = "ability",
    tags = { "nature", "summon" },
    class = "druid",
    unstocked = true,
    unlockLevel = 15,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 5,
        support = true,
        cost = { stat = "mana", amount = 14 },
        effect = function(fx)
            fx.summon("character_mandrake", fx.tx, fx.ty, { amount = fx.level })
        end,
    },
}
