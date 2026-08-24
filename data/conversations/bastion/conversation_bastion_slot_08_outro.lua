-- Conversation authored inline (English); localization ids (`tag`) are stamped by
-- tools/extract_strings.lua and must not be hand-edited. See models/conversation.lua.
--
-- OFFER 8 OF 10 (docs/temptation.md), and the only one made by the player's own employer. It has
-- stopped pretending to be a coincidence by now: the order is asking for exactly what the Crown asked
-- Acedia for, in a nicer room, and it does not know that is what it is doing. The house that sells you
-- shields has been serving its sin the whole time (docs/story.md, the claim at the top of the file);
-- this is the scene where the player is invited to serve it too, for money, in writing.
--
-- IT IS PLACED BEFORE HER RE-SWEARING AND THAT IS DELIBERATE. The Aegis scene below is the emotional
-- summit of the entire line -- she sets down a reflex and chooses the player on purpose -- and it has
-- to be able to land on any answer. It gets harder to hear the more the player has taken, and none of
-- that is stated. Nothing in her lines changes. The scene simply means something different.
return {
    title = "A Useful Saint",
    cast  = { "bastion", "character_rowan", "character_avatar" },

    script = {
        { "bastion", "We knew. The terms are under seal in the second vault and they have been since the year it happened.", tag = 1 },
        { "bastion", "She negotiated. Her life and her company's lives, for the gate. There was no siege. There was no desperate hour. It was a transaction and she got her price.", tag = 2 },
        { "bastion", "We weighed a hard truth against a useful saint, knight, and we took the one that keeps the posts manned.", tag = 3 },
        { "bastion", "Every man on that line holds because he can say her name. What would you have had us do?", tag = 4 },
        { "character_rowan", "...", tag = 5 },
        { "bastion", "You have not answered me, and I notice you have not left either.", tag = 12 },
        { "bastion", "The seal holds or it does not, and that is a decision somebody in this room is going to make today.", tag = 13 },
        { "bastion", "A Lord Commander's stipend is four hundred a season and it is paid to people who understand the difference between a hard truth and a useful one.", tag = 14 },
        { "character_avatar", "...", tag = 15, choices = {
            { "\"Keep your stipend.\"", tag = 16, goto = "refuse" },
            { "\"We understand each other.\"", tag = 17, goto = "took", effect = { gold = 400 } },
            { "\"Rowan holds the Aegis. Offer it to her.\"", tag = 18, goto = "with", effect = { gold = 400 } },
        } },
        { "bastion", "Then you will find the second vault is not the only thing that stays shut to you.", tag = 19, id = "refuse", goto = "after" },
        { "bastion", "Sensible. It changes nothing about what she did and it keeps four hundred posts manned.", tag = 20, id = "took", goto = "after" },
        { "character_rowan", "...The knights on that line do not need to know.", tag = 21, id = "with" },
        { "character_rowan", "Knowing would not put one more of them on a wall. It would take them off.", tag = 22 },
        { "bastion", "Spoken like the commander you are going to be.", tag = 23, id = "after" },
        { "character_rowan", "{name}. Walk with me. Not far.", tag = 6 },
        { "character_rowan", "I swore to you in the ash and I never asked you whether you wanted it.", tag = 7 },
        { "character_rowan", "I would have sworn it to anyone burning that night. Anyone at all. That is not devotion. That is a reflex, and I have been calling it my honour for a year.", tag = 8 },
        { "character_rowan", "So. Again, and properly this time. Not to an order. Not to a name off a shield.", tag = 9 },
        { "character_rowan", "To you. I have looked at you and chosen, and I could have chosen otherwise.", tag = 11 },
        { "character_rowan", "We shall hold.", tag = 10 },
    },
}
