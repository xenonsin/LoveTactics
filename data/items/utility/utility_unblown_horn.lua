-- Lifted off the Late Watch, and it is paid for every oath its bearer imposes.
--
-- THE PAIR. The Forsworn Pike swears the WHOLE enemy party into pairs at the opening bell -- four or
-- five statuses stamped on before anybody has taken a turn -- and every one of them hardens this
-- (data/traits/trait_kept_watch.lua). So a Sloth build walks into the fight already braced to its
-- ceiling, standing still, letting the oath do the moving. That is the posture the Pike was always
-- describing and never rewarded.
--
-- IT WORKS ALONE. Any party that debuffs at all feeds it -- a stun, a slow, a burn, anything you put on
-- a foe takes a little armour off this. Slower without the Pike, and in the currency a body that intends
-- to hold ground actually wants.
--
-- A WATCH THAT NEVER SOUNDED, which is the joke the body was named for and the reason this is what came
-- off it. It is the alarm nobody raised, and what it does now is make other people stand where they were
-- put.
--
-- No `class` and no `price`: no vendor stocks it, no shelf can replace it. There is one.
local Curve = require("models.curve")

return {
    name = "The Unblown Horn",
    description = "Hardens each time you bind a foe, up to a limit.",
    flavor = "Slung on the wall by the stair, where the watch could reach it without standing up.",
    sprite = "assets/items/unblown_horn.png",
    type = "utility",
    class = "creature",
    tags = { "relic" },
    noSteal = true,
    traits = { "trait_kept_watch" },
    bonus = { defense = Curve.ramp(2, 12) },
}
