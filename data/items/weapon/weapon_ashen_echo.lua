-- COVET: the Mimic-of-Ash throws back the last thing thrown at it.
--
-- The desert is the one board where both lines watch each other the whole way in -- open ground, slow
-- crossing, no cover (data/biomes/desert.lua). So on this floor your opening move is INFORMATION, and
-- this is the body that hands the information back.
--
-- WHAT IT THROWS BACK IS THE ELEMENT, NOT THE SPELL (creature identity pass, 2026-11-19). It used to be a
-- strike that grew with the mimic's missing health -- a ramp that read like every enrage in the game, under a
-- description that promised something else. Now the weapon carries trait_ashen_echo: an elemental blow that
-- wounds the mimic is remembered, and this strike carries that element until a plain blow clears it (the
-- Resonant Grip's own machinery, `carriesLastElement`). The badge names the element.
--
-- Still not a literal re-cast, for the reason the old header gave: a mimic that re-threw a party's best spell
-- would be a coin flip and would sit outside its rung. Borrowing the ELEMENT keeps the blow this weapon's size
-- and turns it into a question about resists -- your fire, landing on whoever is weakest to fire.
--
-- The Second Self wields the same echo, and is ash for the same reason.
local Curve = require("models.curve")

return {
    name = "Ashen Echo",
    description = "Strikes an adjacent foe. Its strikes carry the element of the last blow that wounded it, until a plain blow lands.",
    flavor = "It has no opinions of its own. It has an excellent memory for other people's.",
    sprite = "assets/items/ashen_echo.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    traits = { "trait_ashen_echo" },
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        -- The element rides in through Combat.dealDamage (Combat.strikeElement), so the effect is a plain blow.
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
