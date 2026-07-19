-- Riposte: the fencer's move the Riposte Blade is named for, and the only reflex in the game that
-- both NEGATES a blow and answers it. A melee attack the bearer can see coming is turned aside on the
-- blade -- it deals nothing at all -- and the same motion drives the point back into the attacker.
--
-- The distinction from data/traits/parry.lua, which every ordinary sword carries, is the whole point
-- of the weapon. A parry is a trade: you take the hit, then you answer it. A riposte is not a trade --
-- the attack simply fails, and the attacker is punished for having made it. That is a categorical
-- difference rather than a bigger number, which is what the blade was missing when its only claim was
-- a shorter cooldown than the sword every recruit carries.
--
-- It declares no hook: like Dodge (data/traits/dodge.lua) and Smoke Screen, the pre-hit reflex lives
-- in the model -- Trait.tryRiposte, consulted from Combat.dealFlatDamage before mitigation -- because
-- a hook (onDamaged) only ever fires on a blow that ALREADY landed, and this one must never land.
--
-- Tuning: priced as a swing by Trait.answerCost, exactly like the parry it replaces -- so what the
-- Riposte Blade buys is not a cheaper or more frequent answer but a categorically better one, which
-- is the point made above. What bounds it is the escalating price of answering repeatedly in one
-- round (a second riposte costs double, a third quadruple) and the bearer's stamina pool.
--
-- It is far narrower than Dodge, which slips any physical hit from any range: this one only answers a
-- material blow from an ADJACENT foe -- an arrow, a spell, a poison tick, or a trap all go straight
-- through a raised guard. Attack it from two tiles away and the blade is just a sword.
return {
    name = "Riposte",
    description = "Spend a swing's stamina to turn an adjacent melee attack aside entirely and run the attacker through.",
    deflectsMelee = true,  -- read by Combat.dealFlatDamage (via Trait.tryRiposte) before mitigation
}
