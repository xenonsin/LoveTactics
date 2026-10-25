-- THE AVATAR ALWAYS GOES (2026-10-25). Descent.party seats the avatar first on every expedition, a pick
-- that leaves it out loses its last name to it, and the Ward will not lay it up -- so its bones are set
-- for gold or carried (docs/the-count.md's one exception), and a roster can never rest itself into a
-- company that cannot walk down.

local Descent = require("models.descent")
local Injury = require("models.injury")
local Player = require("models.player")

local function company()
    local p = Player.new()
    p.roster = {
        { id = "character_rowan" }, { id = "character_xin" }, { id = "character_gyeom" },
        { id = "character_kaya" }, { id = "character_avatar" },
    }
    return p
end

local function ids(list)
    local out = {}
    for i, c in ipairs(list) do out[i] = c.id end
    return table.concat(out, ",")
end

return {
    {
        name = "an unpicked party seats the avatar first, then the roster",
        fn = function()
            local p = company()
            local party = Descent.party({}, p)
            assert(ids(party) == "character_avatar,character_rowan,character_xin,character_gyeom", ids(party))
        end,
    },
    {
        name = "a pick of four others loses its last name to the avatar",
        fn = function()
            local p = company()
            local run = {}
            Descent.setParty(run, { "character_rowan", "character_xin", "character_gyeom", "character_kaya" })
            local party = Descent.party(run, p)
            assert(#party == Descent.PARTY_MAX)
            assert(party[1].id == "character_avatar", "the avatar must be seated")
            assert(ids(party) == "character_avatar,character_rowan,character_xin,character_gyeom", ids(party))
        end,
    },
    {
        name = "the avatar goes even if an old save has it in the ward",
        fn = function()
            local p = company()
            p.resting = { character_avatar = 2, character_rowan = 2 }
            local party = Descent.party({}, p)
            assert(party[1].id == "character_avatar")
            for _, c in ipairs(party) do assert(c.id ~= "character_rowan", "a resting companion still sits out") end
        end,
    },
    {
        name = "the Ward will not rest the avatar, and the seat is reported fixed",
        fn = function()
            local p = company()
            p.injuries = { character_avatar = { "injury_blood_loss" } }
            assert(not Injury.canRest("character_avatar"))
            assert(Injury.rest(p, "character_avatar") == 0, "resting the avatar should be refused")
            assert(Injury.resting(p, "character_avatar") == 0)
            assert(Descent.isFixedSeat("character_avatar") and not Descent.isFixedSeat("character_rowan"))
        end,
    },
}
