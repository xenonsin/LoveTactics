-- A hammer, so it stuns and it is ponderous (docs/weapons.md) -- and it is the most ponderous thing in
-- the game. Speed 10 where the iron hammer takes 7, for a stun that runs twice as long.
--
-- The family contract says you buy the stun with your own tempo. This is that sentence with the volume
-- turned all the way up, and it exists to prove the trade is real rather than decorative: nothing else in
-- the catalog costs this much of the timeline, and nothing else takes a body off it for this long.
--
-- What it actually produces is a one-for-one trade of turns at a scale that changes the fight. The
-- wielder disappears down the turn order and so does the target, and whichever side has more bodies left
-- moving wins the exchange. So it is a weapon for a full party against a boss, and close to suicide for a
-- lone fighter -- which is the opposite of how the rest of the fighter shelf reads.
--
-- The shelf's top rung alongside the Sleeper's Maul, and the pair is the two ways to remove a turn:
-- durable and expensive here, longer and fragile there.
return {
    name = "The Slow Verdict",
    description = "The slowest swing in the game, for a stun that lasts twice as long.",
    flavor = "The Colosseum times it with a water clock rather than a count. Nobody has ever complained that it was rushed.",
    sprite = "assets/items/slow_verdict.png",
    type = "weapon",
    tags = { "hammer", "impact", "physical", "melee" },
    hands = 2,
    class = "fighter",
    price = 660,
    repRank = 4,
    activeAbility = {
        target = "enemy",
        range = 1,
        -- The whole price, in one number. Ten ticks is most of two ordinary turns.
        speed = 10,
        cost = { stat = "stamina", amount = 14 },
        -- Above an iron hammer's, because it has to be: a swing that costs this much of the timeline and
        -- did not also land heavily would never be worth taking off the rack.
        damage = { 15, 16, 18, 19, 21, 22, 24, 25, 27, 28, 30 },
        effect = function(fx)
            -- Double the stun's declared magnitude, which is what a Stun's initiative shove reads
            -- (data/status/status_stun.lua). The status rides IN the blow for the family's usual reason
            -- -- control applied afterwards arrives too late to stop the counter.
            fx.damage(fx.target, { inflicts = { id = "status_stun", magnitude = 12 } })
        end,
    },
}
