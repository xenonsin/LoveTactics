-- Tests for the visual-effects layer's pure decisions -- the parts that are NOT a matter of taste and
-- would break silently if they drifted. No window and no GPU: every shader family exposes its
-- vocabulary as plain data (a string and a table) exactly so this can run headless, the same contract
-- shaders/field.lua set and tests/field_fx_spec.lua already leans on.
--
--   1. THE SHARED VOCABULARY. A fire weapon, a fire spell and a fire hazard must all reach "fire" off
--      one reading of their tags, or the telegraph, the bolt, the impact and the ground stop agreeing.
--   2. NAME <-> ID PARITY. Each family generates its GLSL #defines and its Lua id table from ONE ORDER
--      list; every styled/mapped name must have a shader id and vice versa, so the two cannot drift.
--   3. RESOLUTION TOTALITY. Every motif a burst maps to must be a real burst shape; every field/burst
--      pattern a motif names must exist. A typo here draws nothing, in silence.
--   4. SCREEN-FX DECAY. Shake/punch/flash run down to nothing; a freeze scales time then releases; the
--      reduced-effects setting silences motion but not meaning.

local Motif = require("ui.motif")
local BurstFx = require("ui.burst_fx")
local BurstShader = require("shaders.burst")
local FieldFx = require("ui.field_fx")
local FieldShader = require("shaders.field")
local SpriteShader = require("shaders.sprite")
local ScreenFx = require("ui.screen_fx")
local Settings = require("models.settings")

