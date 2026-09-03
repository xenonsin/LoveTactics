-- THE BODY CARD (ui/body_tooltip.lua): what the Gate says about a body when you hover one.
--
-- Driven through BodyTooltip.blocks rather than its draw, which is the whole reason the contents are
-- assembled separately from the rendering: the block list IS what the player reads, and it can be read
-- here without a window or a font.
--
-- What the card owes the question it is opened on ("who goes down"):
--   * who they are -- the name, and what they are growing as
--   * what is wrong with them -- the wound count, the pool a wound has locked away, and the status the
--     battle will stamp on them for carrying it
--   * what they bring -- the flat stats with the gear folded in, and NOT the kit by name: the item
--     list is deliberately gone from this box
--
-- The wound half is the part worth pinning: the reserved slice is computed from the player's ledger
-- through Combat.unreservedMax, so a card drawn before Wound.stamp has run would quietly show a whole
-- body. tests/wound_rest_spec.lua covers the ledger itself.

local BodyTooltip = require("ui.body_tooltip")
local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")
local Wound = require("models.wound")

local function company(wounds)
    local p = Player.new()
    p.roster = { Character.instantiate("character_rowan") }
    p.wounds = {}
    if wounds and wounds > 0 then
        p.wounded = true
        p.wounds[p.roster[1].id] = wounds
    end
    Wound.stamp(p)
    Player.restore(p)
    return p, p.roster[1]
end

-- The first block of `kind` whose label (or name/text) matches, or nil.
local function find(blocks, kind, label)
    for _, b in ipairs(blocks) do
        if b.kind == kind and (not label or b.label == label or b.name == label) then return b end
    end
end

return {
    {
        name = "the card names the body, its class and its pools -- and never lists the kit",
        fn = function()
            local p, char = company(0)
            Character.addItem(char, Item.instantiate("weapon_iron_sword"))
            local blocks = BodyTooltip.blocks(p, char)

            local title = find(blocks, "title")
            assert(title and title.text == char.name, "the card does not name the body")
            local class = find(blocks, "stat", "Class")
            assert(class and class.value == "Knight", "the card does not say what she is")

            local hp = find(blocks, "bar", "HP")
            assert(hp and hp.max == char.stats.health.max, "an unwounded body's pool is not whole")
            assert(not hp.reserved, "an unwounded body has a slice of her health locked away")

            local attack = find(blocks, "stat", "Attack")
            assert(attack, "the card does not carry what the body hits for")

            -- THE KIT IS NOT ON THE CARD. What the gear is worth is already in the stat rows; naming
            -- the items again was the longest half of the box and read by nobody, and the blade is
            -- chosen in the Armory rather than at the Gate.
            local carried = 0
            for _, item in ipairs(Character.eachItem(char)) do
                assert(not find(blocks, "stat", item.name),
                    "the card lists " .. item.name .. " -- the kit is gone from this box")
                carried = carried + 1
            end
            assert(carried > 0, "the fixture carries nothing, so the absent kit proves nothing")
            for _, b in ipairs(blocks) do
                assert(not (b.kind == "head" and b.text == "Carrying"), "the Carrying heading is back")
            end
        end,
    },
    {
        -- A WOUND IS THE ONE FACT THAT CHANGES WHO YOU SEND, so it is on the card three ways: counted,
        -- taken off the top of the health bar, and named as the status the fight will stamp.
        name = "a wound is counted, locked out of the health bar, and named as what she fights under",
        fn = function()
            local p, char = company(2)
            local blocks = BodyTooltip.blocks(p, char)

            local count = find(blocks, "stat", "Wounds")
            assert(count and count.value == "2", "the card does not count the wounds")

            local hp = find(blocks, "bar", "HP")
            assert(hp.reserved and hp.reserved > 0, "a wound takes nothing off the pool")
            assert(hp.fullMax == char.stats.health.max, "the bar lost its true ceiling")
            assert(hp.max == char.stats.health.max - hp.reserved, "the ceiling and the reserve disagree")
            -- Said in the word the player is being charged in, not the battle's "res." (a sustained
            -- summon), which is the other thing that locks a tail of a pool.
            assert(hp.reservedLabel == "wounded", "the locked slice does not say what took it")

            -- Whatever models/wound.lua says a wounded body fights under, said here -- read off the
            -- model so the card cannot promise a rung the ladder no longer has.
            for _, effect in ipairs(Wound.combatEffects(p, char.id)) do
                local def = require("models.status").defs[effect.id]
                assert(find(blocks, "status", def.name),
                    "the card does not name " .. tostring(def.name))
            end
        end,
    },
    {
        -- The Gate's picker hands whatever is under the cursor straight in, and an empty plate hands
        -- in nothing.
        name = "no body, no card",
        fn = function()
            assert(BodyTooltip.blocks(Player.new(), nil) == nil, "the card drew for nobody")
        end,
    },
}
