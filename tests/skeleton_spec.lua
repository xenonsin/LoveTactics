-- MARROWLIGHT, the skeleton aspect (data/items/utility/utility_marrowlight.lua). An ITEM, so it goes on
-- any body in the game without being a class, a blueprint or a transform -- and the two rules it carries
-- are the two halves of what this game means by undead:
--
--   * BONE-KNIT, a refusal to fall that is bounded by a POOL rather than by a charge. It fires as often
--     as the bearer can pay forty mana for it, and it returns the WHOLE bar -- which together are the
--     claim that separates it from Second Wind, and the one the engine change was for
--     (models/trait.lua's Trait.trySurvive). The two halves close a loop: a grave-cold body cannot be
--     healed by anything, so dying is the only way it ever gets health back;
--   * GRAVE-COLD, already in the game and re-used rather than restated: every heal aimed at the body
--     wounds it instead.
--
-- Plus the regression that the engine change is really about: a refusal with NO cost still latches
-- exactly once a battle, so Second Wind, the Empty Chair and every general's own rule are untouched.
--
-- Pure model logic, so it runs headless.

local Character = require("models.character")
local Combat = require("models.combat")
local Item = require("models.item")
local Trait = require("models.trait")
local Fixture = require("tests.support.fixture")

-- A knight carrying the charm, isolated to "mechanics" so its blueprint's own innates cannot answer a
-- blow this file is asking about, and handed a pool by hand: `mana` is the entire budget under test, so
-- every case states the one it wants rather than inheriting whatever the sheet happens to carry.
local function skeleton(mana, health)
    local c = Combat.new(Fixture.new(6, 6),
        { Fixture.unit("character_knight", 2, 2, { isolate = "mechanics",
            items = { "utility_marrowlight" },
            stats = { mana = mana, health = health or 60 } }) },
        { Fixture.unit("character_bandit", 5, 5, { isolate = "mechanics" }) })
    return c, c.units[1]
end

local function kill(c, u) Combat.dealFlatDamage(c, u, 9999, {}, "test") end

return {
    {
        name = "the charm is an aspect, not a body: it goes on an ordinary knight and leaves it a knight",
        fn = function()
            local char = Character.instantiate("character_knight")
            Character.addItem(char, Item.instantiate("utility_marrowlight"))
            assert(char.name == Character.instantiate("character_knight").name,
                "the bearer keeps its own name -- this is a charm, not a transform or a raised zombie")
            assert(char.class == Character.instantiate("character_knight").class,
                "...and its own class: the aspect is not a class")
            local unit = { char = char }
            Trait.attach(unit)
            local seen = {}
            for _, t in ipairs(unit.traits) do seen[t.id] = true end
            assert(seen.trait_bone_knit, "the grid delivers Bone-Knit")
            assert(seen.trait_grave_cold, "...and Grave-Cold, the game's existing undead rule")
        end,
    },
    {
        name = "a lethal blow is refused for mana: the body stands, the pool is forty lighter",
        fn = function()
            local c, sk = skeleton(120)
            local before = sk.char.stats.mana.current
            kill(c, sk)
            assert(sk.alive, "the blow that would have felled it did not")
            assert(not sk.incapacitated and not sk.corpse, "and it left no body on the floor")
            assert(sk.char.stats.mana.current == before - 40,
                "the refusal was billed once, at the charm's toll: "
                    .. tostring(before - sk.char.stats.mana.current))
        end,
    },
    {
        name = "THE OTHER HALF: it rises WHOLE, which is the only healing a grave-cold body has",
        fn = function()
            local c, sk = skeleton(120, 60)
            -- Chipped first, so the assertion is about the rise restoring a bar rather than about a
            -- body that happened to be full when it was killed.
            sk.char.stats.health.current = 7
            kill(c, sk)
            local full = Combat.unreservedMax(sk.char, "health")
            assert(sk.char.stats.health.current == full,
                "the whole bar, not Second Wind's half: " .. tostring(sk.char.stats.health.current)
                    .. " of " .. tostring(full))
        end,
    },
    {
        name = "THE CLAIM: it refuses again, and again, for as long as the pool covers it",
        fn = function()
            -- 120 mana flat -- `current` is what pays, and the charm's own +5 ceiling does not fill it.
            -- Three rises at forty, and the fourth death is a death.
            local c, sk = skeleton(120)
            for i = 1, 3 do
                kill(c, sk)
                assert(sk.alive, "refusal " .. i .. " stood it back up (unlike a once-per-battle charge)")
            end
            assert(sk.char.stats.mana.current == 0, "the pool is spent exactly: "
                .. tostring(sk.char.stats.mana.current))
            kill(c, sk)
            assert(not sk.alive, "with nothing left to pay with, the next blow fells it")
        end,
    },
    {
        name = "an empty pool buys nothing: the first blow fells a skeleton that cannot pay",
        fn = function()
            local c, sk = skeleton(39) -- one short of the toll
            kill(c, sk)
            assert(not sk.alive, "a refusal it cannot afford is not a refusal it gets for free")
            assert(sk.char.stats.mana.current == 39,
                "and declining cost it nothing -- canPay only asks: " .. tostring(sk.char.stats.mana.current))
        end,
    },
    {
        name = "mana restored mid-fight buys more deaths: the pool is the whole limit",
        fn = function()
            local c, sk = skeleton(40)
            kill(c, sk)
            assert(sk.alive and sk.char.stats.mana.current == 0, "the one rise the pool covered")
            Combat.restoreResource(sk.char, "mana", 40)
            kill(c, sk)
            assert(sk.alive, "a topped-up pool is a topped-up supply of deaths refused")
        end,
    },
    {
        name = "undead: a heal aimed at the skeleton wounds it for the same amount",
        fn = function()
            local c, sk = skeleton(120, 60)
            sk.char.stats.health.current = 40
            Combat.applyHeal(c, sk, 12)
            assert(sk.char.stats.health.current == 28,
                "Grave-Cold inverts it, so the healer is the one finishing it off: "
                    .. tostring(sk.char.stats.health.current))
        end,
    },
    {
        -- THE PICTURE, which is half of what "turns you into a skeleton" means and the half a rules
        -- test would otherwise never look at. `wearerSkin` names a TREATMENT, not a file, so the
        -- assertion that matters is that two different bodies resolve to two different pictures --
        -- each its own silhouette in bone -- rather than to one shared skeleton token.
        name = "the aspect redraws the BEARER: each body resolves to its own bone variant",
        fn = function()
            local Sprite = require("models.sprite")
            local plain = Character.instantiate("character_knight")
            local boned = Character.instantiate("character_knight")
            Character.addItem(boned, Item.instantiate("utility_marrowlight"))

            -- Skipped rather than failed where assets/ has not been built: the variants are composed
            -- build output (`. art-build`), gitignored, and a fresh clone legitimately has none. The
            -- FALLBACK is asserted unconditionally below, because that is the behaviour that must hold
            -- on such a clone.
            if Sprite.exists("assets/chars/knight_bone.png") then
                assert(Character.spriteOf(boned) ~= Character.spriteOf(plain),
                    "a body carrying the aspect is not drawn as the body without it")
                assert(Character.spriteOf(boned) == Sprite.load("assets/chars/knight_bone.png"),
                    "and what it is drawn as is its OWN token in bone")

                local mage = Character.instantiate("character_mage")
                Character.addItem(mage, Item.instantiate("utility_marrowlight"))
                if Sprite.exists("assets/chars/mage_bone.png") then
                    assert(Character.spriteOf(mage) ~= Character.spriteOf(boned),
                        "two bodies wearing one aspect are still two bodies -- not one skeleton token")
                end
            end

            assert(Character.spriteOf(plain) == plain.sprite,
                "a body with no aspect is drawn exactly as it always was")
            -- The missing-variant fallback, forced by pointing the body at art that cannot exist. A
            -- half-built assets/ must cost the skeleton its bone picture and nothing else -- never the
            -- bare letter disc a path string would land on.
            local orphan = Character.instantiate("character_knight")
            Character.addItem(orphan, Item.instantiate("utility_marrowlight"))
            orphan.spritePath = "assets/chars/no_such_body.png"
            assert(Character.spriteOf(orphan) == orphan.sprite,
                "with no variant on disk the bearer keeps its own sprite")
        end,
    },
    {
        -- THE BONE ORCHARD'S OWN KIT, and the contract that keeps it on the far side of every shelf.
        -- A creature carries natural weapons only -- unpriced, noSteal, outside the earned classes
        -- (docs/bestiary.md, and tests/bestiary_spec.lua enforces the last of those three on the
        -- BODY). Asserted here on the ITEMS, because the failure it guards against is the one that
        -- looks fine on a blueprint: a creature weapon that quietly acquires a price is stock the
        -- Undercroft will buy back, and one that acquires an earned class is a discipline item a
        -- skeleton is not allowed to be carrying.
        name = "the orchard's dead ARE the living cast: each one extends a blueprint the player knows",
        fn = function()
            -- THE CONTRACT THIS FILE EXISTS TO PIN. A skeleton in this game is an existing body with
            -- something done to it, never an invented creature -- so every one of these must still be
            -- recognisably the blueprint it came from (the character_saber_bout idiom). What is asserted
            -- is the IDENTITY carried over, not the fields that changed.
            for deadId, baseId in pairs({
                character_skeleton_knight = "character_knight",
                character_skeleton_archer = "character_archer",
                character_barrow_lord     = "character_knight",
            }) do
                local dead = Character.instantiate(deadId)
                local base = Character.instantiate(baseId)
                assert(dead.spritePath == base.spritePath, deadId
                    .. " is drawn from " .. baseId .. "'s own token -- the bone skin does the rest")
                -- ...and DROPS its shelf. A class is a vendor shelf and a growth declaration, and a
                -- corpse has neither (docs/bestiary.md); the living blueprint's is inherited by the copy
                -- and must be cleared, which is also the line that makes it a corpse rather than a
                -- knight with a condition.
                assert(dead.class == nil, deadId .. " declares no shelf -- a " .. tostring(dead.kind)
                    .. " has none, and it inherited " .. tostring(base.class) .. " from " .. baseId)
                assert(dead.kind == "undead", deadId .. " is dead")
                -- The lattice: edges and points slide through a frame, and the frame pays for both.
                assert(dead.resist.slash > 0 and dead.resist.pierce > 0 and dead.resist.impact < 0,
                    deadId .. " slips edges and points and comes apart under impact")
                assert(dead.resist.slash + dead.resist.pierce + dead.resist.impact == 0,
                    deadId .. "'s three lines are a redistribution, summing to zero "
                        .. "(Balance.INNATE_PHYSICAL)")
            end
            -- ...and the kit that makes a body a skeleton is on the far side of every shelf: a creature
            -- carries natural gear only -- unpriced, noSteal, outside the earned classes
            -- (docs/bestiary.md). The failure this guards is the one that looks fine on a blueprint: an
            -- aspect item that quietly acquires a price is stock the Undercroft will buy back.
            for _, id in ipairs({ "utility_bare_bones", "utility_barrow_binding", "utility_grave_cold" }) do
                local def = Item.defs[id]
                assert(def, id .. " exists")
                assert(def.class == "creature", id .. " is creature kit, not shelf stock")
                assert(def.price == nil, id .. " carries no price -- nothing deals a skeleton's bones")
                assert(def.noSteal, id .. " cannot be lifted off the body")
            end
        end,
    },
    {
        -- THE TEACHING BODY. The Barrow Knight wears the player's own aspect through a creature-side
        -- copy, so the thing the player watches it do is the thing the charm will do for them -- and
        -- its pool is authored to cover an exact number of deaths, which is the fact the fight is
        -- asking them to count.
        name = "the Barrow Lord rises on the same rule, at its own toll, exactly twice",
        fn = function()
            local c = Combat.new(Fixture.new(8, 8),
                { Fixture.unit("character_knight", 1, 1, { isolate = "mechanics" }) },
                { Fixture.unit("character_barrow_lord", 5, 5, { isolate = "none" }) })
            local lord = c.units[2]
            local toll = Item.defs["utility_barrow_binding"].traitParams.cost.amount
            assert(lord.char.stats.mana.max == toll * 2,
                "its pool is exactly two deaths deep, with nothing spare to miscount: "
                    .. tostring(lord.char.stats.mana.max) .. " at a toll of " .. tostring(toll))

            local full = Combat.unreservedMax(lord.char, "health")
            for i = 1, 2 do
                lord.char.stats.health.current = 3 -- chipped, so the rise has a bar to restore
                kill(c, lord)
                assert(lord.alive, "rise " .. i .. " stood the Barrow Knight back up")
                assert(lord.char.stats.health.current == full,
                    "...and stood it up WHOLE, which is what makes the red bar the wrong bar to watch")
            end
            assert(lord.char.stats.mana.current == 0, "two rises empty it exactly")
            kill(c, lord)
            assert(not lord.alive, "and the third death is the one that takes")
            -- ...and it was a knight the whole time, drawn in bone under a crown. The crown is not
            -- decoration: this body's entire fight is that the two beside it stay down and it does not,
            -- so a player has to be able to pick it out of a rank of identical corpses.
            local Sprite = require("models.sprite")
            if Sprite.exists("assets/chars/knight_crowned.png") then
                assert(Character.spriteOf(lord.char) == Sprite.load("assets/chars/knight_crowned.png"),
                    "the Lord is the knight's own token, in bone, crowned")
                assert(Character.spriteOf(lord.char)
                        ~= Character.spriteOf(Character.instantiate("character_skeleton_knight")),
                    "...and emphatically not the same picture as the rank beside him")
            end
        end,
    },
    {
        -- THE KING'S WHOLE FIGHT, and the one claim that is worth a spec: his mana is not a resource,
        -- it is a HEADCOUNT. Court of Bone pins it to thirty per standing subject and Bone-Knit spends
        -- thirty to rise, so "how many are left" and "how many deaths he has" are the same number in
        -- the same bar. Everything the encounter does rests on those two figures agreeing.
        name = "THE KING: his mana is his court, and clearing the room empties it",
        fn = function()
            local crown = Item.defs["utility_the_barrow_crown"]
            assert(crown.traitParams.per == crown.traitParams.cost.amount,
                "one subject must be exactly one death refused, or the bar stops being countable: "
                    .. tostring(crown.traitParams.per) .. " vs " .. tostring(crown.traitParams.cost.amount))
            local per = crown.traitParams.per

            local c = Combat.new(Fixture.new(10, 10),
                { Fixture.unit("character_knight", 1, 1, { isolate = "mechanics" }) },
                { Fixture.unit("character_the_skeleton_king", 8, 8, { isolate = "none" }),
                  Fixture.unit("character_skeleton_knight", 7, 8, { isolate = "none" }),
                  Fixture.unit("character_skeleton_knight", 8, 7, { isolate = "none" }),
                  Fixture.unit("character_skeleton_archer", 7, 7, { isolate = "none" }) })
            Combat.openBattle(c)
            local king = c.units[2]

            assert(king.char.stats.mana.current == per * 3,
                "three subjects standing is three deaths on the bar: "
                    .. tostring(king.char.stats.mana.current) .. ", wanted " .. tostring(per * 3))

            -- Clear the court. Each death is the beat Court of Bone settles on, so the bar falls in
            -- front of the player rather than being recomputed somewhere they cannot see.
            for i, u in ipairs({ c.units[3], c.units[4], c.units[5] }) do
                kill(c, u)
                assert(king.char.stats.mana.current == per * (3 - i),
                    "clearing subject " .. i .. " took a death off the King: "
                        .. tostring(king.char.stats.mana.current))
            end

            -- ...and now the red bar means what it usually means.
            assert(king.char.stats.mana.current == 0, "an empty room is an empty pool")
            kill(c, king)
            assert(not king.alive, "with the court gone, the King dies like anything else")
        end,
    },
    {
        -- The other half of the same rule, asserted separately because it is the half a player meets
        -- FIRST and the half that would make the fight unfair if it were wrong: with the court intact,
        -- killing the King does nothing at all.
        name = "THE KING: killed with his court standing, he gets back up whole",
        fn = function()
            local c = Combat.new(Fixture.new(10, 10),
                { Fixture.unit("character_knight", 1, 1, { isolate = "mechanics" }) },
                { Fixture.unit("character_the_skeleton_king", 8, 8, { isolate = "none" }),
                  Fixture.unit("character_skeleton_knight", 7, 8, { isolate = "none" }),
                  Fixture.unit("character_skeleton_knight", 8, 7, { isolate = "none" }) })
            Combat.openBattle(c)
            local king = c.units[2]
            local full = Combat.unreservedMax(king.char, "health")

            king.char.stats.health.current = 4
            kill(c, king)
            assert(king.alive, "the court paid for that one")
            assert(king.char.stats.health.current == full,
                "and it bought the WHOLE bar back, which is why chipping him is the wrong plan: "
                    .. tostring(king.char.stats.health.current) .. " of " .. tostring(full))
        end,
    },
    {
        -- The court is HIS OWN DEAD, not whoever happens to be standing next to him. A boss whose rule
        -- quietly read "any ally" is a boss a summoner's wolf could prop up, and the fight would stop
        -- being about the thing it is about.
        name = "THE KING: a living ally is not a subject",
        fn = function()
            local c = Combat.new(Fixture.new(10, 10),
                { Fixture.unit("character_knight", 1, 1, { isolate = "mechanics" }) },
                { Fixture.unit("character_the_skeleton_king", 8, 8, { isolate = "none" }),
                  Fixture.unit("character_bandit", 7, 8, { isolate = "mechanics" }) })
            Combat.openBattle(c)
            local king = c.units[2]
            assert(king.char.stats.mana.current == 0,
                "a bandit fighting beside the King is not a body he can spend: "
                    .. tostring(king.char.stats.mana.current))
            kill(c, king)
            assert(not king.alive, "so the first real blow takes him")
        end,
    },
    {
        -- THE CALL IS THE FIGHT'S CLOCK, so the things worth pinning about it are the ones that keep it
        -- fair: it is an ABILITY (telegraphed, answerable) rather than a hidden hook, it refills the
        -- court with the same bodies the player has been clearing, and it does not hold its summons --
        -- an ability that claimed them would gag the King for as long as one subject stood, which is
        -- the exact opposite of the pressure it exists to apply.
        name = "THE KING: Call the Court refills the bar it spends, and is not held by what it calls",
        fn = function()
            local call = Item.defs["ability_call_the_court"]
            assert(call.activeAbility, "the court arrives as a cast, not as a hook -- the player sees it")
            assert(call.activeAbility.cooldown and call.activeAbility.cooldown > 0,
                "and the cooldown is the window a company has to put him down in")
            assert(call.class == "creature" and call.noSteal and call.price == nil,
                "a king's prerogative is on nobody's shelf")

            local reach = Item.defs["weapon_the_kings_reach"]
            assert(reach.activeAbility.range == 2,
                "the reach holds the party a tile off while they try to clear around him")
            assert(reach.class == "creature" and reach.noSteal and reach.price == nil,
                "...and it is creature kit like the rest of him")

            local c = Combat.new(Fixture.new(10, 10),
                { Fixture.unit("character_knight", 1, 1, { isolate = "mechanics" }) },
                { Fixture.unit("character_the_skeleton_king", 5, 5, { isolate = "none" }) })
            Combat.openBattle(c)
            local king = c.units[2]
            assert(king.char.stats.mana.current == 0, "alone, the King has nothing to spend")

            local before = #c.units
            -- Aimed at an adjacent tile: the cast is `target = "tile"` at range 1, and the effect places
            -- the court off the CASTER's own position rather than off the aim, so where it is pointed
            -- only has to be legal.
            assert(Fixture.strike(c, king, { x = 5, y = 6 }, "ability_call_the_court"),
                "the King calls the court onto his own flanks")
            assert(#c.units > before, "...and bodies arrived")
            -- The point of the whole rule: what he called is what pays for him.
            assert(king.char.stats.mana.current > 0,
                "a standing court IS his pool -- the call refilled the bar: "
                    .. tostring(king.char.stats.mana.current))
        end,
    },
    {
        name = "REGRESSION: an unpriced refusal still latches exactly once a battle",
        fn = function()
            local c = Combat.new(Fixture.new(6, 6),
                { Fixture.unit("character_knight", 2, 2, { isolate = "mechanics",
                    items = { "utility_second_wind" }, stats = { health = 60 } }) },
                { Fixture.unit("character_bandit", 5, 5, { isolate = "mechanics" }) })
            local hero = c.units[1]
            kill(c, hero)
            assert(hero.alive, "Second Wind catches the first one, as it always has")
            kill(c, hero)
            assert(not hero.alive, "and never the second: no cost means the charge still bounds it")
        end,
    },
}
