-- The Crucible Golem's hands: two slabs of fired clay, swung slowly and mostly as an afterthought.
-- A `natural` weapon (docs/weapons.md) -- a creature's own body, granted by its blueprint's
-- startingItems, never sold and never stolen.
--
-- It also CARRIES THE GOLEM'S GUARD (data/traits/trait_bulwark.lua), and that is the only reason this
-- exists as its own file rather than the golem simply borrowing weapon_stone_fists. Traits attach to a
-- unit from grid items and from nowhere else: Trait.attach reads `unit.char.traits`, but
-- Character.instantiate builds the runtime character field by field and never copies a blueprint's
-- `traits`, so a guard declared on the character blueprint would be silently dead data. The hands are
-- therefore where the guard lives -- which is a fair description of the thing anyway.
--
-- `noSteal`, as every natural weapon is. Stealing a golem's arms is not a play the game supports, and
-- more to the point it would strip the guard off the wall mid-fight through a mechanic aimed at
-- inventories.
return {
    name = "Golem Fists",
    description = "Slabs of fired clay. Slow, heavy, and not really the point.",
    flavor = "The Crucible spent its care on the shoulders. The hands were what was left over.",
    sprite = "assets/items/golem_fists.png",
    type = "weapon",
    tags = { "natural", "impact", "physical", "melee" },
    noSteal = true,
    traits = { "trait_bulwark" }, -- the wall's guard rides on the body, since blueprint traits do not attach
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 6, -- ponderous, like the rest of it
        damage = { 5, 5, 6, 6, 7, 7, 8, 8, 9, 9, 10 },
        effect = function(fx)
            fx.damage(fx.target)
        end,
    },
}
