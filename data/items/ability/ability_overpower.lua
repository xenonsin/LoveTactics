-- OVERPOWER: the turn a bear cashes in, and the only thing in its kit that is not a claw.
--
-- THE RAMP NEEDS A WAY TO ARRIVE. Fury Swipes deepens one stack per landed blow and a bear lands about
-- one blow a turn -- Great Claws is 12 stamina against a regen of 3 or 4 -- so four stacks is most of a
-- fight, and the ceiling the wound was priced against would almost never be reached. That is not a bear
-- being slow, it is a payoff nobody gets to. This is the button that breaks the rate limit for one turn,
-- and it is the whole of what the animal does besides swing.
--
-- TWO EFFECTS, BECAUSE IN THIS ENGINE "ATTACK FASTER" IS TWO THINGS. A burst of swings needs the ACTIONS
-- to make them and the STAMINA to pay for them, and either alone does nothing: an extra action with an
-- empty bar is a body standing there, and a discount with no action left is a discount on nothing. So it
-- grants one extra action and halves costs for the turn (status_overpowered), which together turn one
-- swing into two -- two stacks in a turn instead of one.
--
-- PRICED IN STAMINA, NOT ON A COOLDOWN, which is this codebase's standing answer and the better one
-- here. ability_vital_points states it plainly -- a price is a decision, a cooldown is only a delay --
-- and a price is what makes this interesting: the 8 comes out of the same bar the swings do. Overpower
-- into two discounted claws costs 8 + 6 + 6 = 20 against a full swing's 12, so the burst is a real
-- commitment of the animal's whole engine rather than free tempo. A bear that opens with this and then
-- misses has spent most of a bar on nothing, which is the risk that makes it worth pressing at the right
-- moment instead of on turn one.
--
-- `free = true` so the cast bills no initiative of its own. Without it the button would cost the turn it
-- exists to spend -- the same reasoning ability_surge carries, and the same shape: a breath, then the
-- blows.
--
-- Natural kit: no class beyond `creature`, no price, no dropTier, noSteal. A bear's second wind is not a
-- trinket anybody can lift, and a boss's own rule must never reach the drop pool (docs/bestiary.md).
return {
    name = "Overpower",
    description = "Grants an extra action and inflicts Overpowered on yourself.",
    flavor = "The pause between two swings is where the animal usually stops.",
    sprite = "assets/items/ability_overpower.png",
    type = "ability",
    class = "creature",
    tags = { "natural", "beast" },
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 0,      -- a breath bills no tempo of its own (cf. ability_surge)
        free = true,    -- ...and leaves the turn open, so the grant is an EXTRA rather than a swap
        support = true, -- it lands no damage
        cost = { stat = "stamina", amount = 8 },
        effect = function(fx)
            fx.grantExtraAction(1)
            fx.applyStatus(fx.user, "status_overpowered")
        end,
    },
}
