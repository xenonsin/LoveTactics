-- Crusader -- fighter x priest multiclass discipline.
-- Signature mechanic: Smite -- holy bonus damage on melee vs demon/undead, heal on kill. The armed
-- faithful; wields weapon_demon_bane (the holy blade already on the knight's shelf).
-- Exemplar: a holy-blade zealot (character_crusader, NEW -- pending), met as a MENTOR/BOSS.
-- Gate: earned advancement -- requires a fighter subclass AND a priest subclass unlocked, which opens
-- quest_cathedral_the_consecrated_march (pending). See docs/disciplines-plan.md.
return {
    name    = "Crusader",
    description = "The armed faithful. Holy bonus damage on demons and undead, and a kill that mends the one who dealt it.",
    classes = { "fighter", "priest" },
    exemplar = "character_crusader", -- NEW, pending
    requiredQuests = { "quest_cathedral_the_consecrated_march" }, -- pending
}
