-- Rattled: the Skill-and-Speed half of data/injuries/injury_rattled.lua.
--
-- HALF OF BLIND'S CUT, and the halving is the whole calibration. data/status/status_blind.lua calls -6
-- "most of a body's aim" and spends a whole turn and eight ticks to apply it; this is permanent, arrives
-- free on a bad roll, and has to leave the body worth fielding -- so it takes half. Against the roster's
-- authored 0-10 skill band (which sits at 2-8 in practice) three points is about six points of Hit:
-- readable in the forecast, survivable in a fight.
--
-- THE SECOND STAT IS WHAT MAKES IT ITS OWN INJURY. A body that is merely less accurate is Torn Shoulder
-- wearing a different word. The point off Speed puts it later in the order (Combat reads speed through
-- flatStat and doubles it into initiative), which is the one axis nothing else in the set touches -- and
-- it is what "has not been right since" actually looks like on a board.
--
-- See data/status/status_shattered_leg.lua for why `debuff = false`.
return {
    name = "Rattled",
    abbr = "Rttl",
    description = "Rattled: aims worse, and acts later.",
    color = { 0.420, 0.392, 0.502 }, -- badge tint (dim slate, Blind's neighbourhood)
    duration = 9999,
    debuff = false,
    statBonus = { skill = -3, speed = -1 },
}
