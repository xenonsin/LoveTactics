-- Slot 4 of the Hunter's Lodge's ten: the escalation, and the first bounty that does not survive being
-- read.
--
-- The board says dangerous beast. The beast is a sow with a litter under her, in a range nobody farms,
-- that has never come near a road. There is no danger and there never was. The bounty exists because
-- the Lodge's board must never close (docs/story.md, "The Lodge, and what almost no one sees") -- the
-- guild's standing, its stipends, and the honor it hangs on its greatest all run on a supply of things
-- worth killing, and when the genuinely dangerous run low the paperwork simply widens.
--
-- WHY IT IS A FIGHT: the player can walk away from a false bounty. The Lodge's own runners cannot --
-- the entry has been posted, and an entry closed as "unfounded" is an admission the board is padded.
-- So they come to close it themselves, and the fight is with hunters, in a wood, over an animal that
-- did nothing. This is the first time the sponsor stands physically between the player and the right
-- answer, and it is four quests before anyone says the word gluttony.
--
-- What it costs Kaya: this is the one she has been waiting for and dreading. She hunts for food and
-- takes only what she needs; a kill made to keep a ledger open is the exact thing she has no word for.
-- She does not lecture. She puts herself between the runners and the sow, which is the whole argument.
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so the two compose): the runners are the board, and the sow living is the point. `protect` holds
-- while any unit with that id lives.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. `character_dire_bear` stands in for the
-- sow until a bespoke blueprint exists; `character_archer` and `character_bandit_chief` stand in for
-- the Lodge's runners, who want their own blueprint -- they are hunters, not brigands, and should read
-- as colleagues.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Manufactured Cull",
    description = "The board calls it a dangerous beast. It is a sow with a litter, in a range nobody " ..
        "farms. The Lodge's runners are on their way to close the entry regardless.",
    difficulty = "Normal",
    sponsor = "hunters_lodge",
    rewardItems = { "weapon_struck_ledger", "armor_kennelbound_jerkin" },
    rewardGold = 180,
    rewardRep = 30,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "hunters_lodge", rank = 2 }, -- Stalker
    map = {
        biome = "forest",
        encounters = { min = 6, max = 8, always = { "encounter_wolf" } },
        objective = {
            name = "The Posted Entry",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_archer" end
                return list
            end,
            allies = { "character_dire_bear" },
            win = { type = "killAll", protect = "character_dire_bear" },
        },
        keyCount = 1,
    },
}
