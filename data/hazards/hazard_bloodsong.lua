-- Bloodsong: the red smoke a Crimson Standard trails. Every ALLY standing in it drinks back a share of
-- what it deals (data/status/status_bloodsong.lua); the enemy standing in it gets nothing at all.
--
-- Ground that WALKS -- laid around its bearer by Combat.layIncense every time they move, and lifted
-- from where they were. That is the censer family's mechanic (docs/weapons.md), borrowed wholesale
-- rather than reinvented, and it is the right one: a company-wide thirst should hold only while the
-- company actually fights in formation around whoever is carrying the colours. Spread out and the song
-- reaches nobody.
--
-- Sided through `ctx.isAlly`, which reads the `side` Combat.layIncense stamps onto every tile of the
-- cloud. A blessing that served whoever wandered into it would be a very strange banner.
--
-- Short duration because it does not need a long one: the smoke is re-laid under its bearer's feet on
-- every move and on every rebase, so what this number really governs is how long the song outlives the
-- standard-bearer being cut down -- about a turn, which is the right amount of grace.
return {
    name = "Bloodsong",
    description = "Red smoke: allies standing in it drink back a share of what they deal.",
    sprite = "assets/hazards/bloodsong.png",
    tags = { "banner" },
    duration = 6,
    disposition = "friendly", -- only the side that owns it is drawn to stand in it
    onEnter = function(ctx)
        if not ctx.isAlly(ctx.unit) then return end
        ctx.applyStatus(ctx.unit, "status_bloodsong")
    end,
}
