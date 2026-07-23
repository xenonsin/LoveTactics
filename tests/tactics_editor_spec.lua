-- Tests for the Tactics tab: the pure row/field helpers behind ui/tactics_editor.lua, and the
-- save round trip for the player-authored settings it writes.
--
-- The widget's own drawing is not testable headless, which is exactly why the logic worth testing is
-- kept OUT of it -- reordering, field visibility and option cycling are static functions, following
-- the precedent set by Party.regionCross and Party.equipDelta in tests/party_spec.lua.

local AI = require("models.ai")
local Editor = require("ui.tactics_editor")
local Character = require("models.character")
local Item = require("models.item")
local Player = require("models.player")
local Save = require("models.save")

local function rules(n)
    local out = {}
    for i = 1, n do
        local r = AI.newRule()
        r.marker = i -- so a reorder is observable
        out[i] = r
    end
    return out
end

return {
    -- ---------------------------------------------------------------------
    -- Reordering
    -- ---------------------------------------------------------------------
    {
        name = "moveRule carries a rule to a new index and clamps at both ends",
        fn = function()
            local list = rules(4)
            assert(Editor.moveRule(list, 1, 3) == 3, "reports where the rule landed")
            assert(list[3].marker == 1, "the moved rule is at its new index")
            assert(list[1].marker == 2 and list[2].marker == 3, "the rest closed up behind it")

            local at = Editor.moveRule(list, 3, 99)
            assert(at == #list, "past the end clamps to the last slot")
            local top = Editor.moveRule(list, 2, -5)
            assert(top == 1, "past the start clamps to the first")

            local before = #list
            Editor.moveRule(list, 2, 2)
            assert(#list == before, "a move to the same index is a no-op, not a duplication")
            assert(Editor.moveRule(list, 99, 1) == 99, "moving a row that isn't there does nothing")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Field visibility
    -- ---------------------------------------------------------------------
    {
        name = "the value field appears only for a test that takes a value",
        fn = function()
            -- An editor that offers "exists 0.4" is offering nonsense, and a player who sets it has
            -- been told a lie about what their rule does.
            local function hasField(rule, key)
                for _, f in ipairs(Editor.visibleFields(rule)) do if f.key == key then return true end end
                return false
            end

            local rule = AI.newRule()
            rule.when = { subject = "any_foe", test = "exists" }
            assert(not hasField(rule, "value"), "`exists` takes no value")

            rule.when = { subject = "any_ally", test = "hp_pct_below", value = 0.5 }
            assert(hasField(rule, "value"), "`hp_pct_below` does")

            -- Every test that declares a value spec must surface the field, and no other may.
            for _, test in ipairs(AI.TEST_ORDER) do
                rule.when = { subject = "any_foe", test = test }
                assert(hasField(rule, "value") == (AI.TEST_VALUE[test] ~= nil),
                    "value field visibility disagrees with AI.TEST_VALUE for " .. test)
            end
        end,
    },
    {
        name = "target preference is hidden for a rule that aims at nobody",
        fn = function()
            local function hasField(rule, key)
                for _, f in ipairs(Editor.visibleFields(rule)) do if f.key == key then return true end end
                return false
            end
            local rule = AI.newRule()
            rule.act = "attack"
            assert(hasField(rule, "targetPref"), "an attack has something to prefer")
            rule.act = "wait"
            assert(not hasField(rule, "targetPref"), "a wait does not")
            rule.act = "retreat"
            assert(not hasField(rule, "targetPref"), "nor does a retreat")
        end,
    },
    {
        name = "changing the test resets the value instead of carrying a meaningless number across",
        fn = function()
            -- 0.5 as a health fraction is a coherent thing to want; 0.5 as a tile count is not. A
            -- field editor that keeps the old number across a type change silently produces a rule
            -- that reads fine and behaves strangely.
            local rule = AI.newRule()
            local testField
            for _, f in ipairs(Editor.FIELDS) do if f.key == "test" then testField = f end end

            rule.when = { subject = "any_ally", test = "hp_pct_below", value = 0.5 }
            testField.set(rule, "within")
            assert(rule.when.value == AI.TEST_VALUE.within.default,
                "switching to a tile test takes the tile default, not 0.5")

            testField.set(rule, "exists")
            assert(rule.when.value == nil, "switching to a valueless test drops the value entirely")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Cycling
    -- ---------------------------------------------------------------------
    {
        name = "cycle steps through options and wraps at both ends",
        fn = function()
            local opts = { "a", "b", "c" }
            assert(Editor.cycle(opts, "a", 1) == "b", "forward")
            assert(Editor.cycle(opts, "c", 1) == "a", "wraps forward")
            assert(Editor.cycle(opts, "a", -1) == "c", "wraps backward")
            assert(Editor.cycle({}, "a", 1) == "a", "an empty option list leaves the value alone")
            assert(Editor.cycle(opts, "zzz", 1) == "b", "an unknown value starts from the top")

            -- Float steps accumulate error, so 0.5 in a rule will not be identical to the 0.5 a
            -- generated list arrives at. Matching by proximity is what keeps the cursor from
            -- snapping back to the first option every time a percentage is edited.
            local pct = {}
            for v = 0.05, 1 + 1e-9, 0.05 do pct[#pct + 1] = v end
            local next_ = Editor.cycle(pct, 0.5, 1)
            assert(math.abs(next_ - 0.55) < 1e-6, "0.5 finds its neighbour despite float drift")
        end,
    },
    {
        name = "every field's options are non-empty and its current value is always among them",
        fn = function()
            -- A field whose value isn't in its own option list can't be cycled away from coherently.
            local char = Character.instantiate("character_priest")
            local rule = AI.newRule()
            for _, test in ipairs(AI.TEST_ORDER) do
                rule.when = { subject = "any_foe", test = test }
                if AI.TEST_VALUE[test] then rule.when.value = AI.TEST_VALUE[test].default end
                for _, f in ipairs(Editor.visibleFields(rule, char)) do
                    local opts = f.options(rule, char)
                    assert(#opts > 0, f.key .. " offers no options for test " .. test)
                    local current, found = f.get(rule, char), false
                    for _, o in ipairs(opts) do
                        if o == current or (type(o) == "number" and type(current) == "number"
                            and math.abs(o - current) < 1e-6) then found = true end
                    end
                    assert(found, f.key .. " current value is not among its own options (test " .. test .. ")")
                end
            end
        end,
    },
    {
        name = "the ordered vocabularies and the validation sets agree in both directions",
        fn = function()
            -- The UI cycles the ordered lists; the model validates against the keyed sets. An entry
            -- in one and not the other is either an option that resolves to nothing or a rule the
            -- player can never author.
            local function agree(order, set, what)
                local seen = {}
                for _, name in ipairs(order) do
                    assert(set[name], what .. " list offers '" .. name .. "', which the model rejects")
                    seen[name] = true
                end
                for name in pairs(set) do
                    assert(seen[name], what .. " '" .. name .. "' exists but the UI can never offer it")
                end
            end
            agree(AI.SUBJECT_ORDER, AI.SUBJECTS, "subject")
            agree(AI.TEST_ORDER, AI.TESTS, "test")
            agree(AI.ACTION_ORDER, AI.ACTIONS, "action")
            agree(AI.PRIORITY_ORDER, AI.PRIORITY, "priority")
        end,
    },

    {
        name = "the item field offers 'any' plus exactly what the character is carrying",
        fn = function()
            local char = Character.instantiate("character_priest")
            local itemField
            for _, f in ipairs(Editor.FIELDS) do if f.key == "item" then itemField = f end end
            local rule = AI.newRule()
            local opts = itemField.options(rule, char)

            assert(opts[1] == false, "'any' leads, and is a reachable choice rather than an absence")
            local ids = {}
            for _, o in ipairs(opts) do if o then ids[o] = true end end
            assert(ids["ability_heal"], "the priest's Heal is offered")
            assert(ids[char.unarmed.id], "so are the bare fists, which are never in the grid")
            assert(not ids["ability_fireball"], "an item the priest does not carry is not offered")

            -- Cycling to an id and back to `any` must leave no residue on the rule.
            itemField.set(rule, "ability_heal")
            assert(rule.item == "ability_heal", "set stores the id")
            itemField.set(rule, false)
            assert(rule.item == nil, "and 'any' clears it rather than storing false")
        end,
    },
    {
        name = "the item field is hidden for a rule that uses no item",
        fn = function()
            local char = Character.instantiate("character_priest")
            local function hasField(rule, key)
                for _, f in ipairs(Editor.visibleFields(rule, char)) do if f.key == key then return true end end
                return false
            end
            local rule = AI.newRule()
            rule.act = "cast"
            assert(hasField(rule, "item"), "a cast uses an item")
            rule.act = "retreat"
            assert(not hasField(rule, "item"), "a retreat does not")
            rule.act = "wait"
            assert(not hasField(rule, "item"), "nor does a wait")
        end,
    },

    -- ---------------------------------------------------------------------
    -- The default rule
    -- ---------------------------------------------------------------------
    {
        name = "a freshly added rule is valid, enabled, and already does something sensible",
        fn = function()
            -- The first thing a player sees after clicking "+ Add rule" has to be a working rule, not
            -- a form to fill in before anything happens.
            local rule = AI.newRule()
            assert(rule.enabled ~= false, "a new rule is on")
            assert(AI.SUBJECTS[rule.when.subject], "its subject is real")
            assert(AI.TESTS[rule.when.test], "its test is real")
            assert(AI.ACTIONS[rule.act], "its action is real")
            assert(pcall(AI.priorityOf, rule), "its priority is real")
            assert(#AI.describeRule(rule) > 0, "and it renders as a sentence")
        end,
    },
    {
        name = "a disabled rule is skipped by the merge but kept in the list",
        fn = function()
            -- Toggling rows off is most of how anyone debugs a list, so a disabled rule has to stop
            -- firing without being lost.
            local char = Character.instantiate("character_bandit")
            char.aiRules = { AI.newRule(), AI.newRule() }
            char.aiRules[1].enabled = false
            char.aiRules[1].act = "wait"

            local merged = AI.rulesFor({ char = char })
            for _, entry in ipairs(merged) do
                assert(entry.rule ~= char.aiRules[1], "the disabled rule never reaches the merge")
            end
            assert(#char.aiRules == 2, "but it is still in the player's list")
        end,
    },

    -- ---------------------------------------------------------------------
    -- Merge & ownership: the blueprint's own rules and the player's overlay
    -- ---------------------------------------------------------------------
    {
        name = "editing an inherited blueprint rule in-game seeds the player's overlay",
        fn = function()
            -- The mage ships with a blueprint ai rule and no overlay; the Tactics tab shows those rules
            -- as inherited and takes ownership only when the player actually changes one.
            local char = Character.instantiate("character_mage")
            assert(char.ai and #char.ai > 0, "the blueprint ships with a rule")
            assert(char.aiRules == nil, "and no player overlay yet")

            local ed = Editor.new({ x = 0, y = 0, w = 800, h = 600, char = char, fonts = {} })
            assert(char.aiRules == nil, "opening the tab and reading the list does not seed it")
            assert(ed:inherited(), "the editor reports the rows are still the blueprint's")

            -- Change the first rule's first field: the first edit copies the whole list into the overlay.
            ed.region, ed.cursor, ed.fieldCursor = "fields", 1, 1
            ed:cycleField(1)
            assert(char.aiRules ~= nil, "the first edit mints the overlay")
            assert(#char.aiRules == #char.ai,
                "seeded with the whole blueprint list, so nothing inherited is lost")
            assert(char.aiRules[1] ~= char.ai[1],
                "and with independent copies, not aliases of the blueprint rules")
            assert(not ed:inherited(), "the list is now the player's own")
        end,
    },
    {
        name = "the character editor (ownKey = 'ai') edits the blueprint's own list directly",
        fn = function()
            local char = Character.instantiate("character_mage")
            local before = #char.ai
            local ed = Editor.new({ x = 0, y = 0, w = 800, h = 600, char = char, fonts = {}, ownKey = "ai" })
            assert(not ed:inherited(), "in the character editor the rules ARE the list, not an inheritance")
            ed:addRule()
            assert(#char.ai == before + 1, "a new rule lands on char.ai, ready to be written to data/")
            assert(char.aiRules == nil, "and no player overlay is minted -- that channel is in-game only")
        end,
    },
    {
        name = "deleting every rule leaves the list owned-and-empty, not resurrected",
        fn = function()
            -- The trap the ownership-by-presence rule closes: if an emptied overlay read back as
            -- un-owned, deleting your last rule would silently bring the blueprint's rules back.
            local char = Character.instantiate("character_mage")
            local ed = Editor.new({ x = 0, y = 0, w = 800, h = 600, char = char, fonts = {} })
            ed:addRule() -- takes ownership (seeds from the blueprint) and appends one
            while #char.aiRules > 0 do ed:removeRule(1) end
            assert(char.aiRules ~= nil and #char.aiRules == 0, "the overlay is an empty table, not nil")
            assert(not ed:inherited(), "so the blueprint rules do not come back as 'inherited'")

            local merged = AI.rulesFor({ char = char })
            for _, e in ipairs(merged) do
                assert(e.rule ~= char.ai[1],
                    "and the merge collects no character-source rule once the overlay owns the list")
            end
        end,
    },

    -- ---------------------------------------------------------------------
    -- Persistence
    -- ---------------------------------------------------------------------
    {
        name = "tactics survive a save/load round trip",
        fn = function()
            local p = Player.new()
            local char = p.roster[1]
            char.aiRules = { AI.newRule() }
            char.aiRules[1].priority = "urgent"
            char.aiRules[1].when = { subject = "ally_lowest_hp", test = "hp_pct_below", value = 0.35 }
            char.autoBattle = true
            char.archetype = "skirmish"

            local restored = Save.restore(Save.snapshot(p))
            assert(restored, "the save round-trips at all")
            local back = restored.roster[1]
            assert(back.aiRules and #back.aiRules == 1, "the rule list came back")
            assert(back.aiRules[1].priority == "urgent", "with its priority band")
            assert(back.aiRules[1].when.value == 0.35, "and its authored value")
            assert(back.autoBattle == true, "auto-battle came back")
            assert(back.archetype == "skirmish", "so did the archetype override")
        end,
    },
    {
        name = "an owned-but-emptied rule list survives the round trip instead of resurrecting the blueprint",
        fn = function()
            -- Ownership is carried by the list's EXISTENCE, so an empty overlay must save as `{}` and
            -- load back non-nil -- the save-side half of the "deleting every rule" editor case above.
            local p = Player.new()
            local char = p.roster[1]
            char.aiRules = {} -- the player took ownership, then deleted every rule
            local restored = Save.restore(Save.snapshot(p))
            local back = restored.roster[1]
            assert(back.aiRules ~= nil, "the empty overlay is preserved as ownership, not dropped")
            assert(#back.aiRules == 0, "and it is still empty")
        end,
    },
    {
        name = "a character who never opened the tab adds nothing to the save",
        fn = function()
            -- Optional-and-only-when-set, matching defaultActionSlot: an untouched roster has to keep
            -- diffing clean, or every save carries a copy of settings nobody chose.
            local p = Player.new()
            local snap = Save.snapshot(p)
            for _, charSnap in ipairs(snap.roster) do
                assert(charSnap.aiRules == nil, "no empty rule list is written")
                assert(charSnap.autoBattle == nil, "no auto-battle flag is written")
                assert(charSnap.archetype == nil,
                    "no archetype is written when it still matches the blueprint")
            end
        end,
    },
    {
        name = "clearing a blueprint archetype back to default survives the round trip",
        fn = function()
            -- The hard case: `nil` here means two different things -- "never set" and "deliberately
            -- cleared" -- and only one of them should override what the blueprint says.
            local p = Player.new()
            local archer = Character.instantiate("character_archer")
            assert(archer.archetype == "skirmish", "the blueprint ships with one")
            p.roster[#p.roster + 1] = archer
            archer.archetype = nil -- the player cleared it

            local snap = Save.snapshot(p)
            local mine
            for _, c in ipairs(snap.roster) do if c.id == "character_archer" then mine = c end end
            assert(mine and mine.archetype == false, "the clear is stored explicitly, not as an absence")

            local restored = Save.restore(snap)
            local back
            for _, c in ipairs(restored.roster) do if c.id == "character_archer" then back = c end end
            assert(back and back.archetype == nil,
                "and it loads back cleared rather than picking the blueprint's up again")
        end,
    },
    {
        name = "an old save with no tactics loads unchanged",
        fn = function()
            local p = Player.new()
            local snap = Save.snapshot(p)
            for _, c in ipairs(snap.roster) do
                c.aiRules, c.autoBattle, c.archetype = nil, nil, nil
            end
            local restored = Save.restore(snap)
            assert(restored, "a save predating the Tactics tab still loads")
            assert(restored.roster[1].aiRules == nil, "with no rules")
            assert(not restored.roster[1].autoBattle, "and auto-battle off")
        end,
    },
}
