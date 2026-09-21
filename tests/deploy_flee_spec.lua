-- THE RUN AWAY PLATE (ui/deploy_phase.lua's controls).
--
-- THE WHOLE READOUT IS THE LABEL. There used to be a note beside this plate, opened on hover and on a
-- pad selection, with a status box stacked under it naming what a failed attempt costs; both are gone.
-- What is left has to carry the decision on its own -- the odds on the thing the player presses -- so
-- what is pinned here is that the number reaches the label, and that the plate only stands on a fight
-- there is a way out of.
--
-- The stake needs nothing here: a caught company's enemies wear Hasted from the moment the roll fails
-- (states/game.lua's onFlee, tests/flee_spec.lua) -- the hint line says so in words and the badges are
-- on the tokens before the bell.
--
-- Constructed by hand rather than through DeployPhase.new, as tests/deploy_input_spec.lua does and for
-- the same reason (the constructor builds fonts, and love.graphics.newFont throws headless).

local DeployPhase = require("ui.deploy_phase")

local function phase(opts)
    opts = opts or {}
    return setmetatable({
        column = { x = 16, y = 104, w = 130 },
        placed = { { char = "knight", x = 1, y = 1 } },
        roster = {},
        allowAuto = true,
        autoBattle = false,
        autoSpeed = 1,
        speedSteps = { 1, 2, 3 },
        onFlee = opts.onFlee,
        fleeChance = opts.fleeChance,
        mx = 0, my = 0,
    }, DeployPhase)
end

local function flee(p)
    for _, c in ipairs(p:controls()) do
        if c.key == "flee" then return c end
    end
end

return {
    {
        name = "the plate quotes the odds it is offering",
        fn = function()
            -- A wager has to quote its price, and this is the only surface left that can.
            local c = flee(phase({ onFlee = function() end, fleeChance = 55 }))
            assert(c, "the plate itself is missing")
            assert(c.label == "Run Away (55%)",
                "the plate reads '" .. tostring(c.label) .. "' and names no price")
            assert(c.enabled, "the way out is drawn and cannot be pressed")

            -- Every rung of the curve reaches the label, not just the even one.
            for _, odds in ipairs({ 20, 37, 55, 72, 90 }) do
                local label = flee(phase({ onFlee = function() end, fleeChance = odds })).label
                assert(label == ("Run Away (" .. odds .. "%)"),
                    "a " .. odds .. "% escape reads '" .. tostring(label) .. "'")
            end
        end,
    },
    {
        -- A probe or a debug board hands over a way out with no muster behind it to price. The plate
        -- still works; it just stops claiming a number nobody computed.
        name = "a plate with no odds behind it says nothing rather than lying",
        fn = function()
            local c = flee(phase({ onFlee = function() end }))
            assert(c and c.label == "Run Away",
                "an unpriced escape reads '" .. tostring(c and c.label) .. "'")
        end,
    },
    {
        -- No way out, no plate: a fight that may not be fled (an objective, a campaign board) never
        -- draws the button at all, and a button that is there is a promise about the board.
        name = "a fight with no way out has no plate",
        fn = function()
            assert(flee(phase()) == nil, "a board with no escape offered one")
        end,
    },
}
