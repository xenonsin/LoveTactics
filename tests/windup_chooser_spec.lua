-- The wind-up depth slider (ui/panels/windup_chooser.lua). The behaviour under test is the split
-- between the depth being SHOWN and the depth being CHOSEN: resting the pointer on a rung previews
-- that hold -- repricing the damage read-out and publishing it through onChange, which is what slides
-- the channel's resolve slot along the turn-order strip -- while committing nothing. Only the check
-- swings, and it swings the chosen depth.

local WindupChooser = require("ui.panels.windup_chooser")

-- A chooser wired to recording hooks. `log.changes` is every depth the host was told to preview;
-- `log.priced` is every depth the damage function was asked about; `log.confirmed` is the swing.
local function chooser(lo, hi)
    local log = { changes = {}, priced = {}, confirmed = nil }
    local c = WindupChooser.new({
        lo = lo, hi = hi,
        anchorX = 400, anchorY = 400, tileSize = 48,
        damageAt = function(d)
            log.priced[#log.priced + 1] = d
            return { primary = d * 10, total = d * 10, count = 1 }
        end,
        onChange = function(d) log.changes[#log.changes + 1] = d end,
        onConfirm = function(d) log.confirmed = d end,
    })
    return c, log
end

-- The centre of rung i, in the widget's own space.
local function rungCentre(c, i)
    return c:rungX(i) + 8, c.ladderY + 10
end

return {
    {
        name = "the chooser opens at its floor and prices it without republishing it",
        fn = function()
            local c, log = chooser(2, 5)
            assert(c.depth == 2, "opens at the floor")
            assert(c:shownDepth() == 2, "and shows it")
            assert(#log.priced == 1 and log.priced[1] == 2, "the opening depth is priced once")
            -- The host set battle.windup to the floor when it raised the panel; telling it again is noise.
            assert(#log.changes == 0, "construction publishes nothing, got " .. #log.changes)
        end,
    },
    {
        name = "hovering a rung previews that depth -- damage AND the strip -- without choosing it",
        fn = function()
            local c, log = chooser(2, 5)
            c:mousemoved(rungCentre(c, 4))
            assert(c:shownDepth() == 4, "the hovered rung is the shown depth")
            assert(c.dmg.primary == 40, "the read-out reprices to the hovered depth")
            assert(#log.changes == 1 and log.changes[1] == 4,
                "the hover is published once, so the turn-order ghost slides to it")
            -- Nothing was spent: the ladder is still where the player left it.
            assert(c.depth == 2, "hovering never moves the chosen depth")
            c:confirm()
            assert(log.confirmed == 2, "the check swings the CHOSEN depth, not the hovered one")
        end,
    },
    {
        name = "a hover that stays put is not repriced every frame",
        fn = function()
            local c, log = chooser(1, 5)
            local x, y = rungCentre(c, 3)
            c:mousemoved(x, y)
            c:mousemoved(x + 1, y + 1) -- same rung, a pixel over
            c:mousemoved(x, y)
            assert(#log.changes == 1, "one crossing onto the rung, one publish, got " .. #log.changes)
            assert(#log.priced == 2, "one opening price plus one hover price, got " .. #log.priced)
        end,
    },
    {
        name = "leaving the ladder drops the preview back to the chosen depth",
        fn = function()
            local c, log = chooser(2, 5)
            c:mousemoved(rungCentre(c, 5))
            assert(c:shownDepth() == 5, "hovered deep")
            c:mousemoved(c.ladderX, c.ladderY - 40) -- up onto the read-out line
            assert(c.hoverRung == nil, "off the ladder, nothing is hovered")
            assert(c:shownDepth() == 2 and c.dmg.primary == 20, "the read-out falls back to the choice")
            assert(log.changes[#log.changes] == 2, "and the strip is told to fall back with it")
        end,
    },
    {
        name = "the commit check is not read as the ladder's top rung",
        fn = function()
            local c, log = chooser(2, 5)
            -- The check sits at the ladder's right at the same height. Previewing the deepest hold while
            -- the pointer is on a button that commits the shallow one would make the two disagree.
            c:mousemoved(c.checkRect.x + 12, c.checkRect.y + 10)
            assert(c.hoverCheck, "the check is hovered")
            assert(c.hoverRung == nil, "but no rung is")
            assert(c:shownDepth() == 2, "so the read-out still shows what the check would swing")
            assert(#log.changes == 0, "and nothing was published")
        end,
    },
    {
        name = "clicking a rung chooses it, and a drag keeps its grip past the ladder's end",
        fn = function()
            local c, log = chooser(1, 5)
            local x, y = rungCentre(c, 3)
            c:mousepressed(x, y, 1)
            assert(c.depth == 3 and c.dragging, "the click chooses the rung and takes the grip")
            assert(log.changes[#log.changes] == 3, "published once")
            -- Dragging past the right end still tracks the last rung rather than dropping the grip.
            -- (The hover bound added for the check applies to a plain hover, never to a live drag.)
            c.dragging = true
            c:setDepth(c:rungAt(c.ladderX + c.ladderW + 200, c.ladderY + 10, true))
            assert(c.depth == 5, "the drag clamps to the deepest rung, got " .. c.depth)
        end,
    },
    {
        name = "arrows step the chosen depth out from under a resting pointer",
        fn = function()
            local c, log = chooser(2, 5)
            c:mousemoved(rungCentre(c, 3))
            assert(c:shownDepth() == 3, "hovering rung 3")
            c:keypressed("right") -- the pad/keyboard moves the real depth: 2 -> 3
            assert(c.depth == 3, "the chosen depth stepped")
            assert(c.hoverRung == nil, "the stale hover preview was dropped")
            assert(c:shownDepth() == 3, "shown and chosen agree again")
            c:keypressed("right")
            assert(c.depth == 4 and c:shownDepth() == 4, "and keep agreeing as it steps on")
            assert(log.changes[#log.changes] == 4, "the strip follows the arrows")
        end,
    },
    {
        name = "the floor is never given up, by hover or by key",
        fn = function()
            local c = chooser(3, 5)
            c:mousemoved(rungCentre(c, 1))
            assert(c:shownDepth() == 3, "a rung below the floor previews the floor, got " .. c:shownDepth())
            c:keypressed("left")
            assert(c.depth == 3, "and the floor holds against a step down")
        end,
    },
}
