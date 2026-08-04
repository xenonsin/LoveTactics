-- Distil: the alchemist half of the Herbalist (hunter x alchemist). Takes a hazard off the ground and
-- puts it in your satchel as a reagent.
--
-- The discipline's mechanic made literal, and the thing three earlier drafts kept failing to be. Field
-- Brew (already on the shelf) brews restorative GROUND; this brews an ITEM, which is the difference S4
-- exists to make. What you carry away is real stock -- it stacks, it casts, it can be stolen off you,
-- the tooltip knows it -- and it evaporates at the gate (Combat.releaseClaims), because a herbalist who
-- could walk out with an armful of free potions would be a business rather than a build.
--
-- It CONSUMES the hazard, which is the half that makes it tactical rather than free money. The fire you
-- distil is fire that stops burning your line; the quicksand you distil is ground your knight can cross.
-- So the ability is two decisions at once -- is this vial worth a turn, and is this ground worth
-- clearing -- and on a quiet board it is worth neither.
--
-- Any hazard, whoever laid it. An enemy pyromancer's fire is a herbalist's reagent, which is the same
-- reading the Warden's Beat the Bounds takes of the field.
return {
    name = "Distil",
    description = "Consumes a hazard on a nearby tile and brews it into a reagent in your grid.",
    flavor = "The ground was already doing the difficult part. She is mostly holding the jar.",
    sprite = "assets/items/ability_distil.png",
    type = "ability",
    tags = { "utility" },
    class = "alchemist",
    discipline = "herbalist",
    price = 360,
    unlockQuests = 8,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 4,
        cost = { stat = "mana", amount = 8 },
        description = "Takes a hazard off the ground and puts a reagent in your satchel.",
        effect = function(fx)
            local Hazard = require("models.hazard")
            local zone = Hazard.at(fx.combat, fx.tx, fx.ty)
            if not zone then
                fx.log("action", "There is nothing on that ground worth having.")
                return
            end
            if not fx.grantItem(fx.user, "consumable_wildcraft_reagent") then return end
            zone.alive = false -- the ground is spent: this is what makes it a decision, not a tap
        end,
    },
}
