-- The stop's panel: ONE body, taken on or walked past (ui/panels/recruit.lua).
--
-- What is worth pinning here is the part a model spec cannot see. models/descent_recruit.lua's cases
-- prove the right body is offered at the right level; these prove the player can READ it and ANSWER it
-- without a mouse -- the kit cursor that opens a tooltip on each carried piece, the two rings that say
-- which pieces are the body's signature pair, and the two answers firing exactly once each.
--
-- Built through the real producer: Recruit.preview hands over the same character the floor draws, so a
-- field renamed under this panel fails here rather than at the tile.
--
-- Fonts are stubbed the way tests/advancement_spec.lua does it -- the panel bakes its faces in `new` and
-- love.graphics.newFont throws with no window. Nothing here draws.

local Character = require("models.character")
local Descent = require("models.descent")
local Recruit = require("models.descent_recruit")
local RecruitPanel = require("ui.panels.recruit")
local Scale = require("scale")

-- A body carrying a signature pair, so the ring and the sentence have something to be about. The generic
-- knight is spear-and-buckler by blueprint (data/characters/character_knight.lua).
local ID = "character_knight"

local function stubFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    gfx.newFont = function()
        return {
            getHeight = function() return 18 end,
            getWidth = function(_, s) return #tostring(s or "") * 8 end,
            getWrap = function(_, text, _) return text, { text } end,
        }
    end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

local function panel(opts)
    opts = opts or {}
    local profile = Descent.newProfile(Descent.startingCompany())
    local char = Recruit.preview(profile, opts.id or ID)
    return RecruitPanel.new({
        char = char,
        prompt = "The company holds 4, and stands 0 today.",
        onAccept = opts.onAccept or function() end,
        onDecline = opts.onDecline or function() end,
    }), char
end

-- Every case builds a panel, so every case needs the stub in force around it.
local function case(name, body)
    return { name = name, fn = function() stubFonts(body) end }
end

return {
    case("the panel opens on the offer, with nothing pried open yet", function()
        assert(Character.defs[ID], ID .. " is the fixture this whole file is about")
        local p, char = panel()
        assert(p.choice == 1, "the panel opens on taking them on, not on the refusal")
        assert(p:openSlot() == nil, "and with no tooltip already open over the card")
        assert(p.name == char.name, "it names the body it was handed")
        assert(p.fights and p.fights:find("Fights with"),
            "and says what the ringed pair IS, in words: " .. tostring(p.fights))

        -- The whole card has to be on the screen. It grows with the prompt's wrap and the kit's caption,
        -- so a body with a long name or a two-line prompt is exactly how this would go off the bottom.
        assert(p.boxY >= 0 and p.boxY + p.boxH <= Scale.HEIGHT,
            "the card runs off the screen: " .. p.boxY .. " + " .. p.boxH)
        assert(p.boxX >= 0 and p.boxX + p.boxW <= Scale.WIDTH, "...or off its side")
    end),

    case("the kit cursor walks the pieces the body is carrying, and off the end of them", function()
        local p, char = panel()
        local carried = 0
        for cell = 1, 9 do if char.inventory[cell] then carried = carried + 1 end end
        assert(#p.slots == carried,
            "every carried piece is a stop and an empty cell is not: " .. #p.slots .. " vs " .. carried)

        for i = 1, carried do
            p:keypressed("down")
            local open = p:openSlot()
            assert(open == p.slots[i], "down must step to piece " .. i)
            assert(open.item, "and a stop always has something to read on it")
        end
        p:keypressed("down")
        assert(p:openSlot() == nil, "walking off the end closes the box again")
        p:keypressed("up")
        assert(p:openSlot() == p.slots[carried], "and up from nothing comes back at the last piece")

        -- Reading the kit must never re-aim the answer under it.
        assert(p.choice == 1, "the kit cursor moved the answer, which is the one thing it must not touch")
    end),

    case("the signature pair is ringed where it sits, and nothing else is", function()
        local p, char = panel()
        local ringed = {}
        for _, slot in ipairs(p.slots) do
            if slot.key then ringed[slot.item.id] = true end
        end
        for _, id in ipairs({ char.signatureWeapon, char.signatureAbility }) do
            assert(ringed[id], id .. " is what this body IS, and the grid does not mark it")
            ringed[id] = nil
        end
        assert(next(ringed) == nil, "and an ordinary piece of kit is not dressed up as a signature")
    end),

    case("the two answers fire once each, by key and by pad", function()
        local took, left = 0, 0
        local p = panel({ onAccept = function() took = took + 1 end })
        p:keypressed("return")
        p:keypressed("return")
        assert(took == 1, "take fired " .. took .. " times; a spent panel must not answer twice")

        p = panel({ onDecline = function() left = left + 1 end })
        p:keypressed("escape")
        assert(left == 1, "Esc walks on")

        -- Left/Right picks the answer; Enter commits whichever is picked. The refusal is reachable
        -- without ever touching the mouse or the X.
        took, left = 0, 0
        p = panel({ onAccept = function() took = took + 1 end, onDecline = function() left = left + 1 end })
        p:keypressed("right")
        p:keypressed("return")
        assert(left == 1 and took == 0, "Right then Enter must walk on, not recruit")

        took, left = 0, 0
        p = panel({ onAccept = function() took = took + 1 end, onDecline = function() left = left + 1 end })
        p:gamepadpressed(nil, "a")
        assert(took == 1 and left == 0, "A takes them on")
    end),
}
