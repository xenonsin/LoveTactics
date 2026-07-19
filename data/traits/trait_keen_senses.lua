-- Keen Senses: the priest feels the blow coming before it is thrown, and answers first. Alone among
-- the reflexes, this one does not wait its turn -- the counter resolves BEFORE the attack that
-- provoked it, so a foe who swings and dies to the answer never lands the swing at all. That is the
-- whole of what it buys: not a bigger number, but the order of the exchange.
--
-- The comparison worth holding is the sword's. All three are priced identically -- an answer costs
-- what the swing that answers costs, doubling with each answer already thrown this round (see
-- Trait.answerCost in models/trait.lua) -- so what separates them is only WHAT they buy:
--
--   parry (trait_parry.lua)     -- take the blow, then answer it. A trade.
--   riposte (trait_riposte.lua) -- turn an adjacent melee blow aside AND answer. Not a trade.
--   this                        -- answer FIRST; take the blow anyway if they still stand.
--
-- It declares no hook: like Dodge and Riposte, the pre-hit reflex lives in the model (Trait.tryPreempt,
-- consulted from Combat.dealFlatDamage before mitigation), because a hook (onDamaged) only ever fires
-- on a blow that has ALREADY landed, and this one must go first.
--
-- Tuning: it is the only one of the three that leaves the bearer taking the hit anyway when the answer
-- fails to kill, which is what pays for going first. On a priest -- 40 stamina, 1 regen a tick, and
-- every point of it also wanted for casting -- answering a whole flurry is a real decision and not a
-- free reflex, because the second answer in a round costs double and the third quadruple.
--
-- It answers anything, arrow or blade or spell, but only from a tile something in the bearer's grid can
-- reach back at (Combat.answeringWeapon, dead zones included): senses this keen are wasted if you
-- cannot reach what you sensed.
return {
    name = "Keen Senses",
    description = "You feel the attack coming and strike first, spending a swing's stamina. Kill them and the blow never lands.",
    preemptsAttack = true, -- read by Combat.dealFlatDamage (via Trait.tryPreempt) before mitigation
}
