-- Slot 8 of the Colosseum's ten: the break, and the moment the sponsor becomes the obstacle.
--
-- Saber has deferred for seven quests -- patient, which is her whole virtue, and which has started to
-- look from the outside like waiting for permission. Here she stops. She walks into the house that
-- schedules Ira and asks for the match, out loud, in front of people, and names the day.
--
-- The house cannot say yes and cannot say what Ira is, because saying it means saying what the program
-- is (docs/story.md, "The house that cannot admit what it built"). So it does the institutional thing:
-- it does not refuse her, it MATCHES her -- against the fighter it keeps for people who ask questions
-- in public, on a card nobody advertised. The venue answers a question with a bout, which is the only
-- language it has.
--
-- This is where patience becomes a CHOICE rather than a temperament, and it is the difference the
-- whole foil rests on: Ira has to be hit to feel anything, and Saber -- who could have swung at any
-- point in eight quests -- picks the moment. Waiting and choosing look identical from outside and are
-- opposite things, and slot 8 exists to show the player which one they have been watching.
--
-- `assassinate`: the house's answer is one fighter, and the rest of the room is a wall to get through
-- rather than a thing to grind down.
--
-- FIRST PASS. Scenes are not authored, so no `intro` / `outro` / `opening` is named. This slot owes
-- SABER'S SECOND RELIC (story.md, slot 8: "second relic; patience becomes a choice") -- it is not
-- written yet, so no `rewardItems` entry points at it.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Naming the Day",
    description = "Saber has stopped waiting. She has asked the house for the match out loud, and the " ..
        "house has answered the only way it knows how.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardItems = { "weapon_given_hour", "weapon_reapers_due" },
    rewardGold = 320,
    rewardRep = 30,
    rewardPrestige = 2,
    requiredPrestige = 4,
    requiredRep = { vendor = "colosseum", rank = 3 }, -- Champion
    map = {
        biome = "castle",
        encounters = { min = 9, max = 12, always = { "encounter_elite" } },
        objective = {
            name = "The Card Nobody Advertised",
            composition = function(ctx)
                local list = { "character_warlord" }
                for i = 1, 2 + math.floor((ctx.prestige or 1) / 3) do list[#list + 1] = "character_champion" end
                return list
            end,
            win = { type = "assassinate", target = "character_warlord" },
        },
        keyCount = 2,
    },
}
