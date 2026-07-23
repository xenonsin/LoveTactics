-- A bow, so it shoots at range with a dead point-blank band (docs/weapons.md). Its extra is the ground it
-- lights: where the shaft lands, a patch of hazard_witchlight is left burning -- harsh light in which
-- nothing can hide from being targeted.
--
-- Quest-only: `class` with no `price`.
--
-- The difference from data/items/weapon/weapon_limning_bow.lua, which marks a BODY, is the whole reason
-- both exist: a mark answers the assassin you managed to hit, and a lit square answers the one you have
-- not found yet. This is the bow you shoot at an empty corridor, at the doorway the enemy has to come
-- through, at the patch of dark the rogue went into. It is anti-stealth as area denial rather than as
-- retaliation -- the archer painting the board instead of the target.
--
-- The light OUTLIVES whoever was standing there, which is what makes it area denial rather than a mark:
-- kill the scout the shaft was aimed at and the square it died on stays lit for several turns, so the
-- next thing to step into that doorway is visible the moment it arrives.
--
-- Unsided, as ground generally is: your own hidden rogue standing in it is exactly as visible. An archer
-- and an assassin in the same party have to talk about where this goes.
return {
    name = "The Witchlight Bow",
    description = "Fires at range and leaves harsh light where the shaft lands: nothing standing in it can hide.",
    flavor = "The Lodge burned three of them before someone thought to ask what the light was for rather than what it was made of.",
    sprite = "assets/items/witchlight_bow.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "light", "ranged" },
    hands = 2,
    class = "hunter",
    activeAbility = {
        target = "enemy",
        range = 3,
        minRange = 2,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 7 },
        -- Under an iron bow's: the light is the weapon and the arrow is how it gets delivered.
        damage = { 3, 4, 4, 5, 5, 6, 6, 7, 7, 8, 8 },
        effect = function(fx)
            fx.damage(fx.target)
            -- Laid on the aimed CELL rather than on the body, which is the whole point: the light stays
            -- when the target dies or walks off it, so the square keeps answering for the shot.
            fx.placeHazard(fx.tx, fx.ty, "hazard_witchlight", { duration = 12 + fx.level })
        end,
    },
}
