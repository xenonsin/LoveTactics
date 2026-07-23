-- Capstone for the WARBREWER discipline (fighter x alchemist) -- data/disciplines/warbrewer.lua names
-- this file in `requiredQuests`.
--
-- Signature on show: COMBAT DRAUGHT -- a brawler who drinks mid-swing and pays for it later
-- (consumable_berserkers_brew and utility_brawlers_bandolier ship; the bandolier's `onCast` haste is
-- the engine's honest approximation of a free action, and its header says so). The exemplar is a
-- draught-brawler in the cellar under the fighting pits, and the demonstration is the arc: she is
-- unremarkable on turn one and terrifying by turn four because she keeps drinking, and the counterplay
-- is to end it before the bandolier is empty.
--
-- Disposition is BOSS. The cellar is where the pits keep the fights nobody sells tickets to.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The brawler wants a bespoke blueprint
-- whose grid IS the bandolier; `character_warlord` stands in and does none of that.
return {
    name = "The Fighting Cellar",
    description = "Below the pits there is a second card nobody prints. The brawlers down here are " ..
        "issued a bandolier before they go on, and they drink the whole way through.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "castle",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Card Nobody Prints",
            composition = function(ctx)
                local list = { "character_warlord" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            win = { type = "assassinate", target = "character_warlord" },
        },
        keyCount = 1,
    },
}
