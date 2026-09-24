-- Gula's grid weapon, and gluttony's reading of the hunter's kit (docs/story.md, "The Hunter's Lodge"). A
-- gralloch is the gutting stroke that opens a carcass to be dressed.
--
-- IT NO LONGER HEALS HER (settled on review 2026-09-23). It used to, and her Maw's Ravenous healed her
-- again on the same blow, so every cut paid her twice and the counterplay the story names -- starve her --
-- had nothing to grip but a bigger number. Her healing is EATING now (data/items/ability/ability_devour.lua):
-- a thing the company can see coming and deny, rather than a tax on every exchange. So the knife is only
-- a knife, quick and cheap -- and the moment she has eaten something with a better weapon in it, she
-- swings that instead.
--
-- A boss weapon: `creature`, no `price`, `noSteal`. The flag is the half that matters: a body's own grid
-- feeds the drop pool directly (models/spoils.lua), so without it her knife fell out of her own corpse.
local Curve = require("models.curve")

return {
    name = "Gralloch Knife",
    description = "Deals damage.",
    flavor = "The stroke that opens a carcass to be dressed. On her it never stops at the carcass.",
    sprite = "assets/items/gralloch_knife.png",
    type = "weapon",
    class = "creature",
    -- `relic`, like every general's weapon (armor_mail_of_the_unappeased, weapon_forsworn_pike): it says
    -- in the data what this file's header has always said in prose, which is that this is Gula's and not
    -- part of the dagger family's ten (docs/weapons.md). Nothing reads the tag mechanically -- it is what
    -- keeps a sin's weapon out of a count of the shelf.
    tags = { "dagger", "pierce", "physical", "melee", "relic" },
    noSteal = true, -- Gula's, and she is still holding it
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2, -- quick: she acts again almost at once
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
