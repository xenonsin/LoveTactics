-- WHERE ENVY LIVES: the Pale Crone and her Wasting Ones, approach traffic on the Ribstone Waste ("Envy's Bestiary",
-- round 4). Both halves of the sin at once: getting hurt feeds the pack, and healing calls the Crone, so the company
-- heals out of her sight or baits her into its blades.
--
-- THE OBJECTIVE (the objective pass, 2026-10-21): a Stray Delver lies hurt, and the company has to keep them alive.
-- Healing them is the obvious answer and every heal calls the Crone, so the fight is where and when to mend.
local Band = require("models.band")

return {
    name = "Where Envy Lives",
    kind = "combat",
    weight = 5,
    condition = function(ctx) return ctx.biome == "desert" end,
    rung = 1,
    composition = function(ctx)
        return Band.fill({ "character_pale_crone" }, ctx, "character_wasting_one", { base = 2, min = 2, max = 3 })
    end,
    allies = { "character_stray_delver" },
    objective = {
        type = "defend", protect = "character_stray_delver", enemy = "the Wasting Ones",
        -- Wounded, not dying: at a quarter the first heal the company gave them was the Crone's strike that
        -- killed them, every time it was measured. At sixty percent a heal in her sight costs the delver
        -- most of what it gave rather than everything.
        chargeOpens = { health = 0.6 },
        -- One more of the pack, drawn to the blood -- one, because two measured as a lost fight: the pack grows
        -- on every wound the company takes, and a second arrival fed it faster than four could cut it down.
        waves = {
            { at = 15, from = "surround", composition = { "character_wasting_one" } },
        },
    },
}
