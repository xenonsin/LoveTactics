-- ENTHRONED: the Hollow Crown on its throne, phases 1 and 2 (models/hollow_crown.lua; slice D). The throne is the
-- body -- 3x3, seated at the far edge -- and this is what keeps it there: it cannot walk and nothing moves it. It
-- comes off at half health, when the Crown steps down and walks.
--
-- The badge is also the first phase's readout. While its court convenes, a holding Archon Warden within 2 of the
-- throne voids every blow on it (HollowCrown.ward), and the description says so for as long as that is true
-- (`court` on the instance, cleared when the court is down).
--
-- What the Crown IS rather than a blessing it holds: `undispellable`, so no strip takes it, the grey water does not
-- wash it off and the Fairest does not count it; `hideLog`, since the Crown's own lines say what is happening.
return {
    name = "Enthroned",
    abbr = "Thr",
    description = "Seated on its throne: cannot move or be moved.",
    describe = function(s)
        if s and s.court then
            return "Seated on its throne: cannot move or be moved. Takes no damage while an Archon Warden holds still within 2."
        end
        return "Seated on its throne: cannot move or be moved."
    end,
    color = { 0.820, 0.700, 0.360 }, -- badge tint (old gold)
    duration = 9999,
    hideDuration = true,
    hideLog = true,
    undispellable = true,
    blocksMove = true,
    blocksForcedMove = true,
}
