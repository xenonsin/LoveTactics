-- NERVELESS BONES: the Dwarf Skeleton's. There are no nerves left to jolt: a Stun or a Sleep still lands,
-- and costs its bearer no time (trait_nerveless). The counter to the floor it comes from -- the ghoul's
-- claws and the wight's touch -- and to every shove in the game. Approved 2026-09-25, round 3.
return {
    name = "Nerveless Bones",
    description = "Stun and Sleep do not delay your turn.",
    flavor = "Tap the knee. Nothing. Tap it again. It looks at you.",
    sprite = "assets/items/utility_nerveless_bones.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    unlockLevel = 5,
    unstocked = true,
    traits = { "trait_nerveless" },
}