return {
    -- ---------------------------------------------------------------------------
    -- 1. The shared vocabulary (ui/motif.lua)
    -- ---------------------------------------------------------------------------
    {
        name = "a weapon's SHAPE leads its element, a spell's element leads outright",
        fn = function()
            -- The Apothecary's Lancet: a stab that leaves poison, not a puff of gas. Shape wins.
            assert(Motif.of({ "dagger", "pierce", "physical", "poison", "melee" }) == "pierce",
                "a poisoned blade should read as the stab it is")
            -- A Fireball's ability tags lead with the element: it blooms.
            assert(Motif.of({ "fire", "arcane" }) == "fire", "a fire spell reads as fire")
            -- The Emberwand: family and routing first, then the element behind them.
            assert(Motif.of({ "wand", "magical", "fire", "ranged" }) == "fire", "a fire wand reads as fire")
        end,
    },
    {
        name = "routing tags carry no picture, and a bite is a slash",
        fn = function()
            assert(Motif.of({ "physical", "melee" }) == nil, "a routing-only tag list resolves nothing")
            assert(Motif.of({ "magical", "ranged" }) == nil, "magical/ranged are not motifs")
            assert(Motif.of({ "natural", "bite", "physical" }) == "slash", "teeth cut, so a bite is a slash")
            -- The archetype tag is never a motif: dagger says which shelf, not what it looks like.
            assert(Motif.of({ "dagger", "melee" }) == nil, "a weapon family is not a motif")
        end,
    },
    {
        name = "an explicit motif overrides the tags",
        fn = function()
            assert(Motif.of({ "fire" }, "ice") == "ice", "an explicit motif wins")
            assert(Motif.of({ "fire" }, "not_a_motif") == "fire", "a nonsense override falls back to tags")
        end,
    },
    {
        name = "tagTable drops the motifs a family has no picture for",
        fn = function()
            -- The field family has no ground for a bare slash; tagTable must not invent one.
            local t = Motif.tagTable({ fire = "flame" })
            assert(t.fire == "flame", "a mapped motif carries through by every tag that means it")
            assert(t.slash == nil, "an unmapped motif is dropped, not defaulted")
        end,
    },

    -- ---------------------------------------------------------------------------
    -- 2. Name <-> id parity, for every family
    -- ---------------------------------------------------------------------------
    {
        name = "the burst family's Lua names and GLSL ids cannot drift apart",
        fn = function()
            for name in pairs(BurstFx.STYLE) do
                assert(BurstShader.PATTERNS[name], "styled burst with no shader id: " .. name)
            end
            for _, name in ipairs(BurstShader.ORDER) do
                assert(BurstFx.STYLE[name], "shader burst with no style: " .. name)
            end
        end,
    },
    {
        name = "the sprite family's modes each have a shader id",
        fn = function()
            for _, name in ipairs(SpriteShader.ORDER) do
                assert(SpriteShader.MODES[name] ~= nil, "sprite mode with no id: " .. name)
            end
        end,
    },

    -- ---------------------------------------------------------------------------
    -- 3. Resolution totality
    -- ---------------------------------------------------------------------------
    {
        name = "every motif a burst maps to is a real burst shape",
        fn = function()
            for motif, pattern in pairs(BurstFx.MOTIF_PATTERN) do
                assert(Motif.SET[motif], "burst maps an unknown motif: " .. motif)
                assert(BurstFx.STYLE[pattern], motif .. " maps to unstyled burst " .. tostring(pattern))
                assert(BurstShader.PATTERNS[pattern], motif .. " maps to burst with no shader id")
            end
        end,
    },
    {
        name = "every motif a field maps to is a real field pattern",
        fn = function()
            for motif, pattern in pairs(FieldFx.MOTIF_PATTERN) do
                assert(Motif.SET[motif], "field maps an unknown motif: " .. motif)
                assert(FieldFx.STYLE[pattern], motif .. " maps to unstyled field " .. tostring(pattern))
                assert(FieldShader.PATTERNS[pattern], motif .. " maps to field with no shader id")
            end
        end,
    },
    {
        name = "a blow always draws SOMETHING -- an unknown motif still bursts",
        fn = function()
            assert(BurstFx.patternFor(nil) == BurstFx.DEFAULT_STRIKE, "a tagless blow draws the default")
            assert(BurstFx.patternFor({ "physical" }) == BurstFx.DEFAULT_STRIKE, "an elementless blow too")
            assert(BurstFx.STYLE[BurstFx.DEFAULT_STRIKE], "the default strike must be a real shape")
            assert(BurstFx.patternFor({ "fire" }) == "bloom", "fire blooms")
            assert(BurstFx.patternFor({ "fire" }, "motes") == "motes", "an explicit pattern wins")
        end,
    },
    {
        name = "a burst's colour follows its motif, so one shape carries many elements",
        fn = function()
            -- poison and acid are the SAME shape (spray) told apart only by colour.
            assert(BurstFx.patternFor({ "poison" }) == "spray" and BurstFx.patternFor({ "acid" }) == "spray",
                "poison and acid share the spray shape")
            local pc = BurstFx.colorFor({ "poison" }, "spray")
            local ac = BurstFx.colorFor({ "acid" }, "spray")
            assert(pc[1] ~= ac[1] or pc[2] ~= ac[2] or pc[3] ~= ac[3],
                "two elements on one shape must not share a colour")
        end,
    },
    {
        name = "flight time grows with distance, clamped at both ends",
        fn = function()
            local near = BurstFx.flightTime(1, 1, 2, 1) -- one tile
            local far = BurstFx.flightTime(1, 1, 8, 1)  -- seven tiles
            assert(near >= BurstFx.FLIGHT_MIN - 1e-9, "a point-blank shot still takes the floor time")
            assert(far <= BurstFx.FLIGHT_MAX + 1e-9, "a full-board shot is capped so it never dawdles")
            assert(far >= near, "a longer shot must not arrive sooner than a shorter one")
        end,
    },

    -- ---------------------------------------------------------------------------
    -- 4. Screen-fx decay (ui/screen_fx.lua)
    -- ---------------------------------------------------------------------------
    {
        name = "shake, punch and flash all decay to nothing",
        fn = function()
            Settings.set("reduced_effects", false)
            ScreenFx.reset()
            ScreenFx.shake(8, 0.3)
            ScreenFx.punch(0.7)
            ScreenFx.flash({ 1, 1, 1 }, 0.25)
            local sx = select(1, ScreenFx.shakeOffset())
            assert(math.abs(sx) > 0 or ScreenFx.post().flash > 0, "an effect that was raised must register")
            for _ = 1, 120 do ScreenFx.update(1 / 60) end -- two seconds: everything must have run out
            local ox, oy = ScreenFx.shakeOffset()
            local post = ScreenFx.post()
            assert(ox == 0 and oy == 0, "shake never settled")
            assert(post.punch == 0 and post.flash == 0, "punch/flash never settled")
            assert(not post.active, "the post pass should be idle once every term has decayed")
            ScreenFx.reset()
        end,
    },
    {
        name = "a freeze scales gameplay time to zero, then releases",
        fn = function()
            Settings.set("reduced_effects", false)
            ScreenFx.reset()
            assert(ScreenFx.timeScale() == 1, "time runs at full speed at rest")
            ScreenFx.freeze(0.08)
            assert(ScreenFx.timeScale() == 0, "a freeze holds gameplay time at zero")
            for _ = 1, 20 do ScreenFx.update(1 / 60) end -- 0.33s > 0.08
            assert(ScreenFx.timeScale() == 1, "the freeze never released")
            ScreenFx.reset()
        end,
    },
    {
        name = "reduced effects silences MOTION but never MEANING",
        fn = function()
            ScreenFx.reset()
            Settings.set("reduced_effects", true)
            ScreenFx.shake(8, 0.3); ScreenFx.punch(0.7); ScreenFx.flash({ 1, 1, 1 }, 0.3); ScreenFx.freeze(0.1)
            local ox, oy = ScreenFx.shakeOffset()
            assert(ox == 0 and oy == 0, "reduced effects must kill the shake")
            assert(ScreenFx.post().punch == 0, "reduced effects must kill the punch")
            assert(ScreenFx.timeScale() == 1, "reduced effects must kill the hit-stop")
            -- ...but the tint that carries a message goes through regardless.
            ScreenFx.grey(0.8); ScreenFx.vignette(0.5)
            for _ = 1, 30 do ScreenFx.update(1 / 60) end
            assert(ScreenFx.post().desat > 0.5, "the defeat grey must survive reduced effects")
            assert(ScreenFx.post().vignette > 0, "the danger vignette must survive reduced effects")
            Settings.set("reduced_effects", false)
            ScreenFx.reset()
        end,
    },
}
