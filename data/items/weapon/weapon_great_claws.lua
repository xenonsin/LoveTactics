-- A bear's natural weapon: the heavy end of the beast shelf, where data/items/weapon/weapon_fangs.lua is the
-- light one. Slower to swing and far more expensive in stamina than a bite, and it hits like a
-- greatsword the wielder grew.
--
-- Given to the Dire Bear (data/characters/character_dire_bear.lua), which is a shape a hunter wears
-- rather than a thing anyone fights, so like Fangs it is `natural`, `noSteal`, and sold by nobody. The
-- family tag carries no shared contract of its own (see Item.ARCHETYPES) -- what a creature's body does
-- is the creature's business.
--
-- AND NOW BY THE BEARS ANYBODY FIGHTS -- character_bear and character_sow, which are real combatants
-- where the Dire Bear is cargo. That is a share rather than a lie: all three are bears, and every wolf
-- in the game shares weapon_wolf_fangs on the same reasoning. What must NOT be shared is a body's rule,
-- which is why the ramp rides on utility_the_same_wound instead of being welded into this file --
-- weapon_demon_claws was cut from this very blueprint for the mirror of that reason.
--
-- The `slash` tag is load-bearing beyond mitigation now: status_fury_swipes opens a SLASH wound because
-- this is what opened it, and a bear's own hide is weak along that same axis. Retagging this would
-- silently unhook both ends of that.
local Curve = require("models.curve")

return {
    name = "Great Claws",
    description = "Rends an adjacent foe.",
    flavor = "The heavy end of the beast shelf: a bear swings once where a wolf bites twice.",
    sprite = "assets/items/great_claws.png",
    type = "weapon",
    class = "creature",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a pickpocket cannot lift the claws off a bear's hands
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7, -- ponderous: a bear swings once where a wolf bites twice
        cost = { stat = "stamina", amount = 12 },
        damage = Curve.ramp(16, 28),
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
