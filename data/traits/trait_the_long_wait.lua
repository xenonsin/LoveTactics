-- The Long Wait: the standing rule of the Poacher's charm of the same name. Blows the bearer strikes at
-- a Rooted or Marked body cannot be answered -- no parry, no riposte, no thorns, no reflecting ward.
--
-- A flag (Trait.flag) read in Trait.mayCounter, which is the single gate every retaliation in the game
-- passes through. So one clause silences all of them at once, and -- because Trait.counterPreview runs
-- through the same function -- the hover preview promises the same silence the swing delivers.
--
-- Read off the ATTACKER, which is the only place it can live: what the charm buys is the trapper's own
-- safety from the thing thrashing in its snare. The snared foe knows nothing about who set it.
--
-- The first draft was a doubled first strike per battle, which the author cut for the better version:
-- a damage number is a thing you calculate, and "it cannot hit you back" is a thing you can see. It also
-- makes the discipline's loop legible -- Quarry's Due paints what the trap catches, and this is what the
-- paint is worth.
return {
    name = "The Long Wait",
    description = "Your blows against a Rooted or Marked body cannot be answered.",
    unanswerableVsHeld = true,
}
