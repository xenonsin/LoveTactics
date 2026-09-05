-- An axe, so it cleaves (docs/weapons.md). Its extra is that the arc eats: any corpse lying in the tiles
-- the swing sweeps is consumed (Combat.consumeCorpse) and the wielder is healed for it.
--
-- Quest-only: `class` with no `price`.
--
-- The distinction from the Crimson Greataxe's lifesteal, which is the obvious comparison and the wrong
-- one: lifesteal pays out of the wound you are opening RIGHT NOW, so it is best when the arc is full of
-- living bodies. This pays out of the ones already down, so it is best on the turn AFTER a good swing --
-- and it does not care whether there is anything alive in front of it at all. A Carrion Axe swung at an
-- empty tile full of dead men is a heal.
--
-- Which makes it the only weapon in the family that wants you to hold ground rather than press forward:
-- the corpses are behind and beside you, and walking off them is walking away from the healing. Read
-- against data/items/weapon/weapon_reapers_due.lua, which reads the same graveyard as a damage stat.
local Curve = require("models.curve")

return {
    name = "Carrion Axe",
    description = "For each corpse in area consume it and heal.",
    flavor = "The Lodge insists it is a butchering tool. Nobody at the Lodge has ever butchered anything with it.",
    sprite = "assets/items/carrion_axe.png",
    type = "weapon",
    tags = { "axe", "slash", "physical", "melee" },
    class = "fighter",
    dropTier = 7,
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        minRange = 1,
        speed = 4,
        cost = { stat = "stamina", amount = 10 },
        damage = Curve.ramp(4, 14),
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
            -- ...and then the ground. `aoeCells` rather than `aoeUnits`: the whole point is the tiles
            -- with nobody standing on them, and aoeCells is deliberately not narrowed by a Careful Sigil
            -- (docs/weapons.md) -- the sigil steers the blast, never the ground it reaches over.
            local eaten = 0
            for _, cell in ipairs(fx.aoeCells()) do
                local corpse = fx.corpseAt(cell.x, cell.y)
                if corpse and fx.consumeCorpse(corpse) then
                    eaten = eaten + 1
                    fx.heal(fx.user, 6 + 2 * fx.level)
                end
            end
            if eaten > 0 then
                fx.log("action", string.format("%s feeds the axe (%d).",
                    (fx.user.char and fx.user.char.name) or "Unit", eaten))
            end
        end,
    },
}
