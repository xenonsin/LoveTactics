-- Slot 2 of the Colosseum's ten (docs/wrath-line-beats.md, Slot 2): the card padded with slaughter,
-- and what the house actually sells.
--
-- Saber signs at slot 1 and enjoys herself. This is the first bout after, and the promoter has done
-- the ordinary thing: warmed the crowd up with a bout that is not one. The "opponents" are the
-- capital's newest REFUGEES -- unarmed, desperate, off the same road the player fled down (prologue) --
-- carded against the house's hardened killers, because the crowd has learned to hate the refugees the
-- war keeps pouring through the gate and will pay to watch them die. The village elder the player and
-- Rowan carried out of the fire in the prologue is among them.
--
-- Why it is a fight: the player takes the refugees' side and CAN win -- put the carded killers down,
-- keep the refugees standing to the bell. And because they hold, the crowd is denied its death the
-- cheap way, so the house sends the one instrument that never fails: Ira walks onto the sand and kills
-- the refugees anyway (scripted in the outro -- NOT a board unit here, NOT preventable). That overrule
-- is the beat, and Ira's first, wordless appearance in the line (she first speaks at slot 7).
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so the two compose): kill the house's killers, and do not let the refugees die while you do it.
-- `protect` holds while ANY unit with that id lives, so losing one costs without ending the run --
-- the same call data/quests/bastion/quest_bastion_slot_01.lua makes with its wagons. NOTE the protect
-- is NOT rendered pointless by the outro: holding them to the bell is precisely what forces the house
-- to send Ira. The player's success causes the horror; it does not fail to prevent it.
--
-- What it costs Saber: she is first down between the killers and the refugees, wins her side, and then
-- watches Ira erase it -- the exact shape of the thing that broke her (see the slot-10 confront: "they
-- died anyway; someone else did it while she stood there"). The seed slot 10 pays off.
--
-- FIRST PASS. Scenes `conversation_colosseum_slot_02_intro` / `_outro` are scaffolded (BEAT strings);
-- this slot's own unbuyable is not authored yet, so it is not named here. `character_survivor` stands
-- in for the refugees (and the elder) until bespoke blueprints exist (docs/wrath-line-beats.md open
-- threads: `character_village_elder`).
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Padded Card",
    description = "The house has carded the capital's newest refugees against its own killers. The " ..
        "crowd paid to watch them die. Take their side.",
    difficulty = "Normal",
    sponsor = "colosseum",
    intro = "conversation_colosseum_slot_02_intro",
    outro = "conversation_colosseum_slot_02_outro",
    rewardItems = { "weapon_carrion_axe", "weapon_mired_maul" },
    rewardGold = 90,
    requiredQuests = { "quest_colosseum_slot_01" }, -- slot 2: the line runs in order
    requiredPrestige = 1,
    map = {
        biome = "desert",
        encounters = { min = 4, max = 6 },
        objective = {
            name = "The Warm-Up Bout",
            composition = function(ctx)
                -- The house's carded killers. Ira is NOT among them -- she is a scripted outro force,
                -- not a board unit this slot.
                local list = { "character_champion" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            -- The refugees, the village elder among them. `character_survivor` is defensive and will not
            -- walk into the killers, which is what a person shoved onto the sand actually does. Standing
            -- in until `character_village_elder` and bespoke refugee blueprints exist.
            allies = { "character_survivor", "character_survivor", "character_survivor" },
            win = { type = "killAll", protect = "character_survivor" },
        },
        keyCount = 0,
    },
}
