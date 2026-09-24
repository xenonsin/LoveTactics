-- THE MOSS HEART: one of the two things that come off the Moss King
-- (data/characters/character_moss_king_slime.lua), and only off him.
--
-- His death, worn. The King does not die, he comes apart; so does its bearer, once a battle
-- (trait_come_apart): a felling blow leaves them at 1 health with three Moss Sloughlings spilling out
-- around them, and bringing those pieces home is how they get back up.
--
-- `unstocked`: visible on the Lodge's rack and never sold (docs/drops.md).
return {
    name = "The Moss Heart",
    description = "Once per battle, a felling blow leaves you at 1 health instead, and three moss sloughlings spill out.",
    flavor = "It was the only part of him that had ever been in one piece.",
    sprite = "assets/items/utility_moss_heart.png",
    type = "utility",
    tags = { "protective" },
    class = "hunter",
    unlockLevel = 3,
    unstocked = true,
    traits = { "trait_come_apart" },
}
