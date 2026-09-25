-- THE LORELEI'S ROCK: the Siren's elite, on Lust's approach (floor three) beside the Drowned Stair.
--
-- She never leaves her rock, and her song holds through the first blow; two Sirens sing beside her, so
-- a body that hears one hears three; and a Fen Lancer soaks the company so all three reach it from
-- anywhere on the board. What makes it an ELITE rather than a louder Reed Choir is the Only Voice: every
-- body that hears her is cut off from its own side, so the healer a company brought for this fight is
-- the thing she takes first. Shoalkin pad it as the fight deepens, standing in the water she wants you to
-- walk toward.
--
-- A spare rather than a billing (Descent.SINS' Lust entry): the Drowned Stair is what floor three is
-- about, and this is the worst thing standing on it. Nobody here roots or shoves.
local Band = require("models.band")

return {
    name = "The Lorelei's Rock",
    kind = "elite",
    weight = 2,
    condition = function(ctx) return ctx.biome == "swamp" end,
    rung = 1,
    composition = function(ctx)
        local list = { "character_lorelei", "character_siren", "character_siren", "character_fen_lancer" }
        return Band.fill(list, ctx, "character_shoalkin", { base = 0, per = 6, max = 2 })
    end,
}
