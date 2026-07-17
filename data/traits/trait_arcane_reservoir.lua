-- A body that slowly rekindles magic no other can. The bearer's mana regenerates a little each tick
-- (Combat.ARCANE_REGEN) -- uniquely breaking the game's "mana never regenerates" rule, which is why
-- it is the exception that proves it: everyone else's mana regen is zero. Like Overchannel and
-- Sanctified Presence, the recovery loop reads this as a capability (Combat.regenerate checks
-- Trait.has "trait_arcane_reservoir"), so the def carries no hook.
return {
    name = "Arcane Reservoir",
    description = "Your mana slowly regenerates -- the one pool that does.",
}
