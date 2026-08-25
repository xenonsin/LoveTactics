-- Capstone for the SKIRMISHER discipline (fighter x hunter) -- data/disciplines/skirmisher.lua names
-- this file in `requiredQuests`.
--
-- Signature on show: HIT-AND-RUN -- strike, then reposition (trait_skirmishers_momentum, which ships,
-- pays a damage bonus for having moved). The exemplar is a raider outrider and the whole quest is that
-- rule read as a scenario: they will not hold ground, they will not trade, and a party that plants
-- itself and waits to be attacked will be whittled down over twenty turns without ever landing a
-- clean blow. You have to make them stand still.
--
-- Disposition is BOSS. The outriders are raiders and there is nothing to negotiate.
--
-- GATING: `requiredQuests` names the first subclass gate of each parent line, so this capstone does
-- not appear until the player genuinely holds both halves -- see the note in
-- data/quests/colosseum/quest_colosseum_champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named. The outrider captain wants a bespoke
-- blueprint built around movement -- high speed, a mount, no reason to ever be adjacent;
-- `character_bandit_chief` and `character_archer` stand in and are far too willing to stay put.
return {
    name = "The Running Fight",
    description = "The outriders have been bleeding the road for a month and have never once been " ..
        "where the column expected. They will not stand. Make them.",
    difficulty = "Hard",
    sponsor = "hunters_lodge",
    ladder = 5, -- which rung of the Lodge this job opens (models/errand.lua)
    rewardItems = { "utility_ground_given", "utility_quarrys_end" },
    rewardGold = 250,
    -- Both parents, earned: "quest_colosseum_slot_03" is the first fighter subclass gate on its line,
    -- "quest_hunters_lodge_slot_03" the first hunter. Holding either is impossible without them.
    -- THE LODGE'S LAST RUNG, carrying both of its chase paths: the skirmisher (fighter and hunter) and
    -- the poacher (rogue and hunter), which is why the Undercroft's key is here beside the Colosseum's.
    -- The poacher could not share the fourth rung with the trapper -- that one is a numbered slot on the
    -- Lodge's own chain, and a chain slot names exactly one prerequisite (tests/quest_ladder_spec.lua),
    -- so it has no room for another house's key. A capstone does.
    requiredQuests = { "quest_colosseum_slot_03", "quest_hunters_lodge_slot_03", "quest_undercroft_slot_04" },
    requiredPrestige = 2,
    map = {
        biome = "tundra",
        encounters = { min = 7, max = 10, always = { "encounter_elite" } },
        objective = {
            name = "The Outrider Captain",
            composition = function(ctx)
                local list = { "character_bandit_chief" }
                for i = 1, 3 + math.floor((ctx.day or 1) / 3) do list[#list + 1] = "character_archer" end
                return list
            end,
            win = { type = "assassinate", target = "character_bandit_chief",
                enemy = "the outrider captain" },
        },
        keyCount = 1,
    },
}
