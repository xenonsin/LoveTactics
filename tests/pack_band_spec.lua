-- The pack band on the Loadout panel's packing screens (ui/panels/party.lua, opts.pool == "both": the
-- Armory and the Gate).
--
-- It replaced a Stash | Pack switch that showed one container at a time and dropped whatever was in hand
-- when it flipped, so a draught reached the bag only by way of somebody's grid. What is pinned here: the
-- band and the stash share the column without overlapping in every space the panel is opened in, the
-- whole bag is on screen at desktop size, a piece moves straight between the two by the send, the drag
-- and the keyboard, the bag is held to the ceiling the chest refuses at, and a piece sent off a body
-- goes where that screen packs to.
--
-- Fonts are stubbed, as every geometry spec here stubs them (`t.window = false`, so newFont throws).

local Scale = require("scale")
local Character = require("models.character")
local Item = require("models.item")
local Descent = require("models.descent")

local DRAUGHT = "consumable_battle_tonic"
local BLADE = "weapon_adder_fang"

local function withFonts(fn)
    local gfx = love.graphics
    local real = gfx.newFont
    local face = {
        getHeight = function() return 18 end,
        getWidth = function(_, s) return #tostring(s or "") * 8 end,
        getWrap = function(self, text, limit) return self:getWidth(text), { tostring(text) } end,
    }
    gfx.newFont = function() return face end
    local ok, err = pcall(fn)
    gfx.newFont = real
    if not ok then error(err, 0) end
end

local function inSpace(w, h, fn)
    local ow, oh, oflag = Scale.WIDTH, Scale.HEIGHT, Scale.inHandheldSpace
    Scale.WIDTH, Scale.HEIGHT = w, h
    Scale.inHandheldSpace = (h == Scale.HANDHELD_H)
    local ok, err = pcall(fn)
    Scale.WIDTH, Scale.HEIGHT, Scale.inHandheldSpace = ow, oh, oflag
    assert(ok, err)
end

local function build(opts)
    opts = opts or {}
    local Party = require("ui.panels.party")
    local roster = {}
    for i = 1, 2 do roster[i] = Character.instantiate("character_knight") end
    local player = { roster = roster, stash = opts.stash or {}, pack = opts.pack or {} }
    local p
    withFonts(function()
        p = Party.new({
            player = player, pool = "both", gridSendTo = opts.gridSendTo,
            persist = false, onClose = function() end,
        })
    end)
    return p, player
end

local function fullPack(n)
    local pack = {}
    for i = 1, n do pack[i] = Item.instantiate(BLADE) end
    return pack
end

