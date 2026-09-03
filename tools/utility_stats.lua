-- Utility stat modifiers: run with
--
--     & "E:\LOVE\lovec.exe" . utility-stats [apply | table]
--
-- Gives every CLASSED utility a stat modifier that reinforces what it already does. Dry run by
-- default; `apply` writes the files, `table` prints the draft and stops.
--
-- WHY EVERY UTILITY WANTS ONE. 46 of 221 utilities carried a `bonus` block and 175 did not, which made
-- the type read as two different kinds of item wearing one name: a handful that move your numbers, and
-- a large majority that are a trait in a wrapper. On a 3x3 grid where every cell is a decision, an item
-- that changes no stat at all is hard to weigh against one that does -- the player has no common unit
-- to compare them in. A small modifier on each gives every slot a floor.
--
-- WHAT IS DELIBERATELY LEFT ALONE:
--
--   * The 46 that already carry a `bonus`. Skipped by inspection, so a hand-tuned value survives a
--     re-run and this tool never argues with an author.
--   * The 35 CLASSLESS utilities. Those are creature kit, not shelf stock -- "sheds a pair of
--     petal-drifts as it is wounded", "on death: bursts", "its wearer takes extra holy damage". They
--     are boss mechanics wearing the utility type, and a stat bonus on them is an enemy power buff that
--     belongs to a bestiary pass (docs/bestiary.md's health bands), not to a shelf one.
--
-- FLAT NUMBERS, NOT RAMPS, and that is the one place this pass departs from the corpus it is joining.
-- The 46 existing bonuses are nearly all `Curve.ramp(N, N + 10)`, which doubles-and-then-some by the
-- last forge level. That shape is right for an item whose bonus IS its point; it is wrong applied 140
-- times at once, because the same pass would then also be handing the shelf a second, larger power
-- increase at the top of every bench. It would additionally mean inserting `local Curve = require(...)`
-- into a hundred files that have never needed it. These are secondary modifiers on items whose primary
-- value is their trait, so they read as what they are: a small, permanent floor.
--
-- MAGNITUDES ARE 1 TO 3, and the band means something:
--
--   1  a kicker on an item whose real value is plainly elsewhere
--   2  the standard: the stat is a fair description of a side effect the item already has
--   3  the stat is close to being the item's whole point
--
-- A few carry a NEGATIVE second stat. Those are the items that already describe a bargain -- the flask
-- that gasses its own wearer, the focus that spends life for mana, the aegis lent away by stripping
-- your own guard -- and the malus is what keeps this pass from being 140 items of pure upside.
--
-- THE ONE RULE THAT IS NOT ABOUT FLAVOUR, and the one the first draft of this table broke ten times:
-- an item may not take a flat bonus in a stat its own TRAIT already grants. Both are real, both reach
-- flatStat, and the player is paid twice for one idea:
--
--   * Butcher's Tally banks damage per corpse. A flat `damage` on top made tests/trait_spec's "grants
--     nothing until someone dies" false -- the item now granted something before anyone had.
--   * Drill Standard carries trait_formation_fighter, which banks defense per flanking ally into
--     unit.bonus. tests/twr_import_spec exists specifically to catch a live trait doubling into that
--     field, and it caught this.
--   * The four FIST items (Iron, Swift, Shadow, Drunken) grant Power through `unarmedBonus`, and every
--     one of them says "does nothing for a weapon" in its own description. A flat `bonus.damage`
--     applies to ANY weapon, so it does not merely double the item -- it contradicts it.
--
-- Where that clash existed the stat was moved to a neighbouring one the item can honestly claim, not
-- shrunk: Crowd's Favour banks defense, so it takes magic defense; Reading the Blade banks damage, so
-- it takes the tempo it reads. The fists take guard, reach and fortune instead of Power.

local M = {}

-- id -> { bonus = "<literal Lua>", why = "<one line, written into the file>" }
--
-- Ordered by house below only for reading; the tool sorts by id. Each entry is a judgement about that
-- blueprint, so the reason travels with it into the file rather than living only here.
local DRAFT = {
    -- ---- alchemist (envy: consumables, poison and acid, coveting what others have) ----
    utility_alchemists_reservoir = { bonus = "magicDamage = 1", why = "a caster's harness: it exists to keep a spell going out" },
    utility_contagion            = { bonus = "magicDamage = 2", why = "the spread is the weapon" },
    utility_coveted_blood        = { bonus = "damage = 2", why = "it opens bodies up; it may as well hit them" },
    utility_cullers_basket       = { bonus = "magicDefense = 2", why = "eating the field's hazards is a ward by another route" },
    utility_everflask            = { bonus = "magicDamage = 1", why = "more castings out of the same satchel" },
    utility_jealous_resin        = { bonus = "defense = 2", why = "a coating that refuses to let go of anything" },
    utility_last_call            = { bonus = "magicDefense = 1, luck = 1", why = "drinking everything at once and coming out of it upright" },
    utility_long_fuse_reagent    = { bonus = "magicDamage = 1", why = "reach is a share of a throw's worth" },
    utility_miasma_flask         = { bonus = "magicDamage = 3, defense = -1", why = "it gasses its own wearer -- the bargain is on the label" },
    utility_mother_vat           = { bonus = "magicDamage = 2", why = "calling in every poison debt on the field at once" },
    utility_philosophers_stone   = { bonus = "magicDamage = 2", why = "copying a body is the deepest working on the shelf" },
    utility_salvage_rig          = { bonus = "magicDamage = 1", why = "a construct's death, harvested" },
    utility_sealed_bell          = { bonus = "magicDamage = 2", why = "one affliction spread across a field" },
    utility_short_fuse           = { bonus = "damage = 2", why = "every charge at once is a damage item however it is dressed" },
    utility_spiteful_ichor       = { bonus = "defense = 2", why = "blood that punishes the hand that draws it" },
    utility_survivors_reflex     = { bonus = "defense = 1, luck = 1", why = "a bandolier that drinks for you is a body that keeps getting away with it" },
    utility_tempered_gut         = { bonus = "magicDefense = 3", why = "immunity taken in doses -- the whole item is resistance" },
    utility_wellspring_sandals   = { bonus = "movement = 1", why = "footwear moves you; the mana behind you is the flourish" },

    -- ---- fighter (wrath: trades its own health and tempo for damage) ----
    utility_adrenal_surge        = { bonus = "speed = 2", why = "the item is tempo, bought with being hit" },
    utility_brawlers_bandolier   = { bonus = "speed = 1, damage = 1", why = "a drink and a swing, neither of them slow" },
    utility_butchers_tally       = { bonus = "defense = 1", why = "the tally banks its own Power per corpse; this is only the apron" },
    utility_crowds_favour        = { bonus = "magicDefense = 2", why = "it banks guard from the crowd already, so this is the other school" },
    utility_duelists_reflex      = { bonus = "defense = 2", why = "a deflection is guard, arriving late" },
    utility_field_still          = { bonus = "magicDefense = 1", why = "something brewing in the grid every turn" },
    utility_last_order           = { bonus = "damage = 1", why = "an order given is a blow thrown by somebody else" },
    utility_pincer_banner        = { bonus = "damage = 2", why = "a second swing off an ally's, and swings are its unit" },
    utility_reading_the_blade    = { bonus = "speed = 1", why = "it converts tempo into Power, so the floor is the tempo itself" },
    utility_red_account          = { bonus = "damage = 3, defense = -1", why = "Fury banked against your own health: the account is the bargain" },
    utility_red_thirst           = { bonus = "damage = 2", why = "the thirst is for blows landed" },
    utility_reprisal             = { bonus = "defense = 2", why = "answering every adjacent foe means surviving to answer" },
    utility_resonant_grip        = { bonus = "magicDamage = 2", why = "steel carrying a working is a magical weapon in the hand" },
    utility_round_for_the_house  = { bonus = "magicDefense = 1", why = "what you drink, the line beside you drinks" },
    utility_toughness            = { bonus = "defense = 1", why = "the pool is its point; the plate is the sentiment" },
    utility_vampiric_strike      = { bonus = "defense = 1", why = "what it drinks keeps it standing -- the damage is the neighbour's" },
    utility_veterans_resolve     = { bonus = "defense = 2", why = "a barrier that arrives when the fight has already gone badly" },

    -- ---- hunter (gluttony: setup, then payoff -- marks, traps, beasts) ----
    utility_ancestor_mask        = { bonus = "magicDefense = 2", why = "a mask that keeps the field's own workings off what you field" },
    utility_beastlords_bond      = { bonus = "damage = 1", why = "every act of yours is another set of teeth" },
    utility_borrowed_pelt        = { bonus = "damage = 2", why = "wearing a wyrm is not a subtle item" },
    utility_caltrop_greaves      = { bonus = "movement = 1", why = "greaves: the ground behind you is what they leave, not what they are" },
    utility_companion_whistle    = { bonus = "damage = 1", why = "a wolf from the first turn" },
    utility_cullers_kit          = { bonus = "skill = 2", why = "culling is precise work, and the Lodge is the aiming house" },
    utility_endurance            = { bonus = "defense = 1", why = "a deeper pool is a body that lasts" },
    utility_executioners_eye     = { bonus = "skill = 2", why = "an eye that decides the kill before the shot" },
    utility_falconers_glove      = { bonus = "skill = 2", why = "the hawk marks; the hand that flies it aims" },
    utility_ghost_wind           = { bonus = "speed = 2", why = "everything you field arrives already moving" },
    utility_ground_given         = { bonus = "movement = 1, damage = 1", why = "strike, cross the board, strike again -- both halves" },
    utility_hunting_horn         = { bonus = "magicDefense = 1", why = "an air sounded over the line" },
    utility_marchstone           = { bonus = "defense = 2", why = "it stops bodies moving, which is a wall's job" },
    utility_patient_line         = { bonus = "skill = 2", why = "the line was the ground she had already decided about" },
    utility_quarrys_due          = { bonus = "skill = 2", why = "a trap that also paints what it caught" },
    utility_reprisal_quiver      = { bonus = "damage = 2", why = "an arrow back is an arrow" },
    utility_second_leash         = { bonus = "defense = 2", why = "bracing the pack braces the handler" },
    utility_skirmishers_momentum = { bonus = "movement = 1, damage = 1", why = "the item is literally movement converted into a blow" },
    utility_spirit_fetish        = { bonus = "magicDefense = 2", why = "what it gives the line it keeps a share of" },
    utility_torch                = { bonus = "skill = 1", why = "seeing further is aiming better, even on a torch" },
    utility_totem_carvers_kit    = { bonus = "magicDefense = 1", why = "everything you raise stands up sturdier" },
    utility_trackless_boots      = { bonus = "movement = 1", why = "footwear, and the one that most plainly is" },
    utility_trap_sense           = { bonus = "luck = 2", why = "knowing where the ground is bad is what luck looks like from outside" },

    -- ---- knight (sloth: the wall -- it decides where you stand) ----
    utility_aegis_of_the_oath    = { bonus = "magicDefense = 2", why = "a ward that walks with you" },
    utility_bound_mile           = { bonus = "defense = 2", why = "everything held stays held, the bearer included" },
    utility_breakers_wedge       = { bonus = "damage = 2", why = "a shove that also Sunders is a blow" },
    utility_dampening_oath       = { bonus = "magicDefense = 3", why = "an oath that makes magic cost double is anti-magic entire" },
    utility_doorstone            = { bonus = "defense = 3", why = "it raises a wall; the wall is the item" },
    utility_drill_standard       = { bonus = "magicDefense = 2", why = "formation banks defense live; drill steadies the other school" },
    utility_dry_word             = { bonus = "magicDefense = 2", why = "taking a caster's mana and keeping it" },
    utility_greywatch_muster_roll= { bonus = "magicDefense = 2", why = "the roll counts guard at the bell; this is what it does not count" },
    utility_lent_aegis           = { bonus = "magicDefense = 2, defense = -1", why = "the guard is lent away -- the malus is the whole mechanic" },
    utility_mana_shield          = { bonus = "magicDefense = 2", why = "wounds paid out of the wrong pool" },
    utility_miasmal_plate        = { bonus = "defense = 2", why = "plate first, poison second" },
    utility_relief_horn          = { bonus = "defense = 2", why = "swapping in for somebody is a wall's move" },
    utility_rot_fume_gauntlet    = { bonus = "defense = 2", why = "it banks Power per poisoned body; the gauntlet is still plate" },
    utility_second_wind          = { bonus = "defense = 2, luck = 1", why = "surviving a killing blow is guard and fortune together" },
    utility_shield_bash          = { bonus = "defense = 2", why = "it needs a shield in the grid; it may as well be one" },
    utility_struck_name          = { bonus = "defense = 2", why = "every blow on the named is taken here" },
    utility_surveyors_chain      = { bonus = "movement = 1", why = "it prices ground for the whole line" },
    utility_the_wedge            = { bonus = "damage = 2", why = "driving down a lane through bodies" },
    utility_unyielding_seal      = { bonus = "magicDefense = 2", why = "shrugging a debuff off as it lands" },
    utility_wardens_writ         = { bonus = "defense = 2", why = "hazards that Halt are ground held" },

    -- ---- mage (pride: elements, wind-ups, remaking the ground) ----
    utility_arcane_conduit       = { bonus = "magicDamage = 2", why = "the grid casts harder around it" },
    utility_attunement           = { bonus = "magicDamage = 1", why = "a deeper pool is more castings" },
    utility_battle_casting       = { bonus = "defense = 1", why = "a mage that means to be stood next to" },
    utility_bloodstone_focus     = { bonus = "magicDamage = 3, defense = -1", why = "spells paid for in life: the focus is the bargain" },
    utility_charnel_reliquary    = { bonus = "magicDefense = 1", why = "it banks Power per body; the reliquary itself only wards" },
    utility_cinderstride_boots   = { bonus = "movement = 1", why = "footwear; the fire is what it leaves" },
    utility_counter_magic        = { bonus = "magicDefense = 2", why = "unravelling a spell aimed at you" },
    utility_court_kept_waiting   = { bonus = "magicDefense = 2", why = "everything you hold is braced while it waits" },
    utility_distant_sigil        = { bonus = "magicDamage = 1", why = "reach is a share of a spell's worth" },
    utility_empty_vessel         = { bonus = "magicDefense = 1", why = "it banks its Power against the spent; empty is also hard to drain" },
    utility_folded_word          = { bonus = "magicDamage = 2", why = "three blows carrying a working" },
    utility_gleaning_rod         = { bonus = "magicDamage = 1", why = "a charge off every spell nearby" },
    utility_hour_returned        = { bonus = "speed = 2", why = "the item is time given back" },
    utility_mana_wellspring      = { bonus = "magicDamage = 1", why = "the only pool that refills itself" },
    utility_ninth_sigil          = { bonus = "magicDamage = 3", why = "every working you laid, under every foe at once" },
    utility_old_wind             = { bonus = "magicDamage = 2", why = "the field's hazards stand up and take your side" },
    utility_pale_vesture         = { bonus = "defense = 3, magicDefense = -1", why = "almost nothing physical lands, and the trade is in the other school" },
    utility_quickened_sigil      = { bonus = "speed = 2", why = "the neighbour comes back around sooner; so does the bearer" },
    utility_resonance_prism      = { bonus = "magicDamage = 2", why = "it raises the magnitude of everything beside it" },
    utility_second_reading       = { bonus = "magicDefense = 1", why = "a reading that undoes what the first one raised" },
    utility_second_utterance     = { bonus = "speed = 1, magicDamage = 1", why = "the next channel comes faster and lands the same" },
    utility_spell_eater          = { bonus = "magicDefense = 3", why = "anti-magic as absorption -- the item is the resistance" },
    utility_spellstrike          = { bonus = "magicDamage = 2", why = "steel made magical" },
    utility_standing_order       = { bonus = "magicDamage = 1", why = "an order that arms everything you built" },
    utility_stormglass_rod       = { bonus = "magicDamage = 2", why = "lifting a body out of a fight entirely" },
    utility_tidewalker_boots     = { bonus = "movement = 1", why = "footwear; the water is the wake" },
    utility_twinned_sigil        = { bonus = "magicDamage = 2", why = "one cast, two bodies" },
    utility_vigil_beads          = { bonus = "magicDefense = 2", why = "a channel nothing can break into" },

    -- ---- priest (lust: zones and wards, holy, and the bare fist) ----
    utility_burning_halo         = { bonus = "magicDamage = 2", why = "a halo that burns whoever stands in it" },
    utility_censer_of_dawn       = { bonus = "magicDamage = 2", why = "it makes the grid beside it holy" },
    utility_centering_charm      = { bonus = "skill = 2", why = "centering is composure, and composure is aim" },
    utility_cleansing_ward       = { bonus = "magicDefense = 2", why = "the first debuff simply does not land" },
    utility_drunken_fist         = { bonus = "luck = 2", why = "the drunk's own luck; the Power belongs to the fist, not the wielder" },
    utility_iron_fist            = { bonus = "defense = 1", why = "a gauntlet guards the hand; the Power is unarmedBonus's, not a weapon's" },
    utility_martyrs_icon         = { bonus = "defense = 2", why = "standing in front of somebody is guard" },
    utility_open_ward            = { bonus = "magicDefense = 2", why = "every heal also lends guard, for the rest of the fight" },
    utility_pilgrims_sandals     = { bonus = "movement = 1", why = "footwear; the hallowed ground is the wake" },
    utility_reliquary_of_tallies = { bonus = "magicDefense = 1, luck = 1", why = "it fills with the ones you lost, which is the wrong kind of luck" },
    utility_rite_unspoken        = { bonus = "magicDefense = 2", why = "everything invited is sent home" },
    utility_shadow_fist          = { bonus = "movement = 1", why = "a fist that reaches further covers ground" },
    utility_shared_ledger        = { bonus = "magicDefense = 2", why = "your guard, lent to whoever you mend" },
    utility_standing_stone       = { bonus = "magicDefense = 2", why = "consecrated ground that stays after the totems fall" },
    utility_swift_fist           = { bonus = "speed = 2", why = "two punches in the time of one, and no Power a weapon could borrow" },
    utility_unbroken_vigil       = { bonus = "luck = 2", why = "a prayer nothing can break is a body nothing catches badly" },
    utility_unheld_hand          = { bonus = "magicDamage = 1", why = "chi back for everything the fists earned" },
    utility_vow_of_the_march     = { bonus = "defense = 2", why = "the vow banks magic defense per Zeal, so the floor is the plainer guard" },
    utility_written_charge       = { bonus = "skill = 2", why = "judging every Marked foe at once is the payoff the Lodge sets up" },

    -- ---- rogue (greed: guile, and taking what is not yours) ----
    utility_bag_of_holding       = { bonus = "luck = 2", why = "a bag that keeps what you took" },
    utility_cutpurse_tally       = { bonus = "luck = 2", why = "it banks Power per debuff; a cutpurse's floor is getting away with it" },
    utility_deadhand_grip        = { bonus = "damage = 1, defense = 1", why = "a grip nothing takes the weapon out of" },
    utility_feather_boots        = { bonus = "movement = 1", why = "footwear; the traps that do not spring are the wake" },
    utility_fourth_shadow        = { bonus = "luck = 2", why = "more of you than there are blows to spend" },
    utility_greyveil_cloak       = { bonus = "luck = 2", why = "being untargetable is fortune with a mechanism" },
    utility_quarrys_end          = { bonus = "skill = 2", why = "the whole field Rooted and painted at once" },
    utility_quiet_errand         = { bonus = "skill = 2", why = "striking anywhere in sight, for the ground you gave up" },
    utility_slipchain_charm      = { bonus = "movement = 1, luck = 1", why = "nothing holds you, which is half movement and half fortune" },
    utility_stripped_plate       = { bonus = "defense = 2", why = "you wear what you Sundered off somebody else" },
    utility_substitution         = { bonus = "luck = 2", why = "the blow lands on a clone, which from outside looks like luck" },
    utility_the_long_wait        = { bonus = "skill = 2", why = "a blow that cannot be answered is a blow taken carefully" },
    utility_the_signal           = { bonus = "damage = 2", why = "every charge you buried, at once" },
    utility_with_interest        = { bonus = "damage = 2", why = "one blow per coin, and the coins were spent on blows" },
    utility_zephyr_striders      = { bonus = "movement = 1", why = "footwear, and the flattest ground-cost item there is" },
}

-- ---------------------------------------------------------------------------

-- Insert the bonus line before the file's final closing brace -- the one that ends the `return {`
-- table. Anchored on the last such line rather than on any particular field, because utility
-- blueprints end in wildly different shapes: a flat field list, a nested `aura`, a multi-line effect
-- function.
local function insert(src, bonus, why)
    local lines = {}
    for line in (src .. "\n"):gmatch("([^\n]*)\n") do lines[#lines + 1] = line end
    -- Trailing blank lines are normal; walk back to the last line with content on it.
    local last
    for i = #lines, 1, -1 do
        if lines[i]:match("^%s*}%s*,?%s*$") then last = i break end
        if lines[i]:match("%S") then return nil end -- ends in something other than a brace: leave it
    end
    if not last then return nil end
    table.insert(lines, last, string.format("    -- %s\n    bonus = { %s },", why, bonus))
    return table.concat(lines, "\n")
end

function M.run(args)
    args = args or {}
    local apply, tableOnly = false, false
    for _, a in ipairs(args) do
        if a == "apply" then apply = true elseif a == "table" then tableOnly = true end
    end

    local rows, skipped = {}, {}
    for _, name in ipairs(love.filesystem.getDirectoryItems("data/items/utility")) do
        if name:sub(-4) == ".lua" then
            local id = name:sub(1, -5)
            local path = "data/items/utility/" .. name
            local src = love.filesystem.read(path)
            local draft = DRAFT[id]
            if not src then
                skipped[#skipped + 1] = { id = id, why = "unreadable" }
            elseif src:find("\n%s*bonus = {") then
                skipped[#skipped + 1] = { id = id, why = "already carries a bonus" }
            elseif not draft then
                skipped[#skipped + 1] = { id = id, why = "classless -- creature kit, not shelf stock" }
            else
                local body = insert(src, draft.bonus, draft.why)
                if body then
                    rows[#rows + 1] = { id = id, path = path, bonus = draft.bonus, body = body }
                else
                    skipped[#skipped + 1] = { id = id, why = "could not find the table's closing brace" }
                end
            end
        end
    end

    table.sort(rows, function(a, b) return a.id < b.id end)

    print(string.format("UTILITY STAT MODIFIERS -- %s",
        apply and "APPLYING" or (tableOnly and "draft" or "dry run (pass `apply` to write)")))
    print("")
    for _, r in ipairs(rows) do
        print(string.format("  %-34s %s", r.id, r.bonus))
    end
    print("")
    print(string.format("  %d to write, %d skipped", #rows, #skipped))
    local byWhy = {}
    for _, s in ipairs(skipped) do byWhy[s.why] = (byWhy[s.why] or 0) + 1 end
    for why, n in pairs(byWhy) do print(string.format("    %3d  %s", n, why)) end
    print("")

    if tableOnly then return end
    if not apply then
        print("  Nothing written. Re-run with `apply`.")
        return
    end

    -- love.filesystem writes to the SAVE directory, not the project, so the write goes through io.
    local written, failed = 0, {}
    for _, r in ipairs(rows) do
        local fh = io.open(r.path, "wb")
        if fh then
            fh:write(r.body); fh:close(); written = written + 1
        else
            failed[#failed + 1] = r.path
        end
    end
    print(string.format("  wrote %d files", written))
    for _, p in ipairs(failed) do print("  COULD NOT WRITE: " .. p) end
end

return M
