-- Slot 2 of the Cathedral's ten (docs/story.md, "The Cathedral: lust, designed"). RE-PREMISED. This
-- slot used to be "The Fallen Confessor": the church branded Amana one of its own gone bad, hired the
-- player to purge her, and her post-battle plea was both her recruit and the line's first reveal. She
-- is recruited three quests earlier now, in the Colosseum's padded card
-- (data/quests/colosseum/quest_colosseum_slot_02.lua), so the slot needed a new job. The plea's payload
-- did not die with it: the blooding lands at slot 4, over the failed bloodings themselves, where the
-- player can see the thing being described (data/conversations/cathedral/conversation_cathedral_slot_04_outro.lua).
--
-- THE PREMISE. The Cathedral's charity is public and honored: it takes in the orphans, the poor, and
-- above all the refugees the war keeps pouring through the gate, and it sends carts out along the
-- king's road to collect them. The player is hired to walk one cart in. That is the whole job, and on
-- its face it is the kindest work in the game.
--
-- WHO IS ON THE ROAD. A Colosseum press-gang, working the same road for the same reason: the house
-- needs bodies to card, and the padded card just used eleven of them up. They come with TRAPPERS, the
-- netters from the debut (data/characters/character_trapper.lua), because you do not kill what you are
-- there to collect. The two houses are running the identical trade on the identical road, and only one
-- of them is doing it in daylight with a blessing on the wagon. Nobody says that sentence out loud.
--
-- THE LINE'S RHYME, KEPT. The Cathedral opens and closes on "refuses what is not offered": here the
-- party refuses to let a house take people who were not offered, and at slot 10 Luxuria offers Amana
-- her own name back and Amana refuses the gift (docs/story.md, "The line's rhyme, and the finale").
-- What the slot buys that the old one could not: the player DELIVERS the cart. Every child walked
-- safely to that door is walked to the altar, and slots 4 and 5 are what make them go back and count
-- them. The player is the hand, three slots before slot 6 tells them so.
--
-- What it costs Amana: she rides the cart she was carried in on as a child, doing the job that was
-- done to her, and she is glad to be doing it. She does not know she is delivering them. She has told
-- the party about the register and the pit (the revival scene) and NOT about the rite, and this is the
-- last slot where that silence still looks like discretion.
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so the two compose): put the press-gang down, and do not let the cart's people be taken while you
-- do it. `protect` holds while ANY unit with that id lives, so losing one costs without ending the
-- run, the same call the padded card and the Greywatch caravan make.
--
-- FIRST PASS. `character_survivor` stands in for the cart's intake (the line owes bespoke oblate
-- blueprints, docs/story.md's not-built list). The opening is authored; there is no outro scene yet.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "The Intake Road",
    description = "The Cathedral's cart is coming in off the king's road with forty souls on it. " ..
        "Walk it home. Something else is working that road tonight.",
    difficulty = "Normal",
    sponsor = "cathedral",
    rewardItems = { "weapon_renewal_staff" },
    rewardGold = 90,
    requiredQuests = { "quest_cathedral_slot_01" }, -- slot 2: the line runs in order
    requiredPrestige = 1,
    map = {
        biome = "forest",
        encounters = { min = 3, max = 5 }, -- map size scales with this (models/overworld.lua)
        objective = {
            name = "The Cart",
            -- The press-gang: a chief who does the talking and netters who do the work. Trappers are
            -- the debut's own tool turned on people who cannot fight back, which is the image the slot
            -- is built on. Count scales with prestige, as every carded roster does.
            composition = function(ctx)
                local list = { "character_bandit_chief", "character_trapper" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit" end
                return list
            end,
            -- The cart's people. `character_survivor` is defensive and will not walk into a fight,
            -- which is what forty frightened people on a road actually do.
            allies = { "character_survivor", "character_survivor", "character_survivor" },
            opening = "conversation_cathedral_slot_02_confront",
            win = { type = "killAll", protect = "character_survivor" },
        },
        keyCount = 1,
    },
}
