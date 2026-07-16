-- A bear's natural weapon: the heavy end of the beast shelf, where data/items/weapon/fangs.lua is the
-- light one. Slower to swing and far more expensive in stamina than a bite, and it hits like a
-- greatsword the wielder grew.
--
-- Given to the Dire Bear (data/characters/dire_bear.lua), which is a shape a hunter wears rather than
-- a thing anyone fights, so like Fangs it is `natural`, `noSteal`, and sold by nobody. The family tag
-- carries no shared contract of its own (see Item.ARCHETYPES) -- what a creature's body does is the
-- creature's business.
return {
    name = "Great Claws",
    description = "Rend an adjacent foe with a bear's forepaws.",
    sprite = "assets/items/great_claws.png",
    type = "weapon",
    tags = { "natural", "slash", "physical", "melee" },
    noSteal = true, -- a pickpocket cannot lift the claws off a bear's hands
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 7, -- ponderous: a bear swings once where a wolf bites twice
        cost = { stat = "stamina", amount = 12 },
        damage = { 16, 17, 18, 19, 21, 22, 23, 24, 26, 27, 28 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
