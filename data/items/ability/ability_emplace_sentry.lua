-- Emplace Sentry: the Crucible bolts a crossbow to a tripod, winds it, and walks away. Binds an Ordnance
-- Sentry (data/characters/character_ordnance_sentry.lua) -- a construct that cannot move at all and
-- shoots four tiles.
--
-- The workshop's third body, and it completes the set by answering the question the other two do not.
-- Summon Homunculus buys a thing worth having because of what it leaves when it dies; Summon Golem buys a
-- thing whose entire worth is that it does not die (data/items/ability/ability_summon_golem.lua). Both
-- are answers to "put a body over there". This is the answer to "threaten over there" -- the first
-- construct on the shelf bought for what it does to a tile it is not standing on.
--
-- WHY IT IS ENVY'S. The golem's file makes the argument and this inherits it: the alchemist does not
-- become braver, it buys somebody else's courage out of a vat. Here it does not become a marksman
-- either -- it buys a marksman's reach, sets it on the floor, and remains exactly as short-ranged as it
-- was. The Lodge spends a career learning to hold a lane; the Crucible spends mana and has one by the
-- end of the turn, and cannot carry it anywhere.
--
-- The reservation is the lightest of the three (0.2, matching the Homunculus) because what it buys is
-- the most conditional: a golem is useful wherever it stands, and this is useful only where the fight
-- comes to it. The `duration` is generous for the same reason -- it needs the turns to earn back a lane
-- it can never re-choose.
--
-- NOT tagged with a `discipline`. Read as Artificer (mage + alchemist) in docs/classes.md's table, but
-- data/disciplines/ does not exist yet -- there are no blueprints and nothing loads them, so a
-- `discipline` field here would be dead data claiming a system that has not been built. It goes on the
-- alchemist's shelf, where the other two constructs are, and it can be re-homed the day the folder does.
return {
    name = "Emplace Sentry",
    description = "Bolts down a crossbow sentry that cannot move and fires four tiles. Reserves a fifth of your max mana.",
    flavor = "The Crucible will not teach you to shoot. It will sell you something that already can.",
    sprite = "assets/items/ability_emplace_sentry.png",
    type = "ability",
    tags = { "summon" },
    class = "alchemist",
    price = 400,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 2, -- set down beside you: you carried it here
        speed = 6,
        reserve = { stat = "mana", percent = 0.2 },
        effect = function(fx)
            fx.summon("character_ordnance_sentry", fx.tx, fx.ty, {
                -- Scales into DAMAGE, barely into health: forging this buys a sentry that hits harder,
                -- never one that survives being closed on. Making it durable would erase the dead zone's
                -- counterplay by another route (see weapon_sentry_bolt.lua).
                scaling = { damage = 1, health = 1 },
                amount = 10 + fx.level,
                duration = 30,
            })
        end,
    },
}
