-- Slot 5 of the Colosseum's ten: THE DISCOVERY -- the intake, which is to say the program rather than
-- its output.
--
-- Every line has a room like this and every room plays the same trick with its paperwork (docs/story.md:
-- the Bastion's martyrs, the Cathedral's ascended saints, the Lodge's named trophies, the Arcanum's
-- donor roll). The Perennial's version is an INTAKE LEDGER: children received, by year, against the
-- roster's win record on the facing page. Nobody has hidden it. It is a business record, and it is kept
-- with pride, because the house genuinely believes it is describing an academy.
--
-- What it costs Saber: this is where she says it. Not a confession -- she reads a year off the page out
-- loud and it is the year she arrived, and then she keeps walking. The line has spent three quests
-- letting the player wonder how she knows; she stops letting them wonder here, and asks for nothing.
--
-- `reach` (region "far"): the job is to get INTO the intake hall, and the house's stewards are between
-- you and it. Deliberately not a purge -- the point of the slot is the room, and a player who runs the
-- corridor without killing everyone in it has understood the assignment.
--
-- FIRST PASS. Scenes are not authored, so no `intro` / `outro` / `opening` is named (Conversation.play
-- asserts on an unknown id). This slot owes the line an UNBUYABLE -- story.md budgets one at slot 5 per
-- line, the intake register's counterpart, `class = "fighter"`, no `price` -- and it is not written
-- yet.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Intake",
    description = "The house keeps a ledger of children received, and the roster's record on the " ..
        "facing page. Get into the hall and read it.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardItems = { "weapon_tempo_debt", "armor_adrenal_harness" },
    rewardGold = 220,
    rewardRep = 45,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "colosseum", rank = 2 }, -- Contender
    map = {
        biome = "castle",
        encounters = { min = 6, max = 9, always = { "encounter_elite" } },
        objective = {
            name = "The Intake Hall",
            composition = function(ctx)
                local list = { "character_warlord" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            win = { type = "reach", region = "far" },
        },
        keyCount = 2,
    },
}
