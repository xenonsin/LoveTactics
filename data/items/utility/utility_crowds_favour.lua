-- Crowd's Favour: the loop half of the Champion (fighter x knight). A charm that widens the Defiance
-- pool to the whole rank -- it banks when the ally BESIDE you is struck, not only when you are, and it
-- deepens the pool by two on top.
--
-- The widening is merged rather than owned (Combat.chargeDef). Defiant Stand says Defiance fills from
-- `hitTaken`; this says it also fills from `allyStruck`; a Champion carrying both fills from either, and
-- neither file mentions the other. The second charm DEEPENS the pool rather than opening a rival one --
-- "your Defiance" has to name one number or it names nothing.
--
-- It carries Still Standing for the same reason Answering Blow declares Defiance: a shelf may not sell
-- half a mechanic. This was a `charge` line and nothing else -- no trait, no effect -- so bought without
-- the spender it deepened a pool nothing could drain and did precisely nothing. The rule in
-- docs/classes.md is not one-directional: a spender must not need a charm to switch it on, and a charm
-- must not need a spender. The trait reads the pool WITHOUT spending it, so the widening still belongs
-- to Answering Blow and the two remain halves of one build rather than one item and its licence.
--
-- It is also the item that makes the Champion a formation piece rather than a duellist. Standing in the
-- line pays even on the turns nobody swings at you, which is the difference between holding a wall and
-- being a wall.
return {
    name = "Crowd's Favour",
    description = "Increase defense by 1 per 2 Defiance held. Also banks Defiance when an ally beside you is struck, and runs deeper.",
    flavor = "They cheer for whoever is still standing. He intends that to keep being him, and them.",
    sprite = "assets/items/utility_crowds_favour.png",
    type = "utility",
    tags = { "charm" },
    class = "fighter",
    discipline = "champion",
    price = 320,
    unlockQuests = 4,
    traits = { "trait_still_standing" },
    charge = { key = "defiance", from = { "hitTaken", "allyStruck" }, max = 8 },
}
