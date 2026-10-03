-- STONE HEART: what the Homunculus drops (data/characters/character_red_homunculus.lua; "Envy's Bestiary",
-- 2026-10-03, slice C). Its red stone turned to the bearer's use: every kill stores a Red Stone, to 3, and a blow
-- that would kill the bearer consumes one and leaves it at 1 health (trait_stone_heart).
--
-- The author's note on round 2's drop was "the drop already exists" -- a once-a-fight rising is Second Wind -- so
-- this one is built on the stone count instead, and the page's text said "Stone"; it reads "Red Stone" here, the
-- name the count carries (status_red_stone), so the two never read as Medusa's petrify stacks.
--
-- An Apothecary's: keeping a body from the last blow is that shelf's work. An unstocked trophy on the seat's rung.
return {
    name = "Stone Heart",
    description = "Each kill stores a Red Stone, to 3. A blow that would kill you consumes one and leaves you at 1 health.",
    flavor = "It is warm, and it is not yours, and it beats anyway.",
    sprite = "assets/items/utility_stone_heart.png",
    type = "utility",
    tags = { "charm" },
    class = "apothecary",
    unlockLevel = 12,
    unstocked = true,
    traits = { "trait_stone_heart" },
}
