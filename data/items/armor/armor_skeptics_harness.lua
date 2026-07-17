-- The Skeptic's Harness: armor worn by someone who has decided, as a matter of settled fact, that
-- magic is not real. It is wrong. It also works.
--
-- Mechanically it is the game's only piece of NEGATIVE-SPACE gear: everything else on every shelf adds
-- something, and this takes something away and charges you for the privilege. The wearer cannot use
-- magic AT ALL: the harness grants the Magic Denial trait, which lays the Magic Denied status at the
-- opening bell, and that status refuses anything tagged `magical` or paid for in mana
-- (Combat.isMagicItem). Not a debuff, so no Panacea can wash the drawback off and leave the magic
-- defense behind; the only answer is to take the armor off, which is the answer a conviction always
-- has. The effect lives in the status rather than in this file, so anything else that wants it -- a
-- hex, a cursed relic, a dead-zone arena -- can reach for the same rules.
--
-- What it buys is the other half of the conviction: a magic defense no plate in the game matches, and
-- `statusResist` -- the flat ward models/status.lua adds to its resist rating -- which makes magical
-- afflictions land for a fraction of their length, and the repeat ones not at all. A knight in this
-- gets polymorphed for three ticks instead of eight, and by the third attempt is simply not
-- polymorphable. See the resistance contract in models/status.lua.
--
-- The build it makes is the point: it is the answer to an enemy mage, handed to the one character who
-- was never going to cast anything anyway. A fighter or a knight loses a Physical Barrier and some
-- potions-that-aren't (a draught is not magic -- it passes) and gains near-immunity to the school that
-- most reliably takes them out of a fight. A mage who puts it on has retired.
--
-- Sold by the knight's vendor: it is heavy steel with a philosophy, and the sloth line is where a
-- refusal to engage is a virtue (see docs/story.md).
return {
    name = "Skeptic's Harness",
    description = "You cannot use magic at all. Magical afflictions land briefly, or not at all.",
    flavor = "Worn by someone who has decided, as a matter of settled fact, that magic is not real. It is wrong. It also works.",
    sprite = "assets/items/skeptics_harness.png",
    type = "armor",
    tags = { "heavy" },
    class = "knight",
    price = 460,
    repRank = 3,
    traits = { "trait_magic_denial" }, -- lays Magic Denied at the bell; see data/status/magic_denied.lua
    -- Ordinary defense is mediocre on purpose: this is not a better Runed Plate, it is a different
    -- trade. `statusResist` is the headline the wearer actually bought -- see Status.resistRating.
    bonus = {
        defense = { 6, 6, 7, 7, 8, 8, 9, 9, 10, 10, 11 },
        magicDefense = { 12, 13, 14, 15, 16, 17, 18, 19, 20, 21, 22 },
        statusResist = { 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18 },
        movement = -2,
    },
    resist = { magical = { 4, 4, 5, 5, 6, 6, 7, 7, 8, 8, 9 } },
}
