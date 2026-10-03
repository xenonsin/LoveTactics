-- A FACE FOR EVERY KILL: the Faceless Assassin's organ (data/characters/character_faceless_assassin.lua). Reviewed
-- 2026-10-01..03 ("Envy's Bestiary", round 2). Its hand is its kills, it walks in disguised, its first blow out of
-- any face is a critical, and a companion it downs is worn at once and remembered by the save
-- (data/traits/trait_a_face_for_every_kill.lua). Bound and unstealable, and carried into every face it wears.
return {
    name = "A Face for Every Kill",
    description = "Its hand is the faces of what it has killed. Its first blow out of any face is a critical.",
    flavor = "It does not remember the names. It remembers the faces, and wears them.",
    sprite = "assets/items/utility_a_face_for_every_kill.png",
    type = "utility",
    tags = { "natural" },
    class = "creature",
    noSteal = true,
    bound = true,
    traits = { "trait_a_face_for_every_kill" },
}
