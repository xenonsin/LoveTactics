-- Slot 3 of the Crucible's ten: the complication, and the first proof that the college's philosophy is
-- false on its own terms.
--
-- The Crucible's public teaching is genuinely popular and genuinely consoling: excellence is a
-- substance, not a self; no one is born better; anything can be transferred (docs/story.md, "The
-- college, and what almost no one sees"). A patron bought that -- a real man, not a monster, who paid
-- for a decanted quality and has worn it for two years and been magnificent.
--
-- It is coming apart. Borrowed property ROTS: what was decanted into him was never his, it does not
-- hold, and what is coming off him as it fails is not metaphorical -- it walks. He is besieged in his
-- own house by the shapes his purchase is shedding, and he is still, between waves, trying to explain
-- that the college will honour the guarantee.
--
-- What it costs Ren -- and this is the slot that makes her a person rather than a position: she is
-- VINDICATED here, publicly, on the record, and she takes no pleasure in it at all. Her honest method
-- says a self cannot be poured. Here is a man dying of the opposite claim, and what she does is pity
-- him and try to keep him alive. Kindness that is right and gets no satisfaction out of being right is
-- the whole of her, and it wants showing before the line asks anything harder of her.
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so the two compose): clear the house, and the patron lives. The player CAN win the fight and lose
-- the quest by letting him fall, which is the correct shape for a slot about a man who bought
-- something that will not hold.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own unbuyable is still unwritten.
-- `character_survivor` stands in for the patron (defensive, holds where it lands, does not charge --
-- which is exactly right); the slot wants a named blueprint with a portrait, because the player should
-- remember his face at slot 9 when the college offers them the same tincture.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Self-Made Master",
    description = "He paid the college for a quality and wore it for two years. It is coming off him " ..
        "now, and it is not coming off quietly. Keep him alive.",
    difficulty = "Normal",
    sponsor = "alchemist",
    rewardItems = { "armor_ichor_coat" },
    rewardGold = 130,
    rewardRep = 25,
    rewardPrestige = 1,
    requiredPrestige = 2,
    map = {
        biome = "castle",
        encounters = { min = 5, max = 7 },
        objective = {
            name = "The Patron's House",
            composition = function(ctx)
                local list = { "character_crucible_golem" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_homunculus" end
                return list
            end,
            allies = { "character_survivor" },
            win = { type = "killAll", protect = "character_survivor" },
        },
        keyCount = 1,
    },
}
