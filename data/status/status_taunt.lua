-- Taunt: a jeer that pulls a foe's whole attention. While it lasts, the taunted unit's AI must go
-- for the taunter with its default weapon and nothing else (Combat.planEnemyAction reads the taunt
-- and its `.taunter`, set by the Shout effect on the status instance). A debuff, so Cure clears it.
-- It carries no statBonus: the compulsion IS the effect. Applied by Shout (data/items/ability).
return {
    name = "Taunt",
    abbr = "Tnt",
    description = "Enraged: must attack the taunter with its default weapon.",
    color = { 0.90, 0.40, 0.30 }, -- badge tint (angry red)
    duration = 15, -- ~3 turns at Status.TICKS_PER_TURN: long enough to hold a foe's attention
    debuff = true,
}
