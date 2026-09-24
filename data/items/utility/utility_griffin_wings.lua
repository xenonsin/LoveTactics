-- The Griffin's wings: they carry On the Wing (data/traits/trait_on_the_wing.lua), Slay the Spire's Byrd --
-- three stacks that halve every blow, stripped one a blow, and a crash when the last goes. Natural kit.
return {
    name = "Griffin's Wings",
    description = "Flies with three stacks, halving every blow. Each blow strips one; the last grounds it and inflicts Stun.",
    flavor = "It does not fly far. It does not need to. It only needs to be where your sword is not.",
    sprite = "assets/items/utility_griffin_wings.png",
    type = "utility",
    class = "creature",
    tags = { "natural", "beast" },
    noSteal = true,
    traits = { "trait_on_the_wing" },
}
