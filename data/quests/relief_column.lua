-- Slot 1 of the Bastion's ten (docs/story.md, "The Bastion: sloth, designed"). The introduction, and
-- the line's thesis stated in miniature: a column that has to ARRIVE.
--
-- The fiction is the doctrine under load. Highwatch is a mountain post of the Watch -- warded, held
-- for life, and standing on ground that has nothing behind it, so it cannot feed itself. A post like
-- that survives on wagons and on nothing else. "Hold until relieved" is a moral architecture
-- subsidised by supply, and the order has never once said so out loud.
--
-- It is besieged on every side, which is why the column is twelve days late and why the garrison is
-- still standing anyway. That is Acedia's whole thesis in embryo, on board one, before anyone has
-- said her name: the doctrine works right up until the wagons stop, and the order's only plan for
-- that day is the knight's willingness to die on schedule.
--
-- Mechanically a `reach` up the mountain with `protect` layered under it (Combat.evaluate checks
-- `obj.protect` before the win type, so the two compose). The party fights its way to the gate; the
-- wagon master dying loses it outright however well the climb was going. Holding is not the job --
-- someone else arriving is.
--
-- NOTE the deliberate split from data/quests/caravan_road.lua, which this used to duplicate outright
-- (same bandits, same forest, same killAll+protect). That one is a road contract against men who
-- want the cargo. This is a siege line of demons that wants the post, and the difference is the
-- whole reason slot 1 exists.
--
-- Rowan recites "hold until relieved" here, flat, the way you recite something you were issued. She
-- is also unaccountably tense about a routine contract, and the line spends nine more quests
-- explaining why.
return {
    name = "The Relief Column",
    description = "Highwatch is besieged and twelve days without supply. Get the column up the mountain.",
    difficulty = "Easy",
    sponsor = "bastion",
    -- Scenes: `intro` plays over the frozen hub before party select, `outro` over the final battle
    -- frame on the way home (ui/panels/quest_board.lua, states/game.lua).
    intro = "bastion_relief_column_intro",
    outro = "bastion_relief_column_outro",
    rewardGold = 80,
    rewardRep = 20,
    rewardPrestige = 1,
    requiredPrestige = 1,
    rewardItems = { "utility_relief_horn" },
    map = {
        biome = "castle",
        -- The road up a mountain, and the map is generated as one: `ascent` puts the objective on
        -- the farthest dead-end there is -- the peak, the end of the road, the last thing -- and
        -- lays the guaranteed encounters out in authored order by distance from the start, so the
        -- list below is met bottom-to-top instead of scattered.
        ascent = true,
        -- The climb, authored rather than rolled. `always` picks are placed BEFORE the weighted pool
        -- and the fill loop stops at `math.max(count, #placed)` (Overworld:placeEncounters), so
        -- naming as many guaranteed encounters as the count means the random pool contributes
        -- nothing -- no wolves or boar wandering onto a besieged mountain.
        --
        -- Five markers, thickening as they go and met IN THIS ORDER (see `ascent` above): pickets
        -- watching the lower switchbacks, the investment line dug in across the road, and the breach
        -- camp leaning on the gate -- with the gate itself beyond all of them at the peak. The climb
        -- escalates because the mountain does.
        encounters = {
            min = 5, max = 5,
            always = {
                "encounter_siege_pickets",
                "encounter_siege_pickets",
                "encounter_siege_line",
                "encounter_siege_line",
                "encounter_siege_breach",
            },
        },
        objective = {
            name = "The Gate at Highwatch",
            composition = function(ctx)
                -- The Breachward is the mark; it never leaves the gate (`holdGround`).
                local list = { "character_siege_breaker" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_demon_grunt" end
                -- And a human knight, in a knightly order's forms, fighting on the demons' side of a
                -- siege line. Nobody remarks on him, nobody explains him, and he is not named -- the
                -- player is simply the only one in the room who has time to wonder about it.
                --
                -- This is the line's first plant, fifteen years early: Acedia's company kept the
                -- discipline and sold the thing underneath it, and they have been out here the whole
                -- time. It pays at slot 4 (a forsworn captain asks Rowan where the icon is buried),
                -- at slot 5 (the gate opened from inside) and at slot 9 (forty-one of them, still a
                -- company). Do not have anyone comment on him here; the gap is the content.
                --
                -- `character_grey_knight`, NOT `character_forsworn_knight`: same statline, leashed
                -- posture, and a nameplate that does not spend the word `forsworn` three quests
                -- early. See that blueprint's header.
                list[#list + 1] = "character_grey_knight"
                return list
            end,
            -- Two wagons at the gate, and unlike the road legs they dig in: `character_caravan_master`
            -- is `defensive`, so it holds where it lands instead of walking into the breach. The
            -- climb is over -- there is nowhere further up to go.
            allies = { "character_caravan_master", "character_caravan_master" },
            -- Both conditions at once, which is what `protect` is for: it is a composable LOSS
            -- condition checked before the win type (Combat.evaluate), so this reads "kill the
            -- Breachward, and do not let the column die doing it".
            --
            -- Note `protect` is satisfied while ANY unit with that id lives (Combat.isProtectedAlive),
            -- so with two wagons you may lose one and still finish. Deliberate: losing a wagon should
            -- cost, not end the run.
            win = {
                type = "assassinate",
                target = "character_siege_breaker",
                protect = "character_caravan_master",
            },
        },
        keyCount = 0,
    },
}
