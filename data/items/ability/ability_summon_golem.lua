-- Summon Golem: Final Fantasy Tactics' Golem, the summon nobody cast for its damage -- it stood in
-- front of the party and let the damage happen to it instead. Binds a Crucible Golem
-- (data/characters/character_crucible_golem.lua): the heaviest body in the game, which takes the first
-- blow each turn aimed at whoever is standing beside it (data/traits/trait_bulwark.lua).
--
-- It is the alchemist's second construct and the deliberate opposite of its first. Summon Homunculus
-- (data/items/ability/ability_summon_homunculus.lua) buys a frail thing whose worth is the Poison it
-- leaves after it dies; this buys a thing whose entire worth is that it does not die. One shelf, one
-- workshop, two answers to "put a body over there" -- which is the pattern docs/weapons.md keeps
-- recommending, a base and two named things pulling in opposite directions.
--
-- WHY IT IS ENVY'S AND NOT THE KNIGHT'S, since a guard is knight vocabulary and the borrow needs
-- saying out loud (docs/classes.md: an unexplained borrow is indistinguishable from a mistake). The
-- knight's Oathward is a body the knight is standing in -- it is the wall, personally, and the oath is
-- the whole character. This does not make the alchemist braver or tougher by a single point. It buys
-- somebody else's courage out of a vat and stands THAT in the way, and when the clay is finished the
-- alchemist is exactly as soft as it was before. Covetous rather than valorous: the shelf's line is
-- "covets others' power rather than casting its own", and the purest form of that is a wall you did
-- not have to become.
--
-- The mana reservation is the cost, and it is the heaviest of the three summons on purpose (Homunculus
-- 0.2, Earth Elemental 0.25, this 0.35). It is held for as long as the golem stands, so a caster with
-- a golem on the board is a caster running a third of a pool short -- an alchemist who summons this and
-- then wants to do anything else that turn has miscounted. See ability_summon_water_elemental.lua for
-- how `reserve`, `scaling`, `duration` and the one-at-a-time rule work.
return {
    name = "Summon Golem",
    description = "Binds a heavy clay golem that guards whoever stands beside it. Reserves a third of your max mana.",
    flavor = "The Crucible will not make you braver. It will sell you something that already is.",
    sprite = "assets/items/ability_summon_golem.png",
    type = "ability",
    tags = { "summon" },
    class = "alchemist",
    price = 480,
    repRank = 3,
    activeAbility = {
        target = "tile",
        range = 2,
        speed = 7, -- slower to raise than the others; there is a great deal more of it
        reserve = { stat = "mana", percent = 0.35 },
        effect = function(fx)
            fx.summon("character_crucible_golem", fx.tx, fx.ty, {
                -- Scales into HEALTH, barely into damage: forging this buys a longer-lived wall, never
                -- a better attacker. An upgrade path that made it hit harder would be selling a
                -- different item than the one described above.
                scaling = { health = 4, damage = 0.25 },
                amount = 10 + fx.level, -- base 10, +1 per upgrade level
                duration = 24,
            })
        end,
    },
}
