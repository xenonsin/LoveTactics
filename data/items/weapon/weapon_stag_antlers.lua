-- STAG ANTLERS: what a stag actually has, and the last body coming off weapon_fangs.
--
-- data/items/weapon/weapon_tusks.lua finished half of this split and named the other half in its own
-- header: "The stag is now the only body on `weapon_fangs`, which is one leftover instead of two."
-- This is that one. The teeth were authored for the wolves and their flavor line still says so ("A
-- wolf is born holding it"); an Ancient Stag was carrying them because nobody had written it anything.
--
-- PIERCE, NOT BITE, for the reason the tusks give in full: nothing in the game carries a `bite` resist
-- -- not one coat, not one blueprint -- so for as long as the stag bit you, its ordinary blow was a
-- melee attack no armour could answer. Two animals were doing that; now none are.
--
-- IT SWEEPS A RANK, WHICH IS THE FAMILY CONTRACT. Both other antlered bodies in this game already
-- declare exactly this footprint and nothing else was ever going to be right here:
--
--   weapon_hoarfrost_antlers   front, width 3, and it Freezes what it catches   (The Winter Hart)
--   weapon_antler_crown        front, width 3, and it Charms what it catches    (The Hartwood Bride)
--   this                       front, width 3, and it does not catch anything else
--
-- Those two sit on 2x2 apexes where being reached at all is the threat, and each carries a condition
-- to say so. This is the tier-2 member of that family, and what it gets is the family's REACH without
-- the family's rider: it hits the rank in front of it, and that is all it does. The counterplay is the
-- oldest one in the genre and needs no teaching -- do not stand in a line in front of it.
--
-- THE DAMAGE IS UNDER A JAB'S ON PURPOSE. weapon_tusks and weapon_fangs both ramp 5->15 into one body;
-- this ramps 4->14 into as many as three. A sweep that also hit for a jab's number would make standing
-- anywhere near this animal strictly worse than standing near a boar, which is a claim a tier-2 road
-- body is not entitled to make. Against a single target it is the weaker weapon, and that is correct:
-- what it is buying is the second and third body, which the PLAYER chooses whether to supply.
--
-- AND IT THROWS WHATEVER REACHES IN (trait_antler_toss, below). The rack is not only a blow, it is the
-- reason you cannot stand beside the thing -- a stag gets its head under whatever touched it and
-- lifts. It rides the weapon rather than a separate charm for weapon_wolf_fangs' reason: every
-- antlered body could carry this and no other body should, where utility_feral_instinct is shared with
-- the boar, the bear and every wolf and would hand the reflex to half the wilds.
--
-- A natural weapon: no class, no price, noSteal (tests/bestiary_spec.lua).
local Curve = require("models.curve")

return {
    name = "Antlers",
    description = "Sweeps a three-wide rank. Throws back whatever strikes it in melee.",
    flavor = "Grown for arguing with other stags. Nobody has ever managed to tell it the difference.",
    sprite = "assets/items/stag_antlers.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true, -- grown from the skull; a pickpocket has nothing to lift
    traits = { "trait_antler_toss" }, -- see the header: it rides the rack, not a shared charm
    activeAbility = {
        target = "enemy",
        range = 1,
        -- Slower than a bite and a jab (both 2), matching the two apex racks' own relationship to their
        -- bodies: a sweep is a head coming round, not a snap. It is also most of what pays for the
        -- second and third body in the footprint.
        speed = 4,
        cost = { stat = "stamina", amount = 6 },
        damage = Curve.ramp(4, 14), -- one under a jab at both ends (5->15); see the header
        aoe = { shape = "front", width = 3 },
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                fx.damage(u)
            end
        end,
    },
}
