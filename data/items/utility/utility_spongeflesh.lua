-- What a Verger IS: a body the blade sinks into and comes out of covered in spores. The rule is
-- Spongeflesh (data/traits/trait_spongeflesh.lua) at its full strength here -- every melee blow it
-- survives swoons the hand that struck it. The mantle a company can carry out of the Ossuary does the
-- same a quarter of the time (armor_spongeflesh_mantle). Bound: it is the body, not a thing it carries.
return {
    name = "Spongeflesh",
    description = "Melee attackers are Swooned by the spores their blow shakes loose.",
    flavor = "It does not flinch. There is nothing in there to flinch.",
    sprite = "assets/items/spongeflesh.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    traits = { "trait_spongeflesh" },
}
