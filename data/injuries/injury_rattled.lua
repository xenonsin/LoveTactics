-- RATTLED: a head that took the floor and has not been right since.
--
-- Three points off Skill and one off Speed -- worse aim, worse crit (docs/accuracy.md: skill raises both)
-- and later in the order. The only kind in the set that touches initiative at all, which is why it keeps
-- the second stat: a body that is merely less accurate is Torn Shoulder wearing a different word, and one
-- word per mechanic cuts both ways.
--
-- HALF OF BLIND'S CUT, and the halving is the point. data/status/status_blind.lua calls -6 "most of a
-- body's aim" and spends eight ticks and a whole turn to apply it; this is permanent and arrives for
-- free on a bad roll, so it takes half and leaves the body worth fielding. The roster is authored on a
-- 0-10 skill band and sits at 2-8, so three points is about six points of Hit -- readable in the
-- forecast, survivable in a fight.
return {
    name = "Rattled",
    description = "Rattled: aims worse, and acts later.",
    -- The shallowest of the seven with Burst Lung, so a camp's field dressing takes it first: a night's
    -- rest is exactly the thing a rattled head responds to, and blood is not.
    severity = 1,
    weight = 10,
    reserve = { health = 0.06 },
    effects = { { id = "status_rattled" } },
}
