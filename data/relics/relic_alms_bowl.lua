-- VIRTUE · overworld · common. Charity mends: the worst-off ally is tended after every fight. A found
-- echo of Amana's Kept Trust, softening the attrition the run spends -- so a party without a healer can
-- still buy some sustain off the shelf.
return {
    name = "Alms Bowl",
    blurb = "After every fight, the most-wounded ally is mended a little.",
    tier = "common", alignment = "virtue", affinity = "overworld", weight = 2,
    encounterCleared = function(_, _, ctx)
        local t = ctx.mostWounded()
        if t then
            local mended = ctx.restore(t, "health", 8)
            if mended > 0 then ctx.say("Alms Bowl mends " .. (t.name or "an ally") .. " (+" .. mended .. ")") end
        end
    end,
}
