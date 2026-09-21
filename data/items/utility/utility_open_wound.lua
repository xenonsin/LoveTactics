-- THE OPEN WOUND: nothing on the wearer ever wears off.
--
-- WAS A RUN RELIC (`relic_open_wound`, rare tier) until the relic shelf was parked on 2026-09-17; see
-- models/relic.lua's park note for the whole move. The effect is unchanged in kind and RESCOPED: a
-- relic was held by the run and felt by the whole company, and this is worn by one body and felt by
-- that body.
--
-- READ BY models/status.lua's tick, which is the only consumer: a status on this body never counts
-- down. Cuts both ways by design and the description says so -- a Blessing that holds forever and a
-- Burn that does too are the same rule.
return {
    name = "The Open Wound",
    description = "Statuses on you never expire, including Burn, Poison and curses.",
    flavor = "Bound, unbound and bound again, and the linen comes away looking exactly as it went on.",
    sprite = "assets/items/open_wound.png",
    type = "utility",
    tags = { "charm" },
    -- SHELVED WITH THE DISCIPLINE ITS EFFECT FEEDS, not with the root class: the shelf whose damage IS the status, and which gains most from one that never ends.
    -- `class` is the vendor shelf and never an equip gate -- anyone may carry this.
    class = "poisoner",
    -- GRADED BY JUDGEMENT rather than by dry run (Grade.of's authored hatch), in turns per
    -- fight: every buff the party lands on this body is permanent, and so is every burn.
    -- The instrument reads net stat swing and replayed damage; this item's worth is in neither,
    -- so left underived it files at ~0 -- see models/grade.lua on a passive being BLIND.
    grade = 2.40,
    unlockLevel = 14,
    rules = { statusesPersist = 1 },
}
