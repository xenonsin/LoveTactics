-- Encounter blueprint. THE LID THAT BITES: the fight a treasure chest turns into when the chest was
-- never a chest (models/mimic.lua).
--
-- `weight = 0`, and this one is stronger than the dark's. The three hazards carry a zero so the
-- CAMPAIGN pool never deals them and the descent's own pool can; this carries one so that NO pool ever
-- deals it, at any depth, in any mode. The only thing in the game that can seat this fight is a hand
-- on the wrong lid -- because a mimic that could also turn up as a marked fight on open ground would
-- be a monster that is sometimes disguised, and the disguise is the entire monster.
--
-- A CAST OF ONE, authored rather than rolled. Two mimics is two chests, standing in two places.
--
-- NO `loot` OF ITS OWN, and that absence is the design: what this fight pays is what the chest was
-- holding, which is not knowable until the lid is touched. Mimic.spring stamps it onto the cell as
-- `carried`, the body is armed from it, and EncounterBattle.spoils pays it out -- one list, read
-- twice, with nothing authored here to fall out of step with it.
return {
    name = "Mimic",
    kind = "elite",
    weight = 0,
    minDay = 1,
    composition = { "character_mimic" },
}
