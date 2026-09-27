-- BLOODHOUND'S SCENT: the Fledgling's second drop (data/items/utility/utility_bloodhounds_scent.lua). The vampire
-- tag's Scent of Blood made a thing a living hunter can carry: +2 movement on a move that ENDS next to a bleeding
-- foe (Combat.reachable reads `scent = "beside"`), and +20% of your own Damage against a bleeding foe.
return {
    name = "Bloodhound's Scent",
    description = "Move 2 further when the move ends next to a bleeding foe. Deal 20% more damage to bleeding foes.",
    scent = "beside",
    damageBonusVs = function(ctx)
        return require("models.thirst").scentDamage(ctx)
    end,
}
