-- What a Fire Elemental is made of, and the vessel its two rules ride in.
--
-- A creature's rule lives on an ITEM in its grid -- a blueprint's own `traits` field is never collected
-- (models/trait.lua) -- so both of the things this body does are authored here rather than on the
-- blueprint. Natural kit: no class, no price, noSteal (tests/bestiary_spec.lua).
--
-- TWO RULES ON ONE PIECE, WHICH IS UNUSUAL AND IS THE POINT. They are not two features: they are the
-- same sentence pointed at the two things a body can do, which is stand still and move. Stand still and
-- it charges whoever reaches for it (data/traits/trait_wanting_costs.lua). Move and it closes the ground
-- behind it. There is nothing a Fire Elemental can do with a turn that does not cost the room something,
-- which is what makes a `defensive` posture on a body this frail into a real problem rather than a
-- delay.
--
-- THE TRAIL IS LAID BEHIND, NEVER UNDERFOOT (Combat.layTrail), so this needs no fire immunity of any
-- kind -- the bearer is simply never standing in its own print, and stays one step ahead of its own
-- ground. Walk back over what you left and you take it exactly as anyone else would.
--
-- AND THE FIRE IS UNSIDED, exactly as the Cinderstride Boots' is: hazard_fire burns whoever enters it,
-- with no reading of sides at all. On the rift's side of the board that is what closes a corridor. On
-- the player's -- because `ability_summon_fire_elemental` calls this same body -- it is what makes where
-- a summoned elemental walks a decision rather than a free one, and it is the single largest change to
-- what that ability fields.
return {
    name = "Living Flame",
    description = "Whoever damages it catches fire, and it sets the tile it steps off alight.",
    flavor = "Somebody paid for this to be lit. The paying is the only part that is over.",
    sprite = "assets/items/living_flame.png",
    type = "utility",
    class = "creature",
    tags = { "natural" },
    noSteal = true,
    traits = { "trait_wanting_costs" },
    -- Eight ticks, the Cinderstride Boots' own duration: long enough that a line of it is still there
    -- when the company wants the corridor back, short enough that a long fight does not end with the
    -- whole floor alight.
    trail = { hazard = "hazard_fire", duration = 8 },
}
