-- The item form of the Archer's Wolf Companion: a bone whistle that calls a wolf to your side at the
-- opening bell. `traits` on an item reach whoever carries it (models/trait.lua), so anyone -- not just
-- the Archer -- can field a free companion by slotting this. A hunter-class piece, sold at the Lodge.
return {
    name = "Companion Whistle",
    description = "A wolf joins you at the start of every battle.",
    flavor = "Worn smooth by use. The Lodge does not ask where the last wolf went.",
    sprite = "assets/items/companion_whistle.png",
    type = "utility",
    tags = { "beast" },
    class = "hunter",
    price = 300,
    repRank = 3,
    traits = { "trait_wolf_companion" },
}
