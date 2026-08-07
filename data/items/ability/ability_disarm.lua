-- Disarm: a wrist turned at the joint, and the weapon is on the floor before its owner knows it is
-- gone (data/status/disarmed.lua). Pure control -- it deals no damage; the payload is the Disarmed
-- status, which strikes the blade from the hand (Combat.itemBlockReason refuses any crafted weapon,
-- basic attack included) while leaving abilities, potions, and a bare-fisted punch untouched. Aim it
-- at the thing that lives by its weapon: a heavy hitter drops to slapping for a few turns.
--
-- ON THE UNDERCROFT'S SHELF because it is `steal` one step short. Greed's whole trade is taking what
-- is not yours; the cheap half of that is making sure the owner cannot use it either, and the hands
-- that lift a purse are the hands that do this. It was the Crucible's for a while, sold as a splash
-- of solvent -- an alchemical reading of the same verb, on the one shelf whose vocabulary it had no
-- reason to borrow. The solvent went with the shelf: this is a `guile` trick and it costs breath.
return {
    name = "Disarm",
    description = "Inflicts Disarm.",
    flavor = "The first thing you learn down here: a man holding a sword is only holding it.",
    sprite = "assets/items/ability_disarm.png",
    type = "ability",
    tags = { "guile", "utility" },
    class = "rogue",
    price = 320,
    unlockQuests = 4,
    activeAbility = {
        target = "enemy",
        range = 2,
        requiresSight = true,
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        effect = function(fx)
            fx.applyStatus(fx.target, "status_disarmed")
        end,
    },
}
