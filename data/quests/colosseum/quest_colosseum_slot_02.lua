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
-- cheap way, so the house sends the one instrument that never fails: Ira walks onto the sand, and she
-- is a BODY ON THE BOARD when she does it. That overrule is the beat, and Ira's first, wordless
-- appearance in the line (she first speaks at slot 7).
--
-- SHE IS FOUGHT, AND THE FIGHT IS LOST. The win is overruled rather than narrated: the objective's
-- `overrule` block below is asked for at the exact moment the last carded killer falls, and instead of
-- a victory the far gate opens (states/battle.lua's battle.fireOverrule). She walks on, the scene
-- plays over the board with her standing on it, the refugees drop as it closes, and then the player has
-- their turn against her like against anyone else. It ends one way. She arrives blueprint-exact off her
-- own reference level -- a body from the end of this line, on a slot-2 board -- and she is stamped
-- `unkillable` for this fielding alone, so a party that fights her superbly still only gets to find out
-- how little that is worth. Every blow they land on her is real; none of them is enough.
--
-- AND THE HOUSE MEANT ALL OF IT. The crowd paid for a night of blood; the player's win threatened to
-- send them home short; so the house put its patron on the sand to finish the card, and the card
-- includes whoever is still standing on it. The promoter is not surprised by any of it. That is the
-- lesson of the slot: the Colosseum will spend anyone in front of it, including its own new draw,
-- because what it actually sells is the killing. The party does not lose the QUEST (the objective was
-- satisfied before she ever walked out, and the payout, the companion and the scenes are all owed);
-- they lose their lives after winning, which is a different and worse lesson.
--
-- WHAT COMES BACK. The venue and the stables are not the same people (docs/story.md, "The league and
-- the stables"), and that gap is what the next scene runs on: the house spent a new draw for one
-- night's crowd, and the stables with money on that draw did not agree. There is no `outro` -- the
-- fight's own ending IS the outro, and it is a fade to black over a sand floor with the company on it.
-- `epilogue` is what the player sees next: the company wakes in the Cathedral, raised by an acolyte
-- named Amana, because those stables paid the church's price for four fighters they intend to book
-- again (data/conversations/colosseum/conversation_colosseum_slot_02_join.lua).
-- Amana is the `rewardCharacter` of this slot, not of the Cathedral's second (docs/story.md, "The
-- Cathedral"): she leaves with the company because the refugees came in on the same cart and nobody
-- paid for THEM, and she is the one who writes them into the intake register as ascended to the Light
-- and carries them to the pit. The player is the only living witness to what actually happened on that
-- sand. Nothing about the blooding is said here; that is the Cathedral's line to give (slot 4).
--
-- This slot is also the gate on the Cathedral itself (data/buildings/cathedral.lua): the door does not
-- open until the player has been carried through it.
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so the two compose): kill the house's killers, and do not let the refugees die while you do it.
-- `protect` holds while ANY unit with that id lives, so losing one costs without ending the run --
-- the same call data/quests/bastion/quest_bastion_slot_01.lua makes with its wagons. NOTE the protect
-- is NOT rendered pointless by the overrule: holding them to the bell is precisely what forces the
-- house to send Ira. The player's success causes the horror; it does not fail to prevent it. Losing a
-- refugee BEFORE that is an ordinary defeat with an ordinary Try Again -- the beat below is the ending
-- of a fight that was won, and it is only reachable by winning it.
--
-- What it costs Saber: she is first down between the killers and the refugees, wins her side, and then
-- watches Ira erase it -- the exact shape of the thing that broke her (see the slot-10 confront: "they
-- died anyway; someone else did it while she stood there"). The seed slot 10 pays off.
--
-- FIRST PASS. `conversation_colosseum_slot_02_intro` is still scaffolded (BEAT strings); the
-- `_overrule` scene and the `_join` epilogue are written, because the arrival and the waking are one
-- beat and a beat cannot be half-scaffolded. This slot's own unbuyable is not authored yet, so it is
-- not named here. `character_survivor` stands in for the refugees (and the elder) until bespoke
-- blueprints exist (docs/wrath-line-beats.md open threads: `character_village_elder`).
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
    -- NO `outro`. The fight ends on the party going down and the screen going black
    -- (states/battle.lua's battle.endOverruled), and there is nothing to say over the sand afterwards
    -- because nobody is left on it who could say it. `epilogue` plays over that black frame: the
    -- company wakes up somewhere else, which is a change of place and cast rather than a change of
    -- subject and so cannot be more lines on the end of anything.
    epilogue = "conversation_colosseum_slot_02_join",
    -- Raised, then kept. Player.recruit refuses a duplicate, so this is safe on any path that reaches
    -- Quest.complete more than once. She is granted the moment the objective pays out, which is well
    -- before the waking scene the join belongs in -- the overrule scene holds the banner (`deferJoins`)
    -- so a recruit never lands in the scene where everyone dies.
    rewardCharacter = "character_amana",
    rewardItems = { "weapon_carrion_axe", "weapon_mired_maul" },
    rewardGold = 90,
    requiredQuests = { "quest_colosseum_slot_01" }, -- slot 2: the line runs in order
    requiredPrestige = 1,
    map = {
        biome = "colosseum", -- a padded card is a card: it is fought on the house's own sand
        encounters = { min = 4, max = 6 },
        objective = {
            name = "The Warm-Up Bout",
            composition = function(ctx)
                -- The house's carded killers. Ira is NOT among them -- she is the overrule below, and
                -- she is not on the board until the last of these is off it.
                local list = { "character_champion" }
                for i = 1, 2 + math.floor((ctx.day or 1) / 2) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            -- The refugees, the village elder among them. `character_survivor` is defensive and will not
            -- walk into the killers, which is what a person shoved onto the sand actually does. Standing
            -- in until `character_village_elder` and bespoke refugee blueprints exist.
            allies = { "character_survivor", "character_survivor", "character_survivor" },
            win = {
                type = "killAll", enemy = "the house's killers", protect = "character_survivor",
                -- THE HOUSE OVERRULES THE WIN. Read once, at the moment the last carded killer falls,
                -- by states/battle.lua's battle.fireOverrule -- see the header there for the block's
                -- shape and the header above for what it is doing to the player.
                overrule = {
                    -- The far gate, behind the house's own line, which is where its patron comes from.
                    composition = { "character_general_wrath" },
                    from = "top",
                    -- Played over the board with her already standing on it, before anything moves.
                    scene = "conversation_colosseum_slot_02_overrule",
                    -- The refugees go down as that scene closes. Everything the player did for them is
                    -- undone in front of them, and there is no turn in which it could have been stopped.
                    fell = "character_survivor",
                    -- She cannot be put down (models/combat.lua). This is the one fight in the campaign
                    -- whose ending is the party's defeat, and a party good enough to fell her would
                    -- break the scene it is walking into rather than win anything.
                    unkillable = "character_general_wrath",
                    -- What replaces the satisfied objective, `protect` and all -- it has to go, or
                    -- felling the refugees a line earlier would be judged a defeat. `killAll` against a
                    -- body that cannot be killed is a fight with no win in it, which is the truth of
                    -- the beat; `text` is what the banner says instead of naming her as a target.
                    win = { type = "killAll", text = "The house has sent its patron" },
                },
            },
        },
        keyCount = 0,
    },
}
