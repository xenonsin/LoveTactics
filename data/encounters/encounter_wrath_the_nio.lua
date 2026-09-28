-- THE NIO (Wrath, floor 7, elite): the temple gate's pair of guardians, one mouth open and one closed
-- (character_asura_agyo, character_asura_ungyo). The Open Mouth spends; the Closed Mouth only fills. When one
-- falls the other takes all of its chi (trait_the_nio), and bursts at once if that fills it -- so the kill order
-- is the puzzle: kill the Closed Mouth first and the Open Mouth spends what it inherits; kill the Open Mouth
-- first and the Closed Mouth bursts with both gauges. Approved on review 2026-09-27/28.
return {
    name = "The Nio",
    kind = "elite",
    weight = 1,
    condition = function(ctx) return ctx.biome == "volcanic" end,
    rung = 1,
    composition = function()
        return { "character_asura_agyo", "character_asura_ungyo" }
    end,
}
