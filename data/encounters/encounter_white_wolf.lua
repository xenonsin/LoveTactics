-- THE WHITE WOLF: met in the wood, not commissioned.
--
-- `kind = "elite"` rather than "combat", which is the honest label and also the one that measures it
-- correctly: tests/skirmish_spec.lua holds ORDINARY fights to a short budget and judges elites
-- separately, and a body whose damage is a count of its own summons is not an ordinary stop. See
-- data/characters/character_white_wolf.lua for the fight.
--
-- SHE OPENS WITH THREE, AND THE OPENING ROSTER IS LOAD-BEARING TWICE OVER. Muster.encounter rates a
-- fight by summing its opening roster and nothing else -- there is no override field and no hook -- so a
-- body that makes more bodies is structurally under-rated by the one number that colours its marker and
-- gates Muster.WALK_OVER (encounter_the_unseeing.lua learned this the expensive way). And here the
-- roster is not merely a rating problem: her teeth strike once per wolf standing with her, so the wolves
-- she opens with ARE her opening damage. Three is what makes the first exchange read as a fight rather
-- than as a large animal walking toward you.
--
-- A FOREST FIGHT, by condition rather than by convention. She belongs to the wood the way the Winter
-- Hart belongs to the tundra (encounter_sloth_winter_hart.lua), which puts her on the Lust circle's
-- floors and on forest roads and nowhere else.
--
-- depth 5, a rung above the boar lord's 4. The pack is the lesson and she is the exam: a company that
-- meets her having never seen a wolf give ground, never been doubled by one, and never watched an alpha
-- howl has been asked a question nobody set up. encounter_wolf (weight 6, depth 1) and
-- encounter_wolf_pack (weight 5) are what teach it.
return {
    name = "The White Wolf",
    kind = "elite",
    weight = 2,
    -- NO DEPTH GATE: ITS CIRCLE IS ITS PLACEMENT. The condition below locks this to one ground, and a
    -- circle owns a fixed stratum -- so a depth on top of that is a second opinion about where it goes,
    -- and it disagrees the moment the shuffle deals that circle at another depth (Descent.sinOrder).
    -- It also gated Lust's own elites off Lust's own floors: converted from the retired calendar they
    -- asked for floors three and four, and Lust owns one and two.
    --
    -- Which of a circle's floors a thing bills on is Descent.SINS' `elites` for the standing threat, and
    -- `rung` for anything an author wants split across the approach and the seat.
    condition = function(ctx) return ctx.biome == "forest" end,
    composition = function(ctx)
        local list = { "character_white_wolf" }
        -- Three at the open, and a fourth deep -- kept deliberately shallow, because she makes more of
        -- them and every one she makes is another bite. The growth here is a floor on the fight, not
        -- its ceiling.
        for _ = 1, 3 + math.floor((ctx.depth or 1) / 5) do
            list[#list + 1] = "character_wolf_grunt"
        end
        return list
    end,
}
