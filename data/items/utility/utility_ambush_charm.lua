-- THE AMBUSH CHARM: the Sabertooth's crit, lent to a person's weapons. Every weapon beside this charm in the
-- grid lands a critical on a turn you opened Invisible (the `critUnseen` aura, read by Combat.forcesCrit).
-- Asked for in round three in place of a pitched Waiting Knife: "Utility, adjacent weapons get guaranteed
-- critical when starting the turn invisible."
--
-- THE PAYOFF FOR A SHELF THAT HAD NONE. The ninja hides three ways -- the Smoke Mantle, Vanishing Strike,
-- Mirror Image -- and the rogue's Unlit Hood a fourth, and every one of them ended with the body hidden and
-- nothing to spend it on. "Opened Invisible" is Combat.unseenFor: still hidden when the turn arrived, or
-- veiled at its top, so a strike that vanished you last turn counts. On the ninja's shelf, beside the
-- Smoke Mantle it most often rides with.
return {
    name = "Ambush Charm",
    description = "Adjacent weapons land a critical on a turn you open Invisible.",
    flavor = "A bone bead on a gut string. It makes no sound at all, which is the point of it.",
    sprite = "assets/items/utility_ambush_charm.png",
    type = "utility",
    tags = { "illusion" },
    class = "ninja",
    unlockLevel = 2,
    unstocked = true,
    aura = {
        appliesTo = { "weapon" },
        critUnseen = true,
    },
}
