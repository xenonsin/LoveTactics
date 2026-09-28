-- Asura: monks who turned their discipline to war, and Wrath's fifth people (reviewed over two rounds on
-- 2026-09-27/28, "The Asura of Wrath"). Not oni -- the oni's whole identity is the horn -- and drawn from
-- Japanese and Southeast Asian imagery: Ashura's three faces, the Niō at the temple gate, the Thai yak.
--
-- WHAT THE RACE IS lives in its blood (utility_asura_blood, granted): the monk's own chi, with the vow broken
-- (models/asura.lua). It fills when an asura is struck, it drains on a turn it is left alone, and a full pool
-- is thrown at the nearest foe whether the asura would or not. ARMS ARE RANK, and they are organs on the
-- bodies rather than a race rule, because a rung has as many as it has earned.
--
-- HUMANOID because it fights with the monk's shelf, and only a humanoid may carry one (tests/bestiary_spec.lua).
-- The stat line is quickness: bodies that punch more often than they are punched (speed +1, skill +1).
-- NOT PLAYABLE and not hireable -- approved on review: the Broken Vow is how a company takes the rule.
return {
    name = "Asura",
    description = "Monks who turned their discipline to war. Their chi fills from pain, and it will not keep.",
    kind = "humanoid",
    bonus = {
        speed = 1,
        skill = 1,
    },
    grants = { "utility_asura_blood" },
    playable = false,
}
