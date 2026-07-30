-- CROSSROADS dilemmas: the data behind a `crossroads` overworld stop (states/game.lua routes one to a
-- ui/panels/choice.lua modal). Each is a small branching gamble with real stakes -- a relic, some coin, a
-- wound, a wager -- so a stop between fights is a decision, not a cutscene. Kept as pure data + resolve
-- functions; the mechanics come in through a `ctx` of headless-safe helpers the caller binds (the same
-- shape relics and traits take), so this module never reaches into a model directly and stays testable.
--
-- ctx = {
--   grantRelic(tier?) -> names the relic granted (or nil if the shelf was bare),
--   addGold(n), drainParty(n) (a wound, floored so it never fells), reveal() (study the ground),
--   rnd() -> [0,1), notify(msg),
-- }
-- A resolve returns nothing; it speaks its own outcome through ctx.notify / the grant's own toast.

local Crossroads = {}

Crossroads.dilemmas = {
    {
        prompt = "A dying courier presses a sealed case into your hands, then goes still.",
        options = {
            { label = "Take the case", desc = "Claim what the courier died carrying -- a relic for the run.",
                resolve = function(ctx)
                    local got = ctx.grantRelic()
                    if not got then ctx.notify("The case holds nothing you can use") end
                end },
            { label = "Search the purse", desc = "Leave the case sealed; take the coin instead.",
                resolve = function(ctx) ctx.addGold(28) end },
        },
    },
    {
        prompt = "A moss-covered altar hums, offering a wager to the bold.",
        options = {
            { label = "Press your luck", desc = "Fortune's favour is a rare relic; its scorn is a wound.",
                resolve = function(ctx)
                    if ctx.rnd() < 0.55 and ctx.grantRelic("rare") then
                        -- the grant speaks for itself
                    else
                        ctx.drainParty(6)
                        ctx.notify("The altar exacts its price in blood")
                    end
                end },
            { label = "Walk on", desc = "Risk nothing, gain nothing.", resolve = function() end },
        },
    },
    {
        prompt = "The trail forks: one path quick and bare, one long and rumoured rich.",
        options = {
            { label = "The greedy way", desc = "A longer road, but coin waits at its end.",
                resolve = function(ctx) ctx.addGold(22) end },
            { label = "The scout's way", desc = "Read the ground: lift the fog toward the objective.",
                resolve = function(ctx) ctx.reveal(); ctx.notify("You read the road ahead") end },
        },
    },
    {
        prompt = "A beggar-saint bars the path, palm open for an offering.",
        options = {
            { label = "Give freely", desc = "Pay 18 gold; the saint blesses your road with a relic.",
                resolve = function(ctx)
                    if (ctx.gold and ctx.gold() or 0) >= 18 then
                        ctx.addGold(-18)
                        if not ctx.grantRelic() then ctx.notify("The blessing finds nothing to give") end
                    else
                        ctx.notify("You haven't the coin to give")
                    end
                end },
            { label = "Push past", desc = "Keep your coin and your luck as it is.", resolve = function() end },
        },
    },
}

-- A random dilemma. `rnd` is a function returning [0,1) (love.math or math.random); nil falls back.
function Crossroads.roll(rnd)
    rnd = rnd or function() return math.random() end
    local i = math.floor(rnd() * #Crossroads.dilemmas) + 1
    if i < 1 then i = 1 elseif i > #Crossroads.dilemmas then i = #Crossroads.dilemmas end
    return Crossroads.dilemmas[i]
end

return Crossroads
