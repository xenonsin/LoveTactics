-- Djinn: the spirits of Pride's spire, and its second race. Reviewed 2026-09-30 ("Pride's Bestiary"): "djinns are
-- powerful mages with NO master in this world".
--
-- A NEW RACE RATHER THAN `elemental`, though its kind is elemental. The elemental race is coarse on purpose -- an
-- element with an outline, authored body by body, granting nothing -- and every djinn shares one rule that
-- belongs on the race the way a goblin's Blood Feud does: WILL NOT STOOP (utility_will_not_stoop). A djinn casts
-- and never swings; a foe beside it at the top of its turn sends it blinking four tiles clear, and a djinn with
-- nowhere to go is Shamed and loses the turn. Each body keeps its own element in its own `resist`, which is the
-- elemental race's argument and still true here.
--
-- KIND `elemental`: smokeless fire and moving air, with no blood for a vampire to drink (models/thirst.lua).
--
-- THE STAT LINE is the mage's (magic damage +2): bound to nobody, and answerable to nobody for what they cast.
--
-- NOT PLAYABLE: a djinn serves no one, and a company is somebody to serve.
return {
    name = "Djinn",
    description = "Spirits of the spire with no master in this world. They cast, and they will not stoop to fight.",
    kind = "elemental",
    playable = false,
    bonus = {
        magicDamage = 2, -- powerful mages
    },
    grants = { "utility_will_not_stoop" },
}
