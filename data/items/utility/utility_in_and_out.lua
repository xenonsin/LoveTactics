-- IN AND OUT: the thing wolves do, taken off a wolf.
--
-- The Alpha Wolf's drop, and the clearest example in the game of docs/drops.md's best idea -- "the two
-- things it DOES, rebuilt as gear somebody could carry". You have spent the whole wolf line being bitten
-- by something that is never there when you swing back (weapon_wolf_fangs.lua). This is that, and
-- nothing else.
--
-- WHAT IT ACTUALLY BUYS IS THE COUNTER YOU DO NOT TAKE. A melee counter is thrown once the whole action
-- has resolved and re-checks reach at that point (data/traits/trait_melee_counter.lua,
-- Combat.beginAnswers), so a body that has already stepped out of adjacency is answered by nothing.
-- Against a line of parries, thorns and ripostes -- which is most of what the deep floors field -- that
-- is worth more than a damage line, and it is worth nothing at all against a foe with no reflex. A real
-- decision rather than a flat upgrade, which is what a piece at this depth ought to be.
--
-- AND IT COSTS POSITION, every time, honestly. The step is away from the body you just hit, so it walks
-- you out of your own reach too: you cannot stand and trade with this on, and a front-liner holding a
-- line will find it pulling them off it. It is a skirmisher's charm and it makes you fight like one
-- whether or not that was the plan. The blocked step is the other half -- backed into a wall or a
-- packmate, it simply does not move, and then you eat the counter like anyone else (Combat.giveGround
-- tries straight back, then either lateral lane, then nothing).
--
-- IT WORKS WHEN YOU ANSWER, TOO, which is the half worth paying for. A Reprisal Quiver or a melee
-- counter of your own throws its blow and this backs you out of the exchange it just started -- the
-- wolf's own trick in the one situation a player is usually helpless in.
--
-- `class = "skirmisher"`, which is where this mechanic already lives: ability_harrying_strike is on
-- that shelf and its own comment calls it "the Hit-and-run mechanic's first stock". A class is the
-- vendor shelf and never an equip gate -- anyone may carry this (docs/classes.md).
--
-- Unpriced: it comes off the alpha and nowhere else, and `dropTier` is set by the grading pass
-- (`. drop-tier`) rather than chosen here. Melee only, by reach -- see Combat.charmGivesGround for why
-- the gate is the weapon's range rather than a `melee` tag.
return {
    name = "In and Out",
    description = "After a melee blow lands, step back one tile. Answers a blow the same way.",
    flavor = "The Lodge teaches it to nobody. Everyone who survives a pack works it out unassisted.",
    sprite = "assets/items/in_and_out.png",
    type = "utility",
    tags = { "beast" },
    class = "skirmisher",
    unlockLevel = 2,
    -- RIFT-ONLY. It comes off the body and nowhere else: no counter deals one however many
    -- the company carries out, and none will buy one back (docs/drops.md, Vendor.foundPrice).
    unstocked = true,
    traits = { "trait_in_and_out" },
}
