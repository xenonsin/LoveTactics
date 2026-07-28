-- Field Assembly: the mage half of the Artificer (mage x alchemist). Builds a construct out of a
-- consumable in your own grid -- and spends the consumable to do it.
--
-- The second thing wrong with turrets: they are generic. The Ordnance Sentry is the same sentry every
-- time, which makes emplacing one a decision about WHERE and never about WHAT. This makes the answer
-- come out of your satchel: whatever you were carrying is what stands up, and the cost is that you are
-- no longer carrying it.
--
-- A FAITHFUL APPROXIMATION, said out loud the way this codebase expects. The plan asked for a construct
-- that "attacks with that item's effect", and the engine has no shape for handing a summoned body
-- somebody else's effect closure -- an fx context is bound to one caster, and a bomb's self-targeted
-- clauses would fire on the wrong body. What happens instead is that the consumed item's POWER goes into
-- the construct: a bigger vial builds a tougher, harder-hitting sentry. The choice is real and the
-- arithmetic is legible; only the flavour of "your turret throws your bomb" is missing.
--
-- It is also the item that finally stocks the Arcanum's half of this discipline. Artificer shipped with
-- both its items on the alchemist shelf, so the mage vendor announced a discipline and sold nothing.
return {
    name = "Field Assembly",
    description = "Consumes a draught from your grid to build a sentry -- the better the stock, the better the machine.",
    flavor = "There is no schematic. There is a satchel, and there is a deadline.",
    sprite = "assets/items/ability_field_assembly.png",
    type = "ability",
    tags = { "summon" },
    class = "mage",
    discipline = "artificer",
    price = 420,
    repRank = 4,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 5,
        cost = { stat = "mana", amount = 10 },
        description = "Consume a draught from your grid to raise a sentry scaled by what it cost.",
        effect = function(fx)
            -- The cheapest consumable in the grid, so an artificer is never forced to feed its Panacea
            -- to the machine: the still's own reagents are what this is meant to eat.
            local Character = require("models.character")
            local pick
            for _, it in ipairs(Character.eachItem(fx.user.char)) do
                if it.type == "consumable" and (it.quantity or 1) > 0 then
                    if not pick or (it.price or 0) < (pick.price or 0) then pick = it end
                end
            end
            if not pick then
                fx.log("action", "There is nothing in the satchel worth building with.")
                return
            end
            -- Scale off what was fed in, floored so a free field reagent still builds something.
            local grade = 1 + math.floor((pick.price or 60) / 60)
            pick.quantity = math.max(0, (pick.quantity or 1) - 1)
            fx.summon("character_ordnance_sentry", fx.tx, fx.ty, {
                scaling = { health = grade, damage = grade * 0.5 },
                amount = 6 + fx.level + grade,
                duration = 18,
            })
        end,
    },
}
