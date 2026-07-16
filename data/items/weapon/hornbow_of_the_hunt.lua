-- Hunter's Lodge rank-4. Strung with sinew from something the Lodge will not name. Outranges every
-- other bow and needs a clear arc, like all of them.
--
-- The Lodge sells the trophies of sacred beasts and eats the rest. Nobody there asks what happens
-- to a hunter who never stops being hungry -- the first hint of Gluttony.
--
-- Its EXTRA over the plain iron bow (data/items/weapon/iron_bow.lua), which also shoots and also
-- needs its line: the Hornbow rewards the DISTANCE it alone can reach. Every tile past the
-- point-blank band adds a fifth of the shot's power, so a arrow loosed from the far edge of its
-- range 5 lands nearly two-thirds harder than the same arrow at 2 tiles.
--
-- That is the Lodge's doctrine rather than physics: a beast that never learns you are there never
-- braces, never turns, never runs. The shot you take from far enough away is the one that takes it
-- full in the flank. Mechanically it inverts the usual pull of a ranged weapon -- most archers creep
-- to the edge of their band to stay in range, and this one wants the whole field between you and the
-- kill. Its range 5 stops being a safety margin and becomes the damage stat.
return {
    name = "Hornbow of the Hunt",
    description = "A great hornbow that reaches across the field. The further the shot, the harder it lands.",
    sprite = "assets/items/hornbow_of_the_hunt.png",
    type = "weapon",
    tags = { "bow", "pierce", "physical", "ranged" },
    hands = 2, -- two-handed, like every bow
    class = "hunter",
    price = 800,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 5, -- two tiles further than a plain bow
        minRange = 3,
        requiresSight = true,
        speed = 3,
        cost = { stat = "stamina", amount = 10 },
        damage = { 14, 15, 17, 18, 20, 21, 22, 24, 25, 27, 28 },
        effect = function(fx)
            -- Tiles past the point-blank band (minRange 2), each worth a fifth of the shot's power.
            -- Taken off fx.amount rather than a flat number, so the reward climbs with the forge just
            -- as the base shot does. A shot AT the minimum gains nothing -- that is the plain bow's job.
            local dist = math.abs(fx.user.x - fx.target.x) + math.abs(fx.user.y - fx.target.y)
            local reach = math.max(0, dist - 2)
            fx.damage(fx.target, { amount = fx.amount + math.floor(fx.amount * 0.2) * reach })
        end,
    },
}
