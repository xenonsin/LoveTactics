-- A carrion crawler's jaws, and the reason a downed body is not simply a body you will pick up later.
--
-- An ordinary bite, plus one rule: standing beside somebody who has gone down, it feeds instead, and
-- what it takes it keeps. That turns the revival countdown into a race the party can LOSE without
-- losing the fight -- which is exactly the pressure the downed system was built to have and has never
-- had an enemy apply.
--
-- It reads fx.downedAt on the tiles around itself and only ever finds a body still inside its window;
-- a corpse is past reviving and no longer answers (models/combat.lua, Combat.downedAt). So the crawler
-- cannot farm the dead forever -- it hurries the one window that matters and then goes back to biting.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

local FEED_HEAL = 8 -- what one mouthful is worth, flat: the crawler is chaff and stays chaff

return {
    name = "Carrion Jaws",
    description = "Bites an adjacent foe, or feeds on a downed one to heal instead.",
    flavor = "It has no opinion about which of you is still moving. It simply prefers the ones that are not.",
    sprite = "assets/items/carrion_jaws.png",
    type = "weapon",
    class = "creature",
    dropTier = 7,
    tags = { "natural", "bite", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 4 },
        damage = Curve.ramp(4, 14),
        effect = function(fx)
            -- Look for a fallen body first, on the four tiles around the crawler. A downed unit is not
            -- a legal `target` (it is out of the fight), so this is read off the board rather than off
            -- what the AI aimed at.
            local u = fx.user
            local OFFSETS = { { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }
            for _, d in ipairs(OFFSETS) do
                local body = fx.downedAt(u.x + d[1], u.y + d[2])
                if body then
                    -- Feeding is the whole turn. It does not also bite.
                    fx.heal(u, FEED_HEAL)
                    fx.log("system", "The crawler feeds.")
                    return
                end
            end
            fx.damage(fx.target)
        end,
    },
}
