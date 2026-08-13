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
-- GATING: `requiredQuests` names the first subclass gate of each parent line, so this capstone does
-- not appear until the player genuinely holds both halves -- see the note in
-- data/quests/colosseum/quest_colosseum_champions_challenge.lua.
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
    -- Both parents, earned: "quest_hunters_lodge_slot_03" is the first hunter subclass gate on its line,
    -- "quest_arcanum_slot_03" the first mage. Holding either is impossible without them.
    requiredQuests = { "quest_hunters_lodge_slot_03", "quest_arcanum_slot_03" },
    requiredPrestige = 2,
    map = {
        biomes = { "forest", "swamp" },
        encounters = { min = 6, max = 9, always = { "encounter_wolf" } },
        objective = {
            name = "The Wood, Roused",
            composition = function(ctx)
                local list = { "character_wolfsong_spirit" }
                for i = 1, 3 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_wolf_grunt" end
                list[#list + 1] = "character_wolf_alpha"
                return list
            end,
            -- TICKS to outlast (the unit the clock counts and the HUD quotes), not turns.
            win = { type = "survive", duration = 30 },
        },
        keyCount = 1,
    },
}
