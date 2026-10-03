-- THE MANY FACED: the Many Faced One's opener, carried on its crown (data/items/utility/
-- utility_crown_of_a_thousand_faces.lua). At the bell it reads the run's order of circles, chooses its forms and
-- puts the first one on, with that stair's adds (models/many_faced.lua). Everything after the bell rides on
-- status_many_faced, which no form can take off.
return {
    name = "The Many Faced",
    description = "Wears each general above Envy in turn, one share of health each, then splits into a copy of each foe.",
    onCombatStart = function(ctx)
        require("models.many_faced").open(ctx.combat, ctx.unit)
    end,
}
