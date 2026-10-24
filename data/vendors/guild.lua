-- THE GUILD's attendant: the one behind the counter at the Gate, who writes a name on the roll.
--
-- The city runs on adventurers going down the Rift, and the guild is how it keeps count of them. The
-- attendant is the face of that: the avatar's first class is granted at this counter, on the Demon
-- Champion's horn as proof and Rowan as the guild's witness (conversation_prologue_arrival), and the same
-- face is behind the counter every time the company stands at the mouth of the stair (states/gate.lua's
-- keeper pane).
--
-- IT KEEPS A BLUEPRINT WITHOUT KEEPING A SHELF, on the Crossing's and the Touchstone's terms
-- (data/vendors/crossing.lua): what a vendor file buys here is a SHOPKEEPER -- a portrait, a name, a line,
-- and a speaker id a scene can cast. `sells = false` and no `class`, so nothing is stocked and it is no
-- house on the market board.
--
-- THE NAME IS A PLACEHOLDER. The attendant is a person; what they are called is the author's to write.
return {
    name = "Guild Attendant",
    portrait = "assets/portraits/guild.png",
    sells = false, -- sells no ITEMS; its whole business is the roll
    description = "Names go on the roll here, and come off it.",
}
