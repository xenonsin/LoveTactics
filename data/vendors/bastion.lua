-- Knight vendor. Its quest line is duty kept under pressure, and ends facing Sloth --
-- which is not laziness but dereliction: the oath abandoned.
return {
    name = "The Bastion",
    class = "knight",
    description = "An order that measures a knight by what they refused to abandon.",
    sin = "sloth",
    -- The companion this house's line earns. Authored here rather than derived: the pairing is a design
    -- fact (docs/story.md -- a general and her foil are the same wound with two answers) stated nowhere
    -- else in data. models/descent_recruit.lua reads it to seat the seven named heroes in the recruit
    -- roster. Rowan is the Bastion's even though the prologue hands her over rather than this board.
    companion = "character_rowan",
}
