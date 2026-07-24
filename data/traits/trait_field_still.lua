-- Field Still: the standing rule of the Warbrewer's charm. A draught is brewed into the bearer's grid at
-- the top of each of its turns.
--
-- Hangs on the turn-start seam in Combat.startTurn (Trait.flag `brewsEachTurn`), and produces the
-- Herbalist's own reagent rather than a bespoke Warbrewer vial -- deliberately. One field-brewed item
-- shared by the two disciplines that brew is a smaller catalog and a clearer rule: what you make in the
-- field is a reagent, whoever you are.
--
-- Ephemeral, so a still cannot be run as an economy: nothing it makes survives the fight.
--
-- Silent when the grid is full (Combat.grantItem logs its own refusal), which is also the real cost of
-- the item -- a still that keeps producing means keeping a cell empty to catch it.
return {
    name = "Field Still",
    brewsEachTurn = "consumable_wildcraft_reagent",
}
