-- Blind: the unit cannot see to fight. It strikes and casts as if half-sighted -- its ability range is
-- cut, and its aim with it.
--
-- THE SKILL CUT IS THE POINT NOW, AND IT USED NOT TO EXIST. This file's header used to open by
-- explaining a workaround: "Range is per ability, not a flat stat, so this can't ride statBonus the way
-- Cripple's movement cut does." That was true, and it meant the game's BLINDING effect did not affect
-- whether you hit anything -- it shortened your reach, which is a different disability wearing the same
-- name. Accuracy made `skill` a flat stat, so the sentence is obsolete and the real effect can finally
-- be spelled.
--
-- IT KEEPS THE RANGE CUT AS WELL, which makes this the heaviest debuff in the game and is a deliberate
-- call rather than an oversight. A blinded body is worse at reaching and worse at connecting, which is
-- what being blind is; and the status costs a whole turn to apply, is removable by Cure, and lasts
-- under two turns. The two halves also land on different builds -- the range cut bites an archer, the
-- skill cut bites everyone -- so keeping both is what stops it being a debuff that only punishes bows.
--
-- `rangeMalus` is read by Status.rangeMalus and folded into Combat.abilityRange, which floors the reach
-- at 1 so a blinded unit can still hit an adjacent foe. `statBonus.skill` rides Status.statBonus into
-- flatStat, exactly as Cripple's movement cut does, and hit% floors at 0 rather than going negative.
return {
    name = "Blind",
    abbr = "Bln",
    description = "Blinded: greatly reduced Skill, and ability range is reduced (never below adjacent).",
    color = { 0.350, 0.333, 0.435 }, -- badge tint (dim slate)
    duration = 8, -- ~1.5 turns at Status.TICKS_PER_TURN (was under one, and so barely landed)
    debuff = true,                -- removable by Cure
    rangeMalus = 2,
    -- -6 is most of a body's aim: the roster is authored on a 0-10 band and sits at 2-8, so this is
    -- twelve points of Hit off almost anyone. That is the right weight for the one status in the game
    -- whose entire subject is not being able to see.
    statBonus = { skill = -6 },
}
