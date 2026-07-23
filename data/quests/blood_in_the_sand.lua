-- Slot 6 of the Colosseum's ten: complicity, and the night the player stops being a guest on the card.
--
-- NOT a grind. This file used to be the line's `repeatable`, and it was the reason story.md called the
-- four-quest template a soft-lock: the rung meant to carry a player from Champion to Legend was itself
-- gated at Champion, and the only fix on offer was "run it until the number goes up." No quest in this
-- game is repeatable now, and this slot is better for it -- "the arena does not care why you come
-- back" was a true sentence with nothing in it for the player to do.
--
-- What replaces it rhymes with slot 2, and the pairing is the whole point. At slot 2 the player WAS
-- the warm-up, and the house padded the card under them with people who had not been brought there to
-- fight (data/quests/the_padded_card.lua). Tonight the player is the DRAW -- their name is the reason
-- the gate receipts are what they are -- and the promoter has padded their undercard the same way, as
-- a courtesy, because that is what a house does for a headliner it wants to keep.
--
-- Nobody asks the player's permission and nobody imagines they need to. The card is already printed.
-- They can refuse to swing at what is put in front of them and the crowd will still have been sold a
-- night, the receipts will still clear, and the standing they need to reach Ira is paid for out of
-- exactly this. The implication lands on both of them: Saber signed with the only house that isn't
-- one, and the house that isn't one has started behaving like the others because the player is winning.
--
-- What it costs Saber: she says nothing during. Afterwards she asks the player -- not rhetorically,
-- she wants an answer -- whether they intend to keep taking the top billing.
--
-- `killAll` with `protect` layered under it (Combat.evaluate checks `obj.protect` before the win type,
-- so they compose): the house's enforcers are the card, and the padding lives. The same shape slot 2
-- had, with the player on the other side of the billing, which is the argument the slot is making.
--
-- FIRST PASS on the new premise. Scenes are not authored, so no `intro` / `outro` / `opening` is named
-- (Conversation.play asserts on an unknown id). `character_survivor` stands in for the padding.
--
-- `rewardItems` includes this slot's share of the line's quest-only shelf stock -- the unpriced
-- pieces a vendor's shelf promises and never sells (docs/classes.md, tests/obtainable_spec.lua).
return {
    name = "Blood in the Sand",
    description = "Your name is the reason the gate receipts are what they are, so the promoter has " ..
        "padded your undercard. As a courtesy. The card is already printed.",
    difficulty = "Hard",
    sponsor = "colosseum",
    rewardItems = { "weapon_wolfs_portion", "weapon_unspent_blow" },
    rewardGold = 240,
    rewardRep = 40,
    rewardPrestige = 1,
    requiredPrestige = 3,
    requiredRep = { vendor = "colosseum", rank = 3 }, -- Champion
    map = {
        biome = "castle",
        encounters = { min = 8, max = 12, always = { "encounter_elite" } },
        objective = {
            name = "The Card With Your Name On It",
            composition = function(ctx)
                local list = { "character_champion" }
                for i = 1, 3 + math.floor((ctx.prestige or 1) / 2) do list[#list + 1] = "character_bandit_chief" end
                return list
            end,
            allies = { "character_survivor", "character_survivor", "character_survivor" },
            win = { type = "killAll", protect = "character_survivor" },
        },
        keyCount = 1,
    },
}
