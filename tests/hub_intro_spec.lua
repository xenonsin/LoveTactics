-- THE FIRST VISIT TO THE CAPITAL: the sponsor's staked voucher, and the two doors the tutorial coaches.
--
-- The prologue ends with the party walking into the city and a sponsor cutting in front of the
-- Adventurers' Guild (conversation_prologue_sponsor). What happens next is the only guided sequence
-- outside a battle: hire the body she has already paid for, then go down. states/hub.lua drives it off
-- `player.hubIntro`, which is a string on the save and therefore the one part of this that can rot
-- without anything saying so -- so the stages are pinned here, along with the model half underneath
-- them (models/voucher.lua's Voucher.stake).
--
-- Headless and pure: no state is entered and no frame is drawn. What is asserted is the DATA the state
-- reads -- what the sponsor left in the purse, whether spending it puts her in the company, and that
-- the cards the two stages point at are cards the city actually has.

local Building = require("models.building")
local Character = require("models.character")
local Player = require("models.player")
local Recruit = require("models.descent_recruit")
local Voucher = require("models.voucher")

-- Who the sponsor stakes, and the stages that coach the two doors. Restated here rather than reached
-- for, because states/hub.lua keeps both as file-locals: what this spec is for is catching the day one
-- of them changes and the other does not.
local HIRE = "character_saber"
local STAGES = {
    { flag = "hire",  building = "hiring_hall" },
    { flag = "coach", building = "the_gate" },
}

local function cityHas(id)
    -- Listed for a player past every gate, since the point is that the CARD exists rather than that it
    -- is open: the hall and the stair are both open on a fresh save anyway (tests/hub_spec.lua).
    for _, b in ipairs(Building.list(Player.new(), { district = "city" })) do
        if b.id == id then return b end
    end
    return nil
end

return {
    {
        -- THE VOUCHER SHE PAID FOR. Iselle's terms open with the hirelings being on her, and a company
        -- of two walking down a stair that has already swallowed four companies is her staking the fifth
        -- as badly as she staked the other four. So there is a voucher in the purse before the player
        -- has looked at the city, and the pull it buys is rigged to the body the story picked.
        --
        -- SHE USED TO STAKE THE BODY ITSELF, standing in a hall whose whole stock was the people you had
        -- walked past on a floor. That hall is gone (models/voucher.lua) and the stake moved with it --
        -- one voucher, once, and a rigged first pull, which is the shape every game in this genre gives
        -- its opening.
        name = "the sponsor stakes one voucher, and it calls the body the story picked",
        fn = function()
            local p = Player.new()
            assert(Voucher.count(p) == 0, "a purse nobody has stocked is empty")

            assert(Voucher.stake(p, HIRE), "the stake takes")
            assert(Voucher.count(p) == 1, "one voucher waiting")
            assert(Voucher.peek(p) == HIRE,
                "the staked voucher must call the body the tutorial is pointing at")

            -- Idempotent: the sponsor paid for one, not for one per visit.
            Voucher.stake(p, HIRE)
            assert(Voucher.count(p) == 1, "staking twice does not put two vouchers in the purse")
        end,
    },
    {
        -- SPENT BY THE PULL. The tutorial's stage is cleared by the body actually joining
        -- (states/hub.lua's introAdvance walks the roster), so the pull has to put her there.
        name = "spending the staked voucher puts her in the company and ends the stake",
        fn = function()
            local p = Player.new()
            p.roster = {}
            Voucher.stake(p, HIRE)

            local result = Voucher.pull(p)
            assert(result and result.id == HIRE, HIRE .. " answers")
            assert(result.char and not result.dupe, "she joins rather than bonding")
            local inCompany = false
            for _, char in ipairs(p.roster) do if char.id == HIRE then inCompany = true end end
            assert(inCompany, "...and she is in the company, which is what clears the coached stage")

            assert(Voucher.count(p) == 0, "the voucher is spent")
            assert(p.riggedPull == nil, "the rig is spent with it")
            assert(not Voucher.stake(p, HIRE), "the sponsor does not pay a second time")
        end,
    },
    {
        -- THE TWO DOORS THE TUTORIAL COACHES, in order. A stage naming a card the city does not have
        -- would anchor the coach bubble to a rect that does not exist and leave the player looking at a
        -- plaza where nothing can be pressed -- which is exactly what retiring the Quest Board did to
        -- the stage that used to point at it.
        name = "each coached stage names a card the city actually has",
        fn = function()
            for _, stage in ipairs(STAGES) do
                local card = cityHas(stage.building)
                assert(card, stage.flag .. " coaches " .. stage.building .. ", which is not in the city")
                assert(not card.locked,
                    stage.building .. " is coached on the first visit and must not be a shut door")
            end

            -- The hall goes first BECAUSE the Gate is one-way: a player coached straight down the stair
            -- takes the prologue's two bodies onto floor one, and the room that would have fixed that is
            -- a card they were told not to press.
            assert(STAGES[1].building == "hiring_hall" and STAGES[2].building == "the_gate",
                "the hire is coached before the stair")
        end,
    },
    {
        -- The hire is a real body with a real card. A slate entry whose blueprint has gone is dropped at
        -- the model (Recruit.pool), so a rotted id would not crash -- it would silently produce a hall that
        -- deals somebody else and a tutorial stage that can never be satisfied.
        name = "the staked hire is a body the hall can build and describe",
        fn = function()
            assert(Character.defs[HIRE], HIRE .. " has no blueprint, so the hall would show an empty room")
            assert(Recruit.nameOf(HIRE), "the card needs a name to print")
            local desc = Recruit.describe(HIRE)
            assert(desc and desc ~= "", "a row the player chooses is a sentence, not a name")

            -- SHE IS A BODY THE FLOORS COULD HAVE OFFERED, and that is the load-bearing half. The hall
            -- deals off the same census the floors are graded against (models/descent_recruit.lua), so a rig
            -- naming somebody outside
            -- Recruit.pool would be the town minting a body the descent has no depth for, which is a rig that
            -- teaches the player a pull can do something a pull cannot.
            --
            -- Saber qualifies because she is a LINE COMPANION (a house's `companion`, data/vendors/),
            -- and the seven of
            -- those stand on the first floor: a base class is what a player has from the beginning, so
            -- there is no ladder above it to climb.
            local shallow = false
            for _, id in ipairs(Recruit.pool(1)) do
                if id == HIRE then shallow = true end
            end
            assert(shallow, HIRE .. " is staked at the hall but stands on no floor the descent deals")
        end,
    },
}
