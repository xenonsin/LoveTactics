-- ASHEN ECHO: the badge a Mimic-of-Ash wears while it holds an element it was struck with (trait_ashen_echo).
-- Creature identity pass, 2026-11-19.
--
-- The badge is the telegraph: it names what the mimic will throw back, so a player can see that their fire is
-- coming home before it does. The element rides on the instance (`element`, set by the trait) and the tooltip
-- reads it live (`describe`, as Already Known does).
--
-- Not a blessing: it is what the ash IS this turn, so a Dispel does not wash it out -- a plain blow does.
local BASE = "Ashen Echo: its weapon strikes carry the element it was last struck with. A plain blow clears it."

return {
    name = "Ashen Echo",
    abbr = "Echo",
    description = BASE,
    color = { 0.600, 0.560, 0.520 }, -- badge tint (ash grey, warm)
    duration = math.huge,
    hideDuration = true,
    undispellable = true,
    describe = function(status)
        local e = status and status.element
        if not e then return BASE end
        return "Ashen Echo: its weapon strikes carry " .. e .. ". A plain blow clears it."
    end,
}
