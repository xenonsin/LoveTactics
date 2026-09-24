-- THE CROWN OF THE COURT: one of the two things that come off the Moss King
-- (data/characters/character_moss_king_slime.lua), and only off him.
--
-- His court, called. Cast it and two Moss Sloughlings stand up beside you, each carrying a tenth of your
-- health; they fight, and whichever walks back to you Rejoins and returns what it has left
-- (ability_rejoin). A company member's version of the King's own fight -- the court is a store of health
-- you have to keep alive long enough to bring home.
--
-- `unstocked`: visible on the Lodge's rack and never sold (docs/drops.md).
return {
    name = "Crown of the Court",
    description = "Two moss sloughlings stand up beside you. Each that rejoins you returns its health.",
    flavor = "A king is mostly the people standing near him.",
    sprite = "assets/items/utility_crown_of_the_court.png",
    type = "utility",
    tags = { "summon" },
    class = "hunter",
    unlockLevel = 2,
    unstocked = true,
    activeAbility = {
        target = "self",
        range = 0,
        support = true,
        speed = 5,
        cost = { stat = "stamina", amount = 10 },
        cooldown = 40,
        effect = function(fx)
            local hp = fx.user.char.stats.health
            local health = math.max(1, math.floor(hp.max * 0.1 + 0.5))
            for _ = 1, 2 do
                local x, y = fx.openTileNear(fx.user.x, fx.user.y)
                if not x then break end
                fx.summon("character_moss_sloughling", x, y, { noClaim = true, stats = { health = health } })
            end
        end,
    },
}
