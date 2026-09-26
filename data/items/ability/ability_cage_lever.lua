-- THE CAGE LEVER: the Goblin King's other lever (approved in round 2, 2026-09-26). One lever opens a cage instead
-- of a trapdoor and lets a Goblin Fanatic loose -- the Fanatic's lane on top of the trapdoor rows makes two
-- things to read, and less floor every turn. One loose at a time: the summoner rule (Combat.activeSummon) keeps
-- the lever silent while its Fanatic lives. A body's own, never shelved.
return {
    name = "The Cage Lever",
    description = "Lets a Goblin Fanatic loose from its cage. One at a time.",
    flavor = "The cage is not to keep it in. The cage is to keep the court alive until it is needed.",
    sprite = "assets/items/ability_cage_lever.png",
    type = "ability",
    tags = { "summon" },
    class = "creature",
    noSteal = true,
    activeAbility = {
        target = "self",
        range = 0,
        speed = 4,
        cooldown = 20,
        support = true,
        cost = { stat = "stamina", amount = 6 },
        ai = { priority = "high", act = "cast" },
        effect = function(fx)
            local user = fx.user
            -- The cage stands off the throne's flank: two tiles out, wherever there is floor.
            local x, y = fx.openTileNear(user.x + 2, user.y)
            if not x then x, y = fx.openTileNear(user.x, user.y) end
            if not x then return end
            fx.summon("character_goblin_fanatic", x, y)
        end,
    },
}
