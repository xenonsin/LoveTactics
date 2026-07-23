-- A Grasping Hollow: soft ground that closes on the first thing to step into it each beat. Anything
-- entering is Rooted -- it may still act, swing and answer, it simply may not walk out this turn.
--
-- Roots on ENTRY, which is a genuinely different kind of zone from everything else in this catalog and
-- the reason it is worth having. Quicksand taxes you for standing in it, fire hurts you for standing
-- in it, a sanctuary mends you for standing in it -- all of them price OCCUPANCY, so all of them are
-- answered by not going there. This prices the CROSSING. It is worth nothing against a line that was
-- going to hold its ground and everything against a line that has to come to you, which makes it the
-- knight's zone rather than the mage's: sloth does not kill you, it decides where you stand.
--
-- The root lands on entry through the ordinary onEnter hook, so it catches a walk, a shove, a pull and
-- a trample alike -- being thrown into the hollow is exactly as sticky as walking into it, which is
-- what lets a knight pair it with a mace. It does NOT catch a blink or a swap, on the same rule every
-- per-tile effect in this game follows (see Status.onEnterTile): you cannot be caught by ground you
-- never crossed.
--
-- Rooted `lingers`, so unlike most zone grants this one travels: step in, and the hold comes with you
-- for its own duration rather than lifting the moment you are clear. That is the whole bite of it --
-- the hollow does not need to be big, because what it takes is the step AFTER the one into it.
return {
    name = "Grasping Hollow",
    description = "Sucking ground: roots whatever steps into it.",
    sprite = "assets/hazards/grasping_hollow.png",
    tags = { "earth" },
    duration = 18,           -- ~3.5 turns of held ground
    disposition = "hostile", -- the enemy AI paths around it rather than through
    onEnter = function(ctx)
        ctx.applyStatus(ctx.unit, "status_root")
    end,
}
