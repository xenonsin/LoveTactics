-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 1 OF 10 (docs/temptation.md). The first one is deliberately not a temptation at all -- there is
-- no voice in it, nothing is at stake, and a player who takes it has done nothing worse than take a
-- dead man's wages off a grateful merchant. That is the whole design of the line's opening three: the
-- Crown does not arrive announcing itself, it arrives as an ordinary sum of money that nobody is
-- going to miss. By slot 4 the same sentence is being said by something else, and the player is
-- supposed to recognise the shape of it and not be able to say when it changed.
--
-- Placed before Rowan's closing pair rather than after it, so the scene still ends on "Somebody
-- arrived" whichever way it is answered -- the base scene must always work (docs/story.md).
return {
    title = "The Gate at Highwatch",
    cast  = { "character_caravan_master", "character_rowan", "character_avatar", "bastion" },

    script = {
        { "character_caravan_master", "Twelve days. We'd stopped counting somewhere around the eighth.", tag = 1 },
        { "character_rowan", "And they opened the gate to you.", tag = 2 },
        { "character_caravan_master", "Opened it? The sergeant came down the road on foot to meet the lead wagon. Wouldn't touch the flour. Went straight past me to the salt.", tag = 3 },
        { "character_caravan_master", "Their wards were four days from going out. Four days, and then that mountain is just a wall with tired men on it.", tag = 4 },
        { "character_caravan_master", "I gave the last of our water to the boy on the wagon on the ninth and told him a relief was coming. I didn't believe it when I said it.", tag = 5 },
        { "character_rowan", "But they held.", tag = 6 },
        { "character_caravan_master", "...Aye. They held.", tag = 7 },
        { "character_caravan_master", "One thing before you go. Sixth wagon had a driver on it at the start and didn't at the end. Denhold. No people that I ever heard of.", tag = 10 },
        { "character_caravan_master", "His share is sitting in my book with nowhere to go, and I am not carrying it back down that road to hand to nobody. You want it, it's yours. Choose...", tag = 11 },
        { "character_avatar", "...", tag = 12, choices = {
            { "\"Put it in the Bastion's poor-box at Highwatch.\"", tag = 13 },
            { "\"We'll take it.\"", tag = 14, effect = { gold = 90, take = "bastion" } },
        } },
        { "character_rowan", "Forgive me, {name}. I'm no use at this part of it.", tag = 8 },
        { "character_rowan", "Somebody arrived. That's all I have ever wanted a story to say.", tag = 9 },
        { "bastion", "Highwatch sent word down ahead of you. Twelve days without supply, and the column reached them.", tag = 15 },
        { "bastion", "The order keeps a counter on the markets. It is open to you. Come and be armed properly next time.", tag = 16 },
    },
}
