-- Dodge: a fighter's evasive reflex. It automatically slips the next PHYSICAL blow to land -- the
-- bearer takes no damage from it at all -- and then must recharge for a spell before it can evade
-- again. A magical hit is not something you can sidestep, so it passes straight through.
--
-- Kin to the Melee/Ranged Counter traits: a passive, auto-triggered reflex gated by a cooldown (keyed
-- on this trait's id, recharged in Combat.rebase alongside status durations). But where a counter
-- REACTS to a survived hit (onDamaged), a dodge must VOID the hit before it lands -- so it works like a
-- barrier rather than a hook: Combat.dealFlatDamage consults Trait.tryEvade before mitigation and, if
-- this reflex fires, deals 0 and starts the cooldown. `magnitude` is the cooldown length in ticks.
return {
    name = "Dodge",
    description = "Automatically evade a physical attack, then recharge before evading again.",
    magnitude = 12,        -- cooldown ticks after a dodge
    evadesPhysical = true, -- read by Combat.dealFlatDamage (via Trait.tryEvade) before mitigation
}
