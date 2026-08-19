-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
return {
    title = "The Inn",
    cast  = {
        "inn", "character_avatar",
        { id = "character_rowan", when = { has = "character_rowan" } },
        { id = "character_saber", when = { has = "character_saber" } },
        { id = "character_amana", when = { has = "character_amana" } },
        { id = "character_clem",  when = { has = "character_clem" } },
        { id = "character_gyeom", when = { has = "character_gyeom" } },
        { id = "character_kaya",  when = { has = "character_kaya" } },
        { id = "character_ren",   when = { has = "character_ren" } },
    },

    script = {
        { "inn", "You came up the street the way they all come up it. Sit down before you fall down.", tag = 1 },
        { "character_avatar", "We only need the beds.", tag = 2 },
        { "inn", "You need the beds and the rest of it. I set what the hole broke. That is the trade, {name}: a bed for every head, a fire, and me working through the night on whoever cannot straighten up.", tag = 3 },
        { "inn", "The price is by the head, so a full company costs more than three of you limping. I will not charge you for a night nobody needed. Come when somebody is carrying something, and come before you go down again.", tag = 4 },

        { when = { has = "character_rowan" }, script = {
            { "character_rowan", "Take the rooms when they are offered, {name}. A wound you carry down is a wound you carry into every fight after it.", tag = 5 },
        } },
        { when = { has = "character_saber" }, script = {
            { "character_saber", "I have slept on worse and fought the next morning.", tag = 6 },
            { "character_saber", "Badly. I fought badly.", tag = 7 },
        } },
        { when = { has = "character_amana" }, script = {
            { "character_amana", "You work nights on strangers and you charge them a bed's price for it.", tag = 8 },
            { "inn", "The bed is what they came for. The rest I would do anyway.", tag = 9 },
        } },
        { when = { has = "character_clem" }, script = {
            { "character_clem", "Do you ask where the money comes from?", tag = 10 },
            { "inn", "I ask where it hurts.", tag = 11 },
        } },
        { when = { has = "character_gyeom" }, script = {
            { "character_gyeom", "How long before a bone is right again?", tag = 12 },
            { "inn", "One night, if you give me the whole of it. Longer if you sit up arguing with me.", tag = 13 },
        } },
        { when = { has = "character_kaya" }, script = {
            { "character_kaya", "Count the hurt before you pay. You are buying the night, not the beds.", tag = 14 },
        } },
        { when = { has = "character_ren" }, script = {
            { "character_ren", "Splints and sleep. No decanting, no transfer, nothing taken off anybody else.", tag = 15 },
            { "inn", "I would not know how.", tag = 16 },
            { "character_ren", "I know. That is what I said.", tag = 17 },
        } },

        { "inn", "The fire stays lit. Bring them up here before you bring them anywhere else.", tag = 18 },
    },
}
