-- TUSKS: what a boar actually has, and the reason weapon_fangs is no longer on one.
--
-- `weapon_fangs` was authored for the wolves and its flavor line still says so ("A wolf is born
-- holding it"). Every wolf in the game moved to `weapon_wolf_fangs` and the split left two animals
-- behind on the wolf's blueprint -- a boar and a stag, neither of which bites anything. This is the
-- boar's half of finishing that split. The stag is now the only body on `weapon_fangs`, which is one
-- leftover instead of two; see docs/bestiary.md on why a shared blueprint splits rather than lies.
--
-- PIERCE, NOT BITE, and the retag is the mechanical half of this file. Nothing in the game carries a
-- `bite` resist -- not one coat, not one blueprint -- so for as long as the boar bit you, its ordinary
-- blow was the rare melee attack no armour in the game could answer. A tusk is a point, `pierce` is
-- what a point is, and the whole argument of the bestiary's resist section is that mitigation should
-- pose a puzzle rather than a flat number. A boar you can turn aside with the right coat is a better
-- boar, and it was never meant to be otherwise.
--
-- Deliberately UNREMARKABLE. A boar standing still and jabbing is not the threat; the threat is
-- ability_gore, and a standing blow that competed with the charge would give the animal no reason to
-- commit to one. This is what it does on the turns it could not line you up.
local Curve = require("models.curve")

return {
    name = "Tusks",
    description = "Gores an adjacent foe.",
    flavor = "Two teeth that never stopped growing, worn to a point on everything it ever ate.",
    sprite = "assets/items/tusks.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "pierce", "physical", "melee" },
    noSteal = true, -- grown from the skull; a pickpocket has nothing to lift
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 2,
        cost = { stat = "stamina", amount = 5 },
        damage = Curve.ramp(5, 15),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
