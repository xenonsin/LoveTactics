-- OVERPOWERED: one turn in which a bear's claws stop being expensive.
--
-- Great Claws costs 12 stamina and a bear regains 3 or 4 a tick, which makes the animal's whole engine a
-- rate limiter: one swing, then stand there and earn the next one. That is correct as the default -- it
-- is what keeps a compounding passive from compounding freely -- and it is also what would stop the ramp
-- ever paying off, because four stacks at one swing per four ticks is most of a fight. This is the
-- window where that rule is suspended, and it is bought (ability_overpower.lua), not given.
--
-- HALF, AND ONLY FOR A TURN. `costMultiplier` is the same knob Mired doubles and the Graven circle cuts
-- to three quarters, so the vocabulary is one the game already has. Half rather than free: an animal that
-- swung for nothing would not be spending anything to burst, and the whole point of the burst is that it
-- is a decision about a bar.
--
-- It is not a buff to what the blows DO. Nothing here touches damage -- the extra damage is the wound
-- deepening (status_fury_swipes), which is the bear earning it a swing at a time. This only buys the
-- swings.
return {
    name = "Overpowered",
    abbr = "Ovp",
    description = "Ability and movement costs are halved.",
    color = { 0.804, 0.639, 0.310 }, -- badge tint (gold -- a window, not a wound)
    -- ~1 turn at Status.TICKS_PER_TURN. It has to cover the turn it was bought in and not the one after:
    -- a two-turn window would let a bear bank the discount and open with it, which is a different and
    -- much stronger ability than the one that was priced.
    duration = 5,
    costMultiplier = 0.5,
}
