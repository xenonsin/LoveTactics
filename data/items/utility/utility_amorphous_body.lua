-- What a slime HAS instead of a hide (data/characters/character_slime.lua). A bound relic in the
-- Volatile Core's shape (data/items/utility/utility_volatile_core.lua): not gear anyone shops for,
-- it is what the thing is, delivered as a grid item because that is the reliable way a rule reaches a
-- unit (models/trait.lua) -- and because an immunity carried on a piece with a NAME is an immunity the
-- combat log can say out loud.
--
-- IT DECLARES AN IMMUNITY RATHER THAN A RESIST, and the two are different purchases. A `resist` is
-- subtractive and floors at 1, so a scratch is still a hit -- it counters, it feeds Rimebitten, it
-- wakes a sleeper -- and no pile of it ever reaches zero (docs/vulnerability.md). There is no number
-- large enough to say "there is nothing in here for an edge to part". `immune` says it: a blow
-- carrying one of these tags is voided outright, before armour, before the floor, spending nothing.
--
-- ALL FOUR PHYSICAL WORDS, because they are four independent claims. `physical` is what almost every
-- weapon in the game carries alongside its family word, but not quite all of them do, and a body that
-- turned aside a sword and not a bare fist would be a bug nobody could see. Naming the family words
-- too costs one line each and closes it.
--
-- AND AN ELEMENT STILL LANDS. Status.immuneToDamage answers an ITEM's immunity with any element on the
-- blow, which is the clause that makes this body a puzzle rather than a wall: a plain sword does
-- nothing, a sword under the Dawn Chrism does everything, and a demon's claws -- `physical, slash,
-- fire` since docs/bestiary.md made the Host burn -- go straight through it. The lesson the body
-- teaches is "bring an element", and it must not also punish the player for bringing one on a blade.
--
-- The `immune` table is the armour half and is deliberately NOT a trait: Trait.flag goes dark under
-- Sundered, and a dispel that made a slime cuttable would be a second, hidden answer to the body that
-- no line of text anywhere promises. What Sundered does take is the adaptation's strike element, which
-- is a reaction and reads as one.
return {
    name = "Amorphous Body",
    description = "Voids blades, points and blows. Takes on elements, and gains Interest.",
    flavor = "You can put a sword through it. You have simply put a sword through it.",
    sprite = "assets/items/amorphous_body.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    bound = true,
    noSteal = true, -- a creature's body is not loot
    immune = { physical = true, slash = true, pierce = true, impact = true },
    -- GREED'S RULE (2026-09-24): the swamp's slimes compound -- each turn alive, more Damage and a
    -- fuller purse when they fall (trait_interest). Every circle's slime line carries one of its own.
    traits = { "trait_adaptive", "trait_interest" },
}
