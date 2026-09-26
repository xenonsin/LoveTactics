-- TWO IN ONE: the Goblin Wolf-Rider's rule (data/items/utility/utility_war_saddle.lua). Read by Trait.trySurvive
-- (`dismountsOnLethal`): the first lethal blow re-bodies it instead of killing it. Shot from range (the lethal
-- blow's striker more than a tile off) the rider falls and the WOLF fights on, Seeing Red; struck up close the
-- wolf falls and the RIDER fights on, as a Goblin Cutter.
return {
    name = "Two in One",
    description = "The first lethal blow kills only half: from range, the rider; up close, the wolf.",
    dismountsOnLethal = true,
    riderless = "character_wolf_grunt",
    unhorsed = "character_goblin_cutter",
}
