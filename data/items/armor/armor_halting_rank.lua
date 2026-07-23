-- Bastion rank-4. Heavy plate whose extra is an ACTIVE: loosed, it Halts every adjacent foe -- they
-- cannot use any ability on their next turn (status_halted). Movement and reflexes are untouched.
--
-- NOT A SHIELD, and the reason is worth recording because it was very nearly one. The shield family is
-- full: docs/weapons.md gives every shoppable family exactly ten weapons, five on a shelf and five
-- quest-only, and the shield's ten are all authored (tests/weapon_spec.lua counts them). An eleventh
-- shield would have to displace one, and none of the ten deserved displacing for this. So the Halt
-- rides on the rank's plate instead of on its boss -- which turns out to be the better home anyway: a
-- shield's whole verb is the Wait swap, and this item's verb is a turn spent SPEAKING rather than
-- bracing. Two verbs on one object would have made a worse shield and a worse order.
--
-- THE SHELF'S OWN WORD, AS A THING YOU WEAR. docs/classes.md gives the knight `halted`, and until now
-- the only things that could say it were an ability (Stand Down, single target, range 2) and a pike.
-- An area version is a different claim: Stand Down picks one foe and asks the knight to spend a turn
-- being a commander, and this asks them to be standing in the middle of four people and spend a turn
-- being a wall that talks.
--
-- Sloth INFLICTED rather than suffered, which is the reading the whole Bastion line is built on
-- (docs/story.md). Halted deliberately leaves the target's feet and its answers alone, so it is not a
-- second Stun: a halted enemy still walks, still parries, still counters. What it loses is the turn it
-- was going to spend doing something clever.
--
-- Priced in stamina AND mana for the same reason Stand Down is: an order is a working, not a bark, and
-- any mana in the price makes the cast sorcery (docs/weapons.md) -- so a silenced knight cannot give
-- it and is left holding an ordinary, very good cuirass. That is the cap, and it is one the enemy can
-- reach for.
return {
    name = "The Halting Rank",
    description = "Halts every adjacent foe: none of them may use an ability on its next turn.",
    flavor = "The Bastion beats the rim once. The drill is that nothing on the far side of it has anything to say.",
    sprite = "assets/items/armor_halting_rank.png",
    type = "armor",
    tags = { "heavy", "plate" },
    class = "knight",
    price = 700,
    repRank = 4,
    bonus = { defense = { 9, 10, 11, 12, 13, 14, 14, 15, 16, 17, 18 }, movement = -2 },
    resist = { physical = { 3, 3, 4, 4, 4, 5, 5, 5, 5, 6, 6 }, impact = { 2, 2, 3, 3, 3, 4, 4, 4, 4, 5, 5 } },
    activeAbility = {
        target = "tile",
        allowOccupied = true,
        range = 1,
        speed = 5,
        support = true, -- a refusal, not a blow: it reads green and lands no damage
        cost = { { stat = "stamina", amount = 8 },
                 { stat = "mana",    amount = 6 } },
        aoe = { radius = 1, shape = "square" }, -- the eight tiles around the knight, corners included
        effect = function(fx)
            for _, u in ipairs(fx.aoeUnits()) do
                if u.side ~= fx.user.side then
                    -- Duration climbs with the forge, as Stand Down's does: a better-kept commission is
                    -- obeyed a beat longer.
                    fx.applyStatus(u, "status_halted", { duration = 4 + fx.level })
                end
            end
        end,
    },
}
