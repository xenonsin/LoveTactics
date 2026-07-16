-- Magic Denied: the bearer cannot work magic. Not "cannot afford it" and not "cannot speak it" -- the
-- craft is simply shut to them, so a mana spell, an enchanted blade, and a magical relic are all
-- equally inert in their hands (Combat.isMagicItem draws the line; Status.deniesMagic is the read, and
-- Combat.itemBlockReason the one gate that acts on it).
--
-- The reusable half of the Skeptic's Harness. The armor does not hard-code its own drawback: it grants
-- the Magic Denial trait, which lays this status at the opening bell (data/traits/magic_denial.lua).
-- Anything else that wants the effect -- a cursed relic, an enemy's hex, a story beat where the party
-- walks into a dead zone -- applies this same status and gets the same rules, including the greyed-out
-- slots and the tooltip note, for free.
--
-- WHY IT IS NOT A DEBUFF, which is the interesting decision here. `debuff = true` would put it in
-- Cure's and Panacea's reach, and for an armor-granted denial that is an exploit with a bow on it:
-- drink a Panacea, wash away the harness's only drawback, keep its magic defense, cast freely. The
-- status therefore states what it is -- a condition, not an affliction. A hex built on it would be
-- uncleansable too, and that is the honest trade for the reuse: anything that wants a *curable*
-- version wants Silence (data/status/silenced.lua), which already exists and already ticks away.
--
-- The duration is the battle. A status that lasts as long as a thing is WORN has no natural tick count
-- -- the grid is fixed for the fight, so "while worn" and "this battle" are the same interval -- and
-- math.huge survives Status.tick's countdown unchanged (huge minus elapsed is huge). The badge stays up
-- the whole time on purpose: the player is looking at greyed-out spell slots and deserves to be told
-- why, every turn, rather than having to remember what their own armor does.
return {
    name = "Magic Denied",
    abbr = "NoMag",
    description = "Cut off from magic: no spell, enchanted weapon, or arcane relic will work.",
    color = { 0.45, 0.45, 0.52 }, -- badge tint (leaden grey: the absence of the arcane violet)
    duration = math.huge,         -- "while worn" == "this battle"; see the note above
    -- There is no countdown to show -- the number is infinity, and a tooltip reading "inf" ticks is
    -- worse than no number at all. The badge still stands the whole battle (that is the point: the
    -- player staring at greyed-out spell slots deserves to be told why); it just doesn't pretend to be
    -- counting down to anything. Same call, same reason, as data/status/channeling.lua.
    hideDuration = true,
    deniesMagic = true,
}
