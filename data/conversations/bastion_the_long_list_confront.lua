-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "An Entry on the List",
    cast  = { "character_forsworn_captain", "character_knight" },

    script = {
        { "character_forsworn_captain", "You've the look. Bastion. Sworn, by the shield.", tag = 1 },
        { "character_forsworn_captain", "Whose name do you carry, then?", tag = 2 },
        { "character_knight", "Acedia's.", tag = 3 },
        { "character_forsworn_captain", "Of course it is. They are still handing her out.", tag = 4 },
        { "character_forsworn_captain", "Ask them where she is buried. Go on. Not what she did -- where she is buried.", tag = 5 },
        { "character_knight", "At Greywatch. Under the gate she died holding.", tag = 6 },
        { "character_forsworn_captain", "Is she.", tag = 7 },
    },
}
