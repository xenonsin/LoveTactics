-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- The debut's found kit (data/quests/arena_debut.lua's `always` list): the party comes across an
-- unclaimed fighter's bag on the walk to the tunnel, and Rowan reads it as the answer to the house's
-- nets. This is the second half of the root counterplay -- the undercard
-- (data/encounters/encounter_arena_undercard.lua) teaches the Trapper's pin, this hands the tool that
-- lifts it and NAMES what the tool is for, so a new player does not have to infer the counterplay from
-- a stash item that appeared with no explanation.
--
-- Both choices grant the same kit (two Clearwater Vials + a Panacea -- self-cleanse and an ally
-- cleanse), because the counterplay must not be skippable: the branch is only tone. Rowan's warning
-- plays on the shared `id = "nets"` line regardless of the choice, and is phrased forward-looking ("a
-- house like the one we're drawn against") so it lands whether or not the undercard was walked first --
-- overworld stop order on the debut's rolled castle field is not guaranteed.
return {
    title = "An Unclaimed Kit",
    cast  = { "character_avatar", "character_rowan" },

    script = {
        { "character_rowan", "Someone kitted up for this card and never made it to the sand. Their bag's still here, straps cut in a hurry.", tag = 1 },
        { "character_avatar", "Cleansing draughts -- a couple of clearwater vials and a panacea besides. Choose...", tag = 2, choices = {
            { "Take the lot.", tag = 3, goto = "nets", effect = { grant = { "consumable_clearwater_vial", "consumable_clearwater_vial", "consumable_panacea" } } },
            { "Rowan -- why would a fighter bring these to a sword bout?", tag = 4, goto = "nets", effect = { grant = { "consumable_clearwater_vial", "consumable_clearwater_vial", "consumable_panacea" } } },
        } },
        { "character_rowan", "Because a house like the one we're drawn against doesn't win with the sword alone -- it fields netters. They'll rope your legs and hold you still while the big blade winds up. Drink one the moment you're pinned and it cuts you loose -- you get your step back before the swing lands. A panacea will do the same for whoever's caught beside you. Don't stand there roped, waiting for it.", tag = 5, id = "nets", goto = "leave" },
        { "character_avatar", "Cut loose, then move. Understood. Let's not keep the veteran waiting.", tag = 6, id = "leave" },
    },
}
