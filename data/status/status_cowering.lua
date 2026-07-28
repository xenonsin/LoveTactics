-- Cowering: flinching from a blow that is already coming down. A unit caught in the strike zone of a
-- committed greatsword wind-up (weapon_first_motion) throws up a guard and gives ground badly -- its
-- movement is cut while the swing hangs over it, so it cannot cleanly stroll out from under the blade.
--
-- Stamped directly on whoever stands in the telegraphed footprint at the moment of commit -- not a
-- terrain effect but a status on the body (see the weapon's `channelAfflict`) -- and it rides the
-- wind-up's own length, lifting about when the blow lands. A fear, not a wound: it forbids nothing, it
-- only shortens the escape, which is the whole counterplay the greatsword's telegraph wants to teach.
--
-- Movement is a flat stat (Combat.moveBudget reads flatStat "movement"), so a plain statBonus does the
-- whole job -- the blue reachable set simply shrinks, exactly as Cripple's does, with no special-case
-- code. A debuff, so Cure strips it.
return {
    name = "Cowering",
    abbr = "Cwr",
    description = "Flinching from an incoming blow: moves fewer spaces.",
    color = { 0.657, 0.623, 0.709 }, -- badge tint (wan violet-grey)
    duration = 6,                 -- ticks the flinch lasts; overridden to the wind-up's length on grant
    debuff = true,                -- removable by Cure
    statBonus = { movement = -2 },
}
