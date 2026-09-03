-- RARE. The descent's own rule inverted: the company recovers nothing between fights -- no camp, no
-- larder, no post-fight heal -- and hits far harder for it. A floor becomes one continuous fight.
--
-- THE RULE FIRES ONCE: recovery is already fully off at one copy and there is nowhere further down to
-- go, so the ladder is the damage alone.
--
-- The only relic here that reads the RUN rather than the board, which is why it is the one that most
-- changes how a descent is played rather than how a fight is. It gags The Deep Larder, The Kept Vigil's
-- mana half and every camp -- worth a spec line so a camp does not silently refund underneath it.
return {
    name = "The Unpaid Tithe",
    blurb = "+%d%% damage. The company recovers nothing between fights.",
    tier = "rare", mark = "Ut",
    cost = "Every point of health is the last one you get.",
    scale = { 50, 25 },
    rules = { noRecovery = true, damageMultiplier = true },
    ruleScale = { damageMultiplier = { 1.5, 0.25 } },
}
