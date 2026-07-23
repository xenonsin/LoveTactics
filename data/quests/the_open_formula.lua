-- Slot 9 of the Crucible's ten: the approach, and the scale of what killing her will NOT undo.
--
-- The college does not hide and never has. It PROSELYTISES (docs/story.md), and the last thing before
-- the vats is a lecture hall with the doors open, the method on the board, and a room full of ordinary
-- people finding it consoling -- because it is: no one is born better, excellence is a substance, and
-- anything can be transferred. That teaching is the engine. Livia is only its best result.
--
-- And then they offer it to the player. Not as a bribe and not as a trap -- as a courtesy, in front of
-- witnesses, from a master who has read their record and thinks they have earned a top-up. The player
-- has met the man at slot 3 who took that offer and came apart in his own house. The Crucible has met
-- him too. It is still offering, and it will still be offering next year, because the formula is
-- already out: every gift already sold, every discard already in the vat, and a new masterpiece is a
-- matter of funding rather than genius. Killing Livia does not close a single one of those doors.
--
-- What it costs Ren: nothing left to cost -- slot 8 spent it. What she does here is refuse the offer
-- in public, which is the only argument this room understands, and then answer the master's question
-- -- what exactly is wrong with giving people what they want -- and discover she cannot do it in a
-- sentence. She goes anyway. That is what kindness is when it stops being agreeable.
--
-- `assassinate`: the master who made the offer, and the hall's own -- brilliant, purchased, entirely
-- convinced -- as the wall to get through.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and the slot's own
-- unbuyable is still unwritten. The
-- proselytising master wants a bespoke blueprint with a portrait; `character_mage` stands in.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Open Formula",
    description = "The lecture hall's doors are open, the method is on the board, and the room finds " ..
        "it consoling. Then the master turns and offers you a dram, as a courtesy.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardItems = { "armor_volatile_carapace" },
    rewardGold = 400,
    rewardRep = 35,
    rewardPrestige = 2,
    requiredPrestige = 5,
    requiredRep = { vendor = "alchemist", rank = 3 }, -- Transmuter
    map = {
        biome = "castle",
        encounters = { min = 10, max = 13, always = { "encounter_elite", "encounter_elite" } },
        objective = {
            name = "The Lecture Hall",
            composition = function(ctx)
                local list = { "character_mage" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_champion" end
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_homunculus" end
                return list
            end,
            win = { type = "assassinate", target = "character_mage" },
        },
        keyCount = 2,
    },
}