return {
    {
        name = "the band sits over the stash in one column, inside the box, in every space",
        fn = function()
            for _, space in ipairs({ { 880, 450 }, { 1120, 450 }, { 1280, 720 } }) do
                inSpace(space[1], space[2], function()
                    local p = build()
                    local where = string.format(" (in %dx%d)", space[1], space[2])
                    local band, stash = p.packPool, p.pool
                    assert(band, "a packing screen has no pack band" .. where)
                    assert(band.x == stash.x and band.w == stash.w, "the band left the stash's column" .. where)
                    assert(band.y + band.h <= p.poolHeaderY, "the band runs into the stash's header" .. where)
                    assert(stash.y > p.poolHeaderY, "the stash runs up over its own header" .. where)
                    local floor = p.boxY + p.boxH - 40
                    assert(stash.y + stash.h <= floor, "the stash runs into the footer" .. where)
                    assert(stash.visRows >= 1, "the band left the stash no row to show" .. where)
                    assert(band.x >= p.grid.x + p.grid.gridW, "the band runs over the member grid" .. where)
                end)
            end
        end,
    },
    {
        name = "at desktop size the whole bag is on screen, empty slots and all, without scrolling",
        fn = function()
            inSpace(1280, 720, function()
                local p = build()
                local band = p.packPool
                assert(not band.arrows, "the band scrolls at the authored size")
                assert(band.cols * band.visRows >= Descent.carryMax(p.player), string.format(
                    "the band shows %d of %d slots", band.cols * band.visRows, Descent.carryMax(p.player)))
                assert(band:slotCount() == Descent.carryMax(p.player), "the empty slots are not drawn")
                assert(p.pool.visRows >= 3, "the stash under the band shows " .. p.pool.visRows .. " rows")
            end)
        end,
    },
    {
        name = "underground the column is the bag and draws its free slots; there is no band",
        fn = function()
            local Party = require("ui.panels.party")
            local p
            withFonts(function()
                p = Party.new({ player = { roster = { Character.instantiate("character_knight") }, stash = {}, pack = {} },
                    pool = "pack", persist = false, onClose = function() end })
            end)
            assert(p.packPool == nil, "a floor of the rift grew a second container")
            assert(p.pool:slotCount() == Descent.carryMax(p.player), "the bag underground draws no free slots")
            assert(p:otherSide("pack") == nil, "underground the send has somewhere to send to")
        end,
    },
    {
        name = "the send moves a piece straight across, both ways, and a stack moves whole",
        fn = function()
            local p, player = build({ stash = { Item.instantiate(DRAUGHT, 3), Item.instantiate(BLADE) } })
            assert(p:moveAcross("stash", 1), "stash -> pack refused")
            assert(#player.stash == 1 and #player.pack == 1, "the draught did not leave the shelf for the bag")
            assert(player.pack[1].id == DRAUGHT and player.pack[1].quantity == 3, "the stack split on the way")
            assert(p.packPool:count() == 1, "the band did not redraw")
            assert(p:moveAcross("pack", 1), "pack -> stash refused")
            assert(#player.pack == 0 and #player.stash == 2, "the draught did not come back to the shelf")
        end,
    },
    {
        name = "a full bag refuses a new piece but still tops up its own stack",
        fn = function()
            local max = Descent.carryMax({})
            local pack = fullPack(max - 1)
            local packed = Item.instantiate(DRAUGHT, 1)
            pack[#pack + 1] = packed
            local p, player = build({ pack = pack,
                stash = { Item.instantiate(BLADE), Item.instantiate(DRAUGHT, Item.maxStack(packed)) } })
            assert(not p:moveAcross("stash", 1), "a full bag took a new piece")
            assert(#player.pack == max, "the bag grew past its ceiling")
            assert(p:moveAcross("stash", 2), "a full bag refused to top up a stack it already holds")
            assert(packed.quantity == Item.maxStack(packed), "the packed stack was not topped up")
            assert(#player.pack == max, "topping up spent a slot")
            assert(player.stash[2] and player.stash[2].quantity == 1,
                "what did not fit should stay on the shelf")
        end,
    },
    {
        name = "a piece sent off a body goes to the bag at the Gate and the shelf at the Armory",
        fn = function()
            for _, case in ipairs({ { "pack", "pack" }, { nil, "stash" } }) do
                local p, player = build({ gridSendTo = case[1] })
                local char = p:currentChar()
                local cell = Character.firstEmptySlot(char)
                char.inventory[cell] = Item.instantiate(BLADE)
                p:setFocus("grid")
                p.grid.cursor = cell
                p:sendFocused()
                assert(char.inventory[cell] == nil, "the send left the piece on the body")
                assert(#player[case[2]] == 1, "the piece did not land in the " .. case[2])
            end
        end,
    },
    {
        name = "dragging off the band onto the stash moves the piece across",
        fn = function()
            local p, player = build({ pack = { Item.instantiate(BLADE) } })
            local bx, by, bw = p.packPool:cellRect(1)
            p:beginDrag("pool", 1, bx + 2, by + 2, "pack")
            p.drag.active = true
            p:dropDrag(p.pool.x + 4, p.pool.y + p.pool.h / 2)
            assert(#player.pack == 0 and #player.stash == 1, "the drop onto the stash did not move it")
        end,
    },
    {
        name = "up off the stash's first row walks into the band, and down off the band walks back",
        fn = function()
            local p = build({ stash = { Item.instantiate(BLADE) }, pack = { Item.instantiate(BLADE) } })
            p:setFocus("pool")
            p.pool.cursor = 1
            p:navigate(0, -1)
            assert(p.focus == "pack", "up off the stash went to " .. tostring(p.focus))
            p:navigate(0, 1)
            assert(p.focus == "pool", "down off the band went to " .. tostring(p.focus))
            p:navigate(-1, 0)
            assert(p.focus == "grid", "left off the stash's first column went to " .. tostring(p.focus))
        end,
    },
}
