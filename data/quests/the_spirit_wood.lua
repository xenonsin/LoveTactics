-- Capstone for the SHAMAN discipline (hunter x mage) -- data/disciplines/shaman.lua names this file in
-- `requiredQuests`.
--
-- Signature on show: SPIRIT TOTEMS -- summoned spirits bound to the ground they stand on
-- (ability_call_spirit and utility_spirit_fetish ship, the Fetish empowering them through a walking
-- Rally zone). The exemplar is a spirit-caller, and the demonstration is that she never has to be
-- anywhere: what fights the party is the wood, and she is the reason it is angry.
--
-- Disposition is MENTOR. She is not hostile and this is not her fight -- something else has stirred
-- the wood and she is holding it down while the party is in it, which is why the objective is
-- `survive`: outlast the night and she settles the rest.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The spirit-caller wants a bespoke
-- blueprint; `character_wolfsong_spirit` and `character_totem` are the wood's own, standing in for
-- spirits nobody has bound yet.
return {
    name = "The Spirit Wood",
    description = "The trees here are spoken for and something has upset the arrangement. She says " ..
        "she can put it back by morning. She says to stay where you are until she has.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_wolf" } },
        objective = {
            name = "The Wood, Roused",
            composition = function(ctx)
                local list = { "character_wolfsong_spirit" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_wolf_grunt" end
                list[#list + 1] = "character_wolf_alpha"
                return list
            end,
            -- TICKS to outlast (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "survive", duration = 30 },
        },
        keyCount = 1,
    },
}
