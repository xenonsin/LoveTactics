-- Wrath: the visible face of the `wrath_rising` trait (data/traits/trait_wrath_rising.lua). It grants
-- nothing on its own -- no statBonus, no hook. The trait already added the damage to the unit's
-- per-battle bonus; this badge exists so the player can watch the number climb and understand,
-- before it is too late, that a long trade is how she wins.
--
-- The number tracks MISSING HEALTH, not blows landed: it steps up as she is emptied, so the badge and
-- her health bar tell the same story from opposite ends. A player who notices that the badge grows
-- fastest exactly when they are closest to winning has understood the fight.
--
-- Deliberately not the mechanic. A statBonus here would double-count the trait's own addBonus, and
-- a status cannot scale its bonus by magnitude anyway (Status.statBonus reads the static def table).
return {
    name = "Wrath",
    abbr = "Wth",
    description = "Awake, and worse for it: every blow it takes sharpens the next one it lands.",
    color = { 0.8, 0.15, 0.15 }, -- badge tint (arterial red)
    duration = 999,       -- rage does not cool; it lasts the battle
    hideDuration = true,  -- the countdown is meaningless -- the magnitude is the story
    magnitude = 0,        -- overwritten each hit with the total damage banked
}
