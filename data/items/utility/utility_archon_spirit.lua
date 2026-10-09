-- SPIRIT BODY: what an Archon IS, granted by its race (data/races/archon.lua) into the first free cell of every
-- Archon ever minted. Reviewed 2026-10-09 ("The Crown's Bestiary", round 2).
--
-- When the bearer falls, its spirit is torn loose as a wisp three tiles off, and the wisp walks back to the body
-- to stand it up at half health (models/spirit.lua). Once: an Archon that falls a second time stays down.
-- Bound and unstealable.
return {
    name = "Spirit Body",
    description = "When felled, a wisp tears loose and walks back to the body. If it arrives, the body stands at half.",
    flavor = "The court does not let its own dead go either.",
    sprite = "assets/items/utility_archon_spirit.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_spirit_body" },
}
