-- A homunculus's natural weapon (the alchemical counterpart to the elementals' Tide/Flame Fists): a
-- clammy, dripping blow that leaves the struck foe Poisoned (data/status/poison.lua). The construct
-- is frail and hits softly, so the toxin is the point -- a homunculus is a shambling poison-ticker
-- that wears a foe down over the turns it survives. `noSteal`: there is nothing here worth pocketing.
return {
    name = "Homunculus Fists",
    description = "Strikes an adjacent foe and inflicts Poison.",
    flavor = "The construct is frail and hits softly. The toxin does the work, and it has nothing but time.",
    sprite = "assets/items/homunculus_fists.png",
    type = "weapon",
    tags = { "natural", "poison", "physical", "melee" },
    noSteal = true,
    activeAbility = {
        target = "enemy",
        range = 1,
        speed = 3,
        cost = { stat = "stamina", amount = 5 },
        damage = { 4, 4, 5, 5, 6, 6, 6, 7, 7, 8, 8 },
        effect = function(fx)
            if fx.damage(fx.target) > 0 then
                fx.applyStatus(fx.target, "status_poison")
            end
        end,
    },
}
