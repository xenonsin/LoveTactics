-- THE HELD BREATH: one health, and armour for everything it is missing.
--
-- WAS A RUN RELIC (`relic_held_breath`, rare tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- A UTILITY RATHER THAN ARMOUR, and the type is a real decision rather than a shelf convenience. Armour
-- in this game is one contract -- tests/armor_spec.lua: every coat costs at least a square of pace and
-- buys it back in defense or a resist -- and this piece pays no pace and grants no authored defense.
-- Its armour is a LIVE TERM computed from what the body is missing, which is a rule rewrite, not a coat.
-- Filing it as armour would have meant bending the one table that keeps the coats comparable.
--
-- A RULE REWRITE (`pinHealth`). The armour it buys is NOT resolved at setup -- it is a live term in
-- Combat.flatStat, because it measures against a ceiling other gear raises and a pool a heal can move.
-- Freezing it at the opening bell would quietly lose every interaction it has.
--
-- ON ONE BODY NOW, which is what makes it playable rather than a coin flip: as a relic it pinned the
-- whole company at 1 health. A single pinned body behind three whole ones is a position.
return {
    name = "The Held Breath",
    description = "Pins your health at 1. Raises both armours by 1 for every 4 maximum health you are missing.",
    flavor = "A cord knotted twice at the throat. Whoever wears it speaks in short sentences.",
    sprite = "assets/items/held_breath.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf that fights out of armour and banks what it takes.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "monk",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: a body that cannot be chipped, only killed outright, and armours up as it empties.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 2.40,
    unlockLevel = 14,
    rules = { pinHealth = 0.25 },
}
