-- THE TREELINE HORN: the Unseeing's bargain, struck by somebody with eyes.
--
-- What it hands you is not a damage stick, and that is the point. A called boar carries its own Gore
-- (data/items/ability/ability_gore.lua) -- a three-tile lane, committed a full turn before it lands and
-- painted on the board the whole time. So what you are placing is a THREAT WITH A PUBLISHED ADDRESS:
-- the enemy can read exactly where it is going, and the only answers are to leave the line or to stand
-- somewhere it cannot reach. Either one is the enemy moving where you chose.
--
-- Which makes it the odd one out on the summoning shelf. A wolf (ability_summon_wolf) is a second body
-- that bites things; this is a piece of board control that happens to have hooves, and it is worth most
-- in a corridor and least in the open -- the exact inverse of every other summon in the game.
--
-- THE RESERVATION IS THE BARGAIN, and it is his: character_the_unseeing pays for his clan out of
-- himself, a share of his own pool locked away for as long as each animal stands
-- (data/items/ability/ability_the_call.lua). This is that arrangement at one boar, and the ordinary
-- summoner's one-at-a-time rule comes with it -- the horn falls silent while the thing it called is
-- still standing, because fx.summon claims the item unless it is told not to. Deliberately NOT
-- `noClaim`: the lord needs that flag because calling is his whole turn, and a player who could hold
-- four boars would be playing a different game.
--
-- It calls an ORDINARY Wild Boar and binds nothing to it. The lord's clan leaves curse where it falls
-- because his Call strikes that bargain in `opts.traits`; a boar you called is just a boar, and a player
-- who salted their own floor every time one died would have been handed a trap rather than a tool.
return {
    name = "Treeline Horn",
    description = "Calls a wild boar. One at a time; reserves a third of your stamina.",
    flavor = "Two notes, badly. Whatever answers it was not listening for music.",
    sprite = "assets/items/utility_treeline_horn.png",
    type = "utility",
    tags = { "horn", "summon" },
    class = "beastmaster",
    -- SHELVED TWO RUNGS UNDER WHAT THE INSTRUMENT RANKS IT, deliberately, and the reason is the same
    -- blindness that filed the Last Sounder at -14.6. tools/drop_tier.lua prices a summon at the whole
    -- stat block of the body it calls and cannot see a single condition attached to it -- that this one
    -- lapses after twenty ticks, that the horn falls silent for as long as the boar stands, or that a
    -- third of the bearer's stamina is locked away the entire time. Graded flat it reads as a fifth party
    -- member; played, it is one lane, once, at a real cost.
    --
    -- It also has to sit under the chase. Depth IS rarity here (a floor pays the ranks it reaches), so
    -- the horn and the Last Sounder both filed at rank 8 would drop at the same rate -- and this list is
    -- authored the other way round on purpose: the horn is the piece you meet, the Sounder is the one
    -- you are still after.
    dropTier = 6,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    activeAbility = {
        target = "tile",
        range = 2, -- placed at arm's length: WHERE the lane starts is most of what you are buying
        speed = 5,
        cost = { stat = "stamina", amount = 8 },
        support = true, -- calling your own is a kindness: preview green
        reserve = { stat = "stamina", percent = 0.34 },
        effect = function(fx)
            -- IT LAPSES, and that is what makes this the piece you actually see rather than the chase.
            -- Graded as a permanent body the horn came out at 95.9 -- the strongest thing the Unseeing
            -- hands over and dearer than the Last Sounder, which inverts the whole list: a floor pays
            -- by rank, so the strongest piece is the rarest one by construction. A binding that lapses
            -- is the mage's own answer to the same problem (ability_summon_fire_elemental: "cast it
            -- early and it will be gone by the endgame"), and it prices the horn where it belongs --
            -- a lane you get to place roughly once a fight, not a fifth party member.
            fx.summon("character_boar", fx.tx, fx.ty, { duration = 20 })
        end,
    },
}
