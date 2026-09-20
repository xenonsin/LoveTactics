-- SINK THE ANCHOR: the binding that names its own spirit, and the heavy end of the Shaman's hex line.
-- The Anchor goes into one piece of the target's kit and that body does not walk again
-- (data/curses/curse_the_anchor.lua -- `rules.noMove`).
--
-- IT IS A HARD LOCK AND IT IS PRICED AS ONE. Every other way this game stops a body moving is a status
-- with a clock on it -- Stun, Freeze, Mired, Halted -- and all of them end. This does not: a bound hex
-- holds until a priest lifts it, which on an enemy means until the fight does. So the cost is a cast
-- that is expensive, slow, short-ranged and CONDITIONAL, and the condition is the interesting half.
--
-- IT NEEDS SOMETHING TO SINK INTO. The Anchor is an object's curse, so a body with no cursable piece in
-- its grid simply shrugs -- which is not a failure mode, it is the counterplay, and it is legible from
-- across the board once a player has learned to read a beast from a soldier. The things this locks down
-- are armed humanoids; the things that walk over it are wolves, elementals and anything else fighting
-- with its own body (`noSteal`). A boss carrying a bound relic is likewise immune to exactly this,
-- because Curse.canAfflict refuses what is already nailed down.
--
-- UNLIKE LAY THE HEX, THERE IS NO DAMAGE UNDER IT. That is the split between the two: the shallow cast
-- pays a bolt when it finds nothing, because it is the everyday spell and a wasted turn would make
-- players stop taking it. This one is a commitment aimed at a target the caster chose deliberately, and
-- a consolation prize would blunt the decision it exists to be.
return {
    name = "Sink the Anchor",
    description = "Binds The Anchor into a foe's kit: that body cannot move at all.",
    flavor = "Older than the rift, and it has never once been talked out of anything.",
    sprite = "assets/items/ability_sink_the_anchor.png",
    type = "ability",
    tags = { "dark", "magical" },
    class = "shaman",
    -- SLOT 8, WHICH IS THE TOP OF THE LADDER AND NOT A JUDGEMENT ABOUT THIS SPELL. It was authored
    -- at 11 first, and slot 11 does not exist: Balance.maxSlot() takes the SPAN of the ladder off
    -- the catalogue's own highest rung, so one item three rungs above everything else stretched the
    -- line every other item's target sits on and quietly re-scaled all of them downward. A deep
    -- ability belongs at the deep end of the ladder that exists, not past it. Price is slot 8's band.
    price = 740,
    unlockQuests = 8,
    activeAbility = {
        target = "enemy",
        range = 2,
        speed = 10,
        cost = { stat = "mana", amount = 16 },
        description = "Binds The Anchor into one piece of the target's kit: that body cannot move at all.",
        effect = function(fx)
            fx.curse(fx.target, "curse_the_anchor")
        end,
    },
}
