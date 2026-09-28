-- STATIC: the charges an Arc -- or whoever wears its Static Coil -- has stored by walking (models/storm.lua). One a
-- tile, to 5; the next lightning cast spends them all at +3 damage each. Rooted, Stunned or Grounded, the charge
-- runs out into the floor and is wasted (trait_static).
return {
    name = "Static",
    abbr = "Stc",
    description = "Stored charge: the next lightning cast deals +3 damage per charge.",
    color = { 0.560, 0.580, 0.900 }, -- badge tint (arc)
    duration = math.huge,
    hideDuration = true, -- the count is the story
    hideLog = true,      -- a step at a time; the badge is the news
    magnitude = 1,
    stacks = 99,         -- a count, not a cap: Storm.stepped holds it at Storm.STATIC_MAX
}
