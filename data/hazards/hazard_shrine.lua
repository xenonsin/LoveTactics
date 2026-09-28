-- A SHRINE: a meditation stone laid on the board by the Meditation Hall (data/encounters/
-- encounter_wrath_the_meditation_hall.lua). It does nothing to anybody who steps on it; what it does is to a
-- rule. An asura standing on one does not cool -- its chi does not drain on an idle turn (Asura.onShrine) --
-- so a hot asura parked on a shrine stays hot, and the fight is about moving them off.
--
-- NEUTRAL: nothing here hurts or heals, so the AI neither seeks nor avoids it by its disposition. The asura's
-- own turn does not need to seek it either; it only has to be standing there when it waits.
return {
    name = "Shrine",
    description = "An asura standing here does not cool: its chi does not drain.",
    tags = {},
    duration = 9999, -- laid for the fight, and it outlasts it
    disposition = "neutral",
}
