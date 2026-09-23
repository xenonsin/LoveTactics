-- QUILLED: a manticore's quill left in the body, and the more of them there are the worse an arrow does.
--
-- The manticore line's one mark (data/characters/character_manticore.lua). Its tail throws them across
-- an area (ability_tail_volley), its hide throws them at whoever works it over (trait_bristle), and every
-- one of them is a stack of this. On its own a quill does nothing but make the next pierce blow land
-- harder -- the Bristleback shape, where a spray is only dangerous because of the sprays before it.
--
-- THE PIERCE TWIN OF FURY SWIPES, and priced the same way. The bear's wound is slash, worked into one
-- body by one animal; this is pierce, laid on whole areas, and ANYBODY's pierce spends it: the
-- manticore's bite, its next volley, and the company's own archers against it. Four stacks at 2 apiece
-- is 8, which is exactly status_vulnerable_pierce -- so a body that has eaten four volleys is where one
-- Barbed Dart already puts it, and never past it.
--
-- IT STACKS BY ITSELF (`stacks`, models/status.lua's Status.apply). Five things apply it, and every one
-- of them simply applies it -- including from inside a damage call's `inflicts`, which is what makes a
-- missed quill lodge nothing. A refresh adds one and restarts the clock.
return {
    name = "Quilled",
    abbr = "Qll",
    description = "Quills in the body: takes 2 more piercing damage for each stack.",
    color = { 0.620, 0.345, 0.180 }, -- badge tint (tawny: a lion's colour, not a wound's)
    -- ~3 turns, refreshed by every quill that lands. Long enough that a volley's stacks are still there
    -- when the next one comes off cooldown (10 ticks), short enough that breaking off lets them fall out.
    duration = 15,
    debuff = true,          -- Cure pulls every quill at once: the counterplay that costs a turn
    magnitude = 1,          -- one quill per application
    stacks = 4,             -- the cap: 4 x 2 = status_vulnerable_pierce's 8 (see the header)
    hideDuration = true,    -- the count is the story, as Fury Swipes does it
    vulnerable = { pierce = 2 },
    vulnerableScales = true, -- the bag above is per stack (Status.vulnerability)
}
