-- A dagger, so it owes the family's Bleed (docs/weapons.md). What it adds over
-- data/items/weapon/weapon_iron_dagger.lua is what rides in on the wound: the blade is kept wet, so the
-- cut Poisons as well as bleeds.
--
-- The two afflictions are deliberately opposite in kind, which is the whole of what the extra buys:
--
--   Bleed  is POSITIONAL -- it taxes every tile the victim walks, and costs a still one nothing.
--   Poison is a CLOCK    -- it burns on regardless, and standing still only wastes the time.
--
-- So the pair closes a door the plain dagger leaves open. A knifed foe could always answer Bleed by
-- refusing to move; answer this one that way and the venom just runs its course. There is no longer a
-- posture that costs nothing -- which is envy's reading of a rogue's weapon: it does not want to beat you,
-- it wants to take away the thing that was working.
local Curve = require("models.curve")

return {
    name = "Envenomed Kris",
    description = "Deals damage and inflicts both Bleed and Poison. Moving costs blood; standing still costs time.",
    flavor = "The Alchemist sells the blade at cost. The refills are where the money is.",
    sprite = "assets/items/envenomed_kris.png",
    type = "weapon",
    tags = { "dagger", "pierce", "physical", "poison", "melee" },
    class = "alchemist",
    price = 210,
    unlockQuests = 11,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick, as every dagger is
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(4, 14), -- under an iron dagger's: two afflictions is the trade
        effect = function(fx)
            -- Both afflictions ride the blow, so a guardian who takes the hit takes the wound and the venom.
            fx.damage(fx.target, { inflicts = { "status_bleed", "status_poison" } })
        end,
    },
}
