-- Capstone for the HERBALIST discipline (hunter x alchemist) -- data/disciplines/herbalist.lua names
-- this file in `requiredQuests`.
--
-- Signature on show: FIELD BREWING -- turning what is growing on the board into something usable
-- mid-fight (consumable_wildcraft_poultice and ability_field_brew ship; Field Brew makes restorative
-- GROUND rather than an inventory item, which its header admits is the approximation the engine
-- allows). The exemplar is a field-apothecary, and the demonstration is that she arrives with almost
-- nothing and is fully supplied by turn three, off a glade everyone else is trying not to touch.
--
-- Disposition is RECRUIT. She is not defending the glade and not responsible for it -- she is working
-- in it because it is the richest place for miles if you know which parts are poison, which is the
-- entire discipline stated as a life.
--
-- GATING: the both-parents rule lives in `Discipline.isUnlocked`, not here -- see the note in
-- data/quests/champions_challenge.lua.
--
-- FIRST PASS. Scenes are not authored, so nothing is named, and no `rewardCharacter` is set -- the
-- apothecary needs a blueprint before she can join. `character_blightstake` and `character_boar` are
-- what the glade has made of its own wildlife.
return {
    name = "The Poisoned Glade",
    description = "Everything in it is toxic and everything in it is valuable, and there is a woman " ..
        "working the middle of it with her sleeves rolled up.",
    difficulty = "Hard",
    sponsor = "alchemist",
    rewardGold = 250,
    rewardRep = 10,
    rewardPrestige = 1,
    requiredPrestige = 4,
    map = {
        biome = "forest",
        encounters = { min = 6, max = 9, always = { "encounter_boar" } },
        objective = {
            name = "The Glade",
            composition = function(ctx)
                local list = { "character_blightstake" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_boar" end
                return list
            end,
            win = { type = "killAll" },
        },
        keyCount = 1,
    },
}
