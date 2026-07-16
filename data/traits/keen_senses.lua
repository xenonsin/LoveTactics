-- Keen Senses: the priest feels the blow coming before it is thrown, and answers first. Alone among
-- the reflexes, this one does not wait its turn -- the counter resolves BEFORE the attack that
-- provoked it, so a foe who swings and dies to the answer never lands the swing at all. That is the
-- whole of what it buys: not a bigger number, but the order of the exchange.
--
-- The comparison worth holding is the sword's. All three are priced the same way -- stamina per firing
-- plus a cooldown (see payCost in models/trait.lua) -- so what separates them is only WHAT they buy:
--
--   parry (data/traits/parry.lua)     -- take the blow, then answer it. A trade.      4 stamina / 20 ticks
--   riposte (data/traits/riposte.lua) -- turn an adjacent melee blow aside AND answer. 6 stamina / 16 ticks
--   this                              -- answer FIRST; take the blow if they still stand. 6 stamina / 12 ticks
--
-- It declares no hook: like Dodge and Riposte, the pre-hit reflex lives in the model (Trait.tryPreempt,
-- consulted from Combat.dealFlatDamage before mitigation), because a hook (onDamaged) only ever fires
-- on a blow that has ALREADY landed, and this one must go first.
--
-- Tuning: the SHORTEST cooldown of the three, at a riposte's price. That is the shape of the trade --
-- a parry answers hardest-to-exhaust, a riposte answers best, and this answers most OFTEN, but it is
-- the only one of the three that leaves the bearer taking the hit when it fails to kill. On a priest --
-- 40 stamina, 1 regen a tick, and every point of it also wanted for casting -- countering a whole flurry
-- is a real decision and not a free reflex. It answers anything, arrow or blade or spell, but only from
-- within the reach of the bearer's own default weapon: senses this keen are wasted if you cannot reach
-- what you sensed.
return {
    name = "Keen Senses",
    description = "You feel the attack coming and strike first, spending stamina. Kill them and the blow never lands.",
    preemptsAttack = true,                   -- read by Combat.dealFlatDamage (via Trait.tryPreempt) before mitigation
    magnitude = 12,                          -- cooldown ticks after a counter (a riposte's is 16, a parry's 20)
    cost = { stat = "stamina", amount = 6 }, -- paid per counter; no stamina, no answer
}
