-- The Heartwood Bond: what the Hamadryad IS -- a dryad whose life is in her tree. The rule is Heartwood
-- (data/traits/trait_heartwood.lua): her tree is planted beside her at the bell, and while it stands no
-- blow kills her. Bound: it is the elite's own rule, not a relic she carries (docs/bestiary.md).
return {
    name = "Heartwood Bond",
    description = "Starts each battle with her tree beside her; she cannot die while it stands.",
    flavor = "A hamadryad is not the tree's spirit. She is the part of the tree that learned to walk away from it, and has to come back.",
    sprite = "assets/items/heartwood_bond.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    traits = { "trait_heartwood" },
}
