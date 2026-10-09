-- Archon: the court under the Hollow Crown, and the bottom floor's people. Reviewed 2026-10-06..09 ("The Crown's
-- Bestiary", rounds 1-3).
--
-- A RACE OF THEIR OWN, NOT A KIND OF DEMON. They were pitched as the demon race and then as "Arch Demons", and
-- the author split them off by name because `demon` already means every demonic thing in the game (the
-- prologue's raiders, the succubi, the imps). So nothing carries across: no fire on their blows and no holy
-- line. An Archon is mitigated by what it wears, like any other people. All of them are humanoid -- the
-- author's note on every body: rank shows in the face and the robe, never in a beast's shape.
--
-- WHAT THEY ARE is rulers of the bottom of the world, the way the Gnostic archons keep souls from rising: a
-- ranked court that does not let its own dead go either. SPIRIT BODY (data/traits/trait_spirit_body.lua,
-- models/spirit.lua) is the race: an Archon that falls throws its spirit clear as a wisp, and the wisp walks
-- back to the body to stand it up again. The author's own reading of the rule (round 1): "the wisp and the
-- body is separated, and the wisp goes back to the body so you have to stop it".
--
-- THE STAT LINE is a little magic defense, under the tier-1 budget the Lesser Archon caps it at. They are a
-- court of casters and spell-cut blades, and they know what a spell is.
--
-- SPIRIT BODY IS GRANTED rather than authored into every grid (utility_archon_spirit): an organ, not kit.
return {
    name = "Archon",
    description = "The court under the Crown. A fallen Archon's spirit walks back to its body to raise it.",
    kind = "humanoid",
    bonus = {
        magicDefense = 2, -- a court of casters knows what a spell is
    },
    grants = { "utility_archon_spirit" },
}
