-- Crowd's Favour: the loop half of the Champion (fighter x knight). A charm that widens the Defiance
-- pool to the whole rank -- it banks when the ally BESIDE you is struck, not only when you are, and it
-- deepens the pool by two on top.
--
-- No trait and no effect: it is a `charge` declaration and nothing else, which is the whole point of the
-- pool being merged rather than owned (Combat.chargeDef). Defiant Stand says Defiance fills from
-- `hitTaken`; this says it also fills from `allyStruck`; a Champion carrying both fills from either, and
-- neither file mentions the other. The second charm DEEPENS the pool rather than opening a rival one --
-- "your Defiance" has to name one number or it names nothing.
--
-- It is also the item that makes the Champion a formation piece rather than a duellist. Standing in the
-- line pays even on the turns nobody swings at you, which is the difference between holding a wall and
-- being a wall.
return {
    name = "Crowd's Favour",
    description = "Defiance also banks when an ally beside you is struck, and your pool runs deeper.",
    flavor = "They cheer for whoever is still standing. He intends that to keep being him, and them.",
    sprite = "assets/items/utility_crowds_favour.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "champion",
    price = 380,
    repRank = 3,
    charge = { key = "defiance", from = { "hitTaken", "allyStruck" }, max = 8 },
}
