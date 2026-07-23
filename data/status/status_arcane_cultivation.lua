-- Arcane Cultivation: borrowed talent. The magical half of the elixir shelf -- a flat lift to Magic
-- Damage for a long window (data/items/consumable/consumable_elixir_of_the_adept.lua).
--
-- The mirror of Giant's Vigour (data/status/status_giants_vigour.lua), and deliberately a separate
-- status rather than one elixir with a choice in it: a drinker should be able to hold both open at
-- once, and two statuses in flatStat's sum is how that falls out without anyone writing a rule for it.
-- A battlemage who drinks the pair is running on nothing but other people's gifts, which is a fair
-- description of the shelf that sold them.
--
-- A BUFF, so Cure leaves it be.
return {
    name = "Arcane Cultivation",
    abbr = "Arc",
    description = "Borrowed talent: raised Magic Damage.",
    color = { 0.55, 0.45, 0.85 }, -- badge tint (steeped violet)
    duration = 45, -- ~9 turns at Status.TICKS_PER_TURN, matching its muscular twin
    statBonus = { magicDamage = 10 },
}
