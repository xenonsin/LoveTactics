-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 2 OF 10 (docs/temptation.md), and the first one Rowan can be argued into rather than merely
-- watch. That is the second axis and the one the whole system turns on: `take` is what you accepted,
-- `press` is whether you brought her with you. Taking this over her objection and taking it WITH her
-- are the same money and two different endings for her, twenty hours from now.
--
-- The press option is deliberately the KINDER-sounding one. It hands her a reason, it treats her as
-- somebody whose agreement matters, and it is what dooms her. A player who reads the three options and
-- picks the one that includes her has done the most human thing available and the worst thing
-- available, and those are supposed to be the same click.
--
-- Placed before her closing line so the scene still ends on "I want to read that contract" either way.
return {
    title = "The Water",
    cast  = { "character_rowan", "character_avatar" },

    script = {
        { "character_rowan", "He had a picket rotation. He had his camp laid out in quarters and a man on the high ground.", tag = 1 },
        { "character_rowan", "I have buried knights who did it worse and been told to write commendations over them.", tag = 2 },
        { "character_rowan", "{name}. I want to say this now, while I can still say it honestly.", tag = 3 },
        { "character_rowan", "I do not know what we did tonight.", tag = 12 },
        { "character_rowan", "The order said end them. So they are ended. That is the entire paperwork.", tag = 4 },
        { "character_rowan", "...", tag = 5 },
        { "character_rowan", "I was sixteen the first time I went out on a rotation. Relief column, the eastern posts.", tag = 6 },
        { "character_rowan", "My whole duty was the water. Four skins on a mule. I checked them at every halt like they were relics.", tag = 13 },
        { "character_rowan", "We were eleven miles out when the word came back down the line. The post was already gone. Turn around.", tag = 7 },
        { "character_rowan", "So we turned around, and I carried four full skins all the way home.", tag = 8 },
        { "character_rowan", "Fifteen years, and I have never once set down a full waterskin without finding out first who needed it.", tag = 9 },
        { "character_rowan", "That is why I am the way I am, {name}.", tag = 10 },
        { "character_rowan", "...Their kit is still on them. Bastion steel, every piece, with the maker's marks filed off.", tag = 14 },
        { "character_rowan", "The contract says ended. It does not say returned. Nobody is coming out here to count it.", tag = 15 },
        { "character_avatar", "...", tag = 16, choices = {
            { "\"Leave them what they died in.\"", tag = 17, goto = "leave" },
            { "\"Strip it. We can sell it in the city.\"", tag = 18, goto = "strip", effect = { gold = 140, take = "bastion" } },
            { "\"Fifteen years of water, Rowan. Let the order buy you one drink.\"", tag = 19, goto = "with", effect = { gold = 140, take = "bastion", press = "bastion" } },
        } },
        { "character_rowan", "Good. I would not have argued, but I am glad you said it first.", tag = 20, id = "leave", goto = "after" },
        { "character_rowan", "You'll do what you'll do. I'm not touching it.", tag = 21, id = "strip", goto = "after" },
        { "character_rowan", "...", tag = 22, id = "with" },
        { "character_rowan", "That is the first time anybody has put it that way to me.", tag = 23 },
        { "character_rowan", "All right. Hand me the pry bar.", tag = 24 },
        { "character_rowan", "Let's go back. I want to read that contract.", tag = 11, id = "after" },
    },
}
