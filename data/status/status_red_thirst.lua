-- The Red Thirst: for a few turns the bearer drinks back most of what it deals. Folded into the same
-- `mods.lifesteal` that a Vampiric Strike charm beside a blade feeds and that a weapon's own declared
-- keyword feeds (Status.lifesteal -> withStatusLifesteal in models/combat.lua), so all three ADD -- a
-- thirsting axe swung under this drinks deeper than either would alone.
--
-- WHAT IT IS FOR. Healing in this game is somebody else's turn: the priest spends an action to keep
-- the fighter up, and the fighter's own contribution to staying alive is armor. This is the other
-- answer -- sustain a character buys by being ON someone, which is the only kind of sustain wrath has
-- any business selling. It is worth nothing at all in a turn spent walking, and it is worth the whole
-- fight in a turn spent in the middle of three bodies.
--
-- It stacks with the charm rather than replacing it, and that is deliberate rather than generous: the
-- charm costs a grid slot forever and pays a little always; this costs a turn and pays enormously,
-- briefly. Building for both is a real loadout, and it is a fragile one -- it does nothing whatsoever
-- against a foe it cannot reach, and the whole of it is undone by an Unclosing Wound.
return {
    name = "The Red Thirst",
    abbr = "Thst",
    description = "Thirsting: drinks back most of the damage it deals.",
    color = { 0.76, 0.14, 0.20 }, -- badge tint (deep arterial)
    duration = 12,                -- ~2.5 turns of drinking
    lifesteal = 0.75,             -- the share of its own damage the bearer mends for
}
