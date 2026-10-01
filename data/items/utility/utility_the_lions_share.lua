-- THE LION'S SHARE: the Lion's organ (data/characters/character_lion.lua; trait_the_lions_share). He goes for
-- the prey his lionesses hold, and his kill roars. Bound and unstealable.
return {
    name = "The Lion's Share",
    description = "Goes for held prey first. When it makes a kill, every lioness heals 20% and foes within 2 are Rattled.",
    flavor = "He was asleep for the hunt. He is awake for this.",
    sprite = "assets/items/utility_the_lions_share.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_the_lions_share" },
}
