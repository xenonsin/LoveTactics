-- THE UNSEEING: the boar lord, met on the road rather than commissioned.
--
-- `kind = "elite"` rather than "combat", which is the honest label and also the one that measures it
-- correctly: tests/skirmish_spec.lua holds ORDINARY road fights to a short budget and judges elites
-- separately, and a body that spends its turns making more bodies is not an ordinary stop. See
-- data/characters/character_the_unseeing.lua for the fight.
--
-- HE OPENS WITH THREE OF THE CLAN, and the third one is there for a reason worth writing down.
--
-- Muster.encounter rates a fight by summing its OPENING roster and nothing else -- there is no override
-- field and no hook -- so a body whose whole turn is making more bodies is structurally under-rated by
-- the one number that colours its marker and gates Muster.WALK_OVER. Opening on two, this fight rated
-- 900 against a pool median near 1000, which is not merely cosmetic: it dragged the median down far
-- enough that encounter_carrion_swarm stopped being filtered as a light fight on floor 5 and became
-- walk-over-able, which tests/descent_spec.lua caught. The third boar states the truth (lord plus three
-- rates ~1170) rather than leaving the rating to describe a fight nobody has.
--
-- The rating still cannot see the Call, and nothing here can make it: three more arrive during the
-- fight. This is the closest an authored composition can get to what the player actually stands in.
--
-- minDay 4 rather than 1, unlike the ordinary boar. The lanes are the lesson and the lord is the exam:
-- a company that meets him having never seen a Gore telegraph has been asked a question nobody set up.
-- encounter_boar (weight 6, minDay 1) and encounter_the_sounder (weight 4) are what teach it.
return {
    name = "The Unseeing",
    kind = "elite",
    weight = 2,
    minDay = 4,
    composition = function()
        return { "character_the_unseeing", "character_boar", "character_boar", "character_boar" }
    end,
}
