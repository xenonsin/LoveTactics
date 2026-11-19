-- THE GILDED HOOK: the gilded page's weapon (data/characters/character_gilded_page.lua; the creature identity pass,
-- 2026-11-19). The audit found the page and the sworn were one body at two tiers -- the same pike, the same hide, the
-- same rule -- so the page was given the rank's OTHER job: a hook on a pole that drags a foe within 2 in beside the
-- page, which is where the sworn's pikes reach. The sworn holds the line; the page fetches bodies to it.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua). Lighter than the pike, because the hook's
-- work is the drag, not the wound.
local Curve = require("models.curve")

return {
    name = "Gilded Hook",
    description = "Strikes a foe within 2 and pulls it in beside you.",
    flavor = "A page carries what the rank needs. Mostly, the rank needs you closer.",
    sprite = "assets/items/weapon_gilded_hook.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 3, -- the pike's own pace: a page acting a beat later than its rank cost Pride's road fights a round
        requiresSight = true, -- a hook cannot catch what it cannot see
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            local t = fx.target
            if not (t and t.alive) then return end
            fx.damage(t)
            if t.alive then fx.pull(t) end
        end,
    },
}
