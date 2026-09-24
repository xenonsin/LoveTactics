-- COME APART: the Moss Heart's rule (data/items/utility/utility_moss_heart.lua), and the Moss King's
-- own death handed to whoever put him down.
--
-- Once per battle, a blow that would fell the bearer instead leaves them standing at 1 health, and
-- three Moss Sloughlings spill out around them, each carrying a tenth of their health. The bearer is
-- still on the board and still in danger; the pieces are their way back, and each one that walks home
-- and Rejoins returns what it has left (ability_rejoin).
--
-- Read by Trait.trySurvive through `splitsOnLethal`, beside Second Wind's `revivesOnLethal`, so it
-- catches the same lethal beat by the same road. Once per battle on `stacks`.
return {
    name = "Come Apart",
    description = "Once per battle, a felling blow leaves you at 1 health instead, and three moss sloughlings spill out.",
    splitsOnLethal = true,
    count = 3,
    share = 0.1,
}
