-- VIRTUE · overworld · common. Charity heals: the worst-off ally is tended after every fight. A found
-- echo of Amana's Kept Trust, softening the attrition the run spends -- so a party without a healer can
-- still buy some sustain off the shelf.
return {
    name = "Alms Bowl",
    blurb = "After every fight, the most-wounded ally is healed a little.",
    tier = "common", alignment = "virtue", affinity = "overworld", weight = 2,
    encounterCleared = function(_, _, ctx)
        local t = ctx.mostWounded()
        if t then
            local healed = ctx.restore(t, "health", 8)
            if healed > 0 then ctx.say("Alms Bowl heals " .. (t.name or "an ally") .. " (+" .. healed .. ")") end
        end
    end,
}
