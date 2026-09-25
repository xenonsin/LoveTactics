-- Singing: a Siren's held song (data/items/ability/ability_siren_song.lua). While she holds it, every foe
-- who HEARS her -- within four tiles, or Wet anywhere on the board (Combat.hears) -- is filled with
-- Longing: once as the song begins, and again at the top of each of her turns, so a body the lancers
-- soak mid-fight hears her from across the mere on her next breath.
--
-- A Lorelei sings the Only Voice as well (her rock carries `onlyVoice`, data/traits/trait_only_voice.lua).
--
-- IT BREAKS WHEN SHE IS HIT. Any damage ends the song, and what already landed runs out its own clock --
-- which is the clean answer for a company with a bow, while a company made only of blades still has to
-- walk in to reach her, and walking in is what the song wants. A Held Note (the Lorelei's rock, and the
-- drop that hands it over) shrugs off the first blow each battle (Combat.holdsTheNote).
--
-- NOT a debuff: it is her own stance, and a Cure on the Siren's side must never end it.
local function sing(ctx)
    local Combat = require("models.combat")
    local Status = require("models.status")
    local Trait = require("models.trait")
    local singer = ctx.unit
    local combat = ctx.combat
    if not (combat and combat.units and singer.alive) then return end
    local level = (singer.char and singer.char.level) or 1
    local bite = 3 + math.floor(math.max(0, level - 1) / 6)
    local both = Trait.flag(singer, "onlyVoice")
    for _, u in ipairs(combat.units) do
        if Combat.hears(singer, u) then
            Status.apply(combat, u, "status_longing", { applier = singer, magnitude = bite })
            if both and u.alive then
                Status.apply(combat, u, "status_the_only_voice", { applier = singer })
            end
        end
    end
end

return {
    name = "Singing",
    abbr = "Sng",
    description = "Singing: everyone who hears her is filled with Longing each turn. Breaks when she is hit.",
    color = { 0.720, 0.560, 0.820 }, -- badge tint (a light song violet)
    duration = 30, -- a safety cap of six turns; the song really ends on a blow, or with her
    debuff = false,
    onApply = sing,
    onTurnStart = sing,
    onDamaged = function(ctx)
        local Combat = require("models.combat")
        if Combat.holdsTheNote(ctx.combat, ctx.unit) then return end
        ctx.log("status", string.format("%s's song breaks.", (ctx.unit.char and ctx.unit.char.name) or "Unit"))
        ctx.expire()
    end,
}
