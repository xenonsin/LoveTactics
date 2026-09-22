-- Hand-picked icons, for assets whose names describe an IDEA rather than an object.
--
-- `. icon-map` matches names against game-icons.net and does well on anything that names a thing:
-- a flail is a flail. It cannot do anything with "tempo debt" or "the names he kept", because no
-- amount of string matching turns those into a picture. Those decisions live here.
--
-- An entry wins over whatever the matcher would have guessed, and is written into map.lua as
-- `by = "hand"`, so regenerating never disturbs it.
--
-- Name an icon either fully ("lorc/incense") or by name alone ("incense") -- which artist drew it
-- is not worth looking up. An icon named here that does not exist is reported as an error rather
-- than silently skipped, so a typo cannot quietly cost an item its art.
--
-- Browse the vocabulary at https://game-icons.net, or grep the vendored set:
--     grep -i shield vendor/slugs.txt

return {
    -- Hazards are deliberately NOT here. A hazard is a patch of ground, not an object sitting on
    -- it, and a centred glyph fights that reading. They stay on ui/battle_map.lua's tinted wash
    -- until painted art exists. See docs/art-assets.md.

    -- --------------------------------------------------------------- abilities
    ["items/ability_answering_din.png"] = "shouting",
    ["items/ability_backward_glance.png"] = "backward-time",
    ["items/ability_banish.png"] = "magic-portal",
    ["items/ability_blightstake.png"] = "heart-stake",
    ["items/ability_conjunction.png"] = "moon-bats",
    ["items/ability_culling_stroke.png"] = "reaper-scythe",
    ["items/ability_detonate.png"] = "bright-explosion",
    ["items/ability_disarm.png"] = "sword-break",
    ["items/ability_dispel_illusions.png"] = "disintegrate",
    ["items/ability_dual_wield.png"] = "crossed-swords",
    ["items/ability_en_garde.png"] = "duel",
    ["items/ability_exploit.png"] = "eye-target",
    ["items/ability_gaunt_vigil.png"] = "old-lantern",
    ["items/ability_held_reaction.png"] = "hourglass",
    ["items/ability_jolt.png"] = "lightning-arc",
    ["items/ability_keen_senses.png"] = "all-seeing-eye",
    ["items/ability_leaping_crash.png"] = "pounce",
    ["items/ability_mana_sunder.png"] = "lorc/implosion",
    ["items/ability_mark_of_heresy.png"] = "crown-of-thorns",
    ["items/ability_mirror_image.png"] = "invisible",
    ["items/ability_muster_rift.png"] = "portal",
    ["items/ability_not_yet.png"] = "stopwatch",
    ["items/ability_omnislash.png"] = "lorc/atomic-slashes",
    ["items/ability_overcharge.png"] = "energise",
    ["items/ability_polymorph.png"] = "transform",
    ["items/ability_provoke.png"] = "lorc/screaming",
    ["items/ability_scouring_mercy.png"] = "bleeding-wound",
    ["items/ability_set_charge.png"] = "smoke-bomb",
    ["items/ability_single_combat.png"] = "lorc/sword-clash",
    ["items/ability_thicketing.png"] = "vines",
    ["items/ability_zealous_charge.png"] = "charged-arrow",

    -- The six summons take their element, not the word "summon" -- what the player must read at a
    -- glance is WHICH elemental is arriving.
    ["items/ability_summon_earth_elemental.png"] = "rock-golem",
    ["items/ability_summon_fire_elemental.png"] = "fire-silhouette",
    ["items/ability_summon_ice_elemental.png"] = "frostfire",
    ["items/ability_summon_lightning_elemental.png"] = "lightning-branches",
    ["items/ability_summon_water_elemental.png"] = "water-drop",
    ["items/ability_summon_wind_elemental.png"] = "tornado",
    ["items/ability_summon_homunculus.png"] = "imp-laugh",

    -- ------------------------------------------------------------------ gear
    ["items/armor_choking_apron.png"] = "delapouite/hazmat-suit",
    ["items/armor_everdraught_bandolier.png"] = "lorc/transparent-tubes",
    ["items/armor_quarryhide.png"] = "leather-vest",
    ["items/armor_whirlplate.png"] = "snake-spiral",
    ["items/mail_of_the_unappeased.png"] = "chest-armor",
    ["items/mailpiercer.png"] = "spotted-arrowhead",
    ["items/utility_brawlers_bandolier.png"] = "fist",
    ["items/utility_aegis_of_the_oath.png"] = "shield",
    ["items/wardens_oath.png"] = "lorc/winged-shield",
    ["items/weapon_throughline.png"] = "spear-hook",
    ["items/kingsfall.png"] = "crown-coin",
    ["items/demon_bane.png"] = "daemon-skull",
    ["items/maw_of_the_unfed.png"] = "bull-horns",
    ["items/stillhunter.png"] = "lorc/dead-eye",
    ["items/sunderers_answer.png"] = "lorc/shattered-sword",
    ["items/quarrys_answer.png"] = "broken-shield",
    ["items/wolfs_portion.png"] = "wolf-head",
    ["items/whitening.png"] = "lorc/crystalize",

    -- ---------------------------------------------------------- consumables
    ["items/consumable_elixir_of_heroism.png"] = "lorc/square-bottle",
    ["items/consumable_elixir_of_the_adept.png"] = "lorc/corked-tube",
    ["items/alchemists_reservoir.png"] = "round-potion",
    ["items/alchemic_mastery.png"] = "lorc/erlenmeyer",
    ["items/long_fuse_reagent.png"] = "lorc/unlit-bomb",
    ["items/sig_aqua_vitae.png"] = "health-potion",
    ["items/demonic_essence.png"] = "lorc/gooey-daemon",
    ["items/bloodstone_focus.png"] = "crystal-cluster",
    ["items/sig_overflowing_focus.png"] = "crystal-ball",
    ["items/emberwand.png"] = "wizard-staff",
    ["items/censer_red_hour.png"] = "lorc/fire-bowl",
    ["items/reliquary_unbidden.png"] = "jeweled-chalice",
    ["items/sig_reliquary_kept_trust.png"] = "delapouite/amphora",
    ["items/utility_spirit_fetish.png"] = "totem",
    ["items/conductor.png"] = "lorc/focused-lightning",
    ["items/avalanche.png"] = "falling-rocks",
    ["items/nightjar.png"] = "caro-asercion/barn-owl",

    -- --------------------------------------------- ledgers, oaths and tempo
    -- The Ledger line is bookkeeping made into a weapon; it reads as tallies and verdicts.
    ["items/forty_one_marks.png"] = "tally-mark-5",
    ["items/long_count.png"] = "abacus",
    ["items/names_he_kept.png"] = "tied-scroll",
    ["items/struck_name.png"] = "lorc/cross-mark",
    ["items/relief_order.png"] = "lorc/papers",
    ["items/second_utterance.png"] = "lorc/conversation",
    -- The ABILITY of the same name (the charm above banks the free cast for its bearer; this one hands it
    -- to an ally). Matched to the charm on purpose: one word, one picture, wherever it is granted from.
    ["items/ability_second_utterance.png"] = "lorc/sonic-shout",
    -- The hand that would have reached to help, refused. The matcher guesses "hand", which reads as a
    -- grab; what this ability does is REFUSE one working, so the interdiction sign is the closer idea.
    ["items/ability_sealed_hand.png"] = "interdiction",
    ["items/slow_verdict.png"] = "delapouite/banging-gavel",
    ["items/reapers_due.png"] = "lorc/scythe",
    ["items/tempo_debt.png"] = "lorc/sands-of-time",
    ["items/utility_hour_returned.png"] = "lorc/cycle",
    ["items/first_motion.png"] = "sprint",
    ["items/the_stillness.png"] = "meditation",
    ["items/attunement.png"] = "aura",

    -- ------------------------------------------------- knacks and resolves
    -- Traits and passives: the picture has to say "a body that has learned something".
    ["items/adrenal_surge.png"] = "muscle-up",
    ["items/endurance.png"] = "lorc/strong",
    ["items/toughness.png"] = "brutal-helm",
    ["items/tempered_gut.png"] = "muscle-fat",
    ["items/feral_instinct.png"] = "claws",
    ["items/duelists_reflex.png"] = "lorc/crossed-sabres",
    ["items/utility_duelists_poise.png"] = "lorc/master-of-arms",
    ["items/survivors_reflex.png"] = "bandage-roll",
    ["items/veterans_resolve.png"] = "ribbon-medal",
    ["items/utility_reprisal.png"] = "lorc/return-arrow",
    ["items/vanishing_act.png"] = "lorc/magic-lamp",
    ["items/trap_sense.png"] = "wolf-trap",

    -- ------------------------------------------- review pass, 2026-07-23
    -- Found by reading all 409 auto-matches. The register blocklist in icon_map.lua caught the
    -- systematic failures (bowling strikes, mug shots, lab coats); these are what survived it --
    -- individually plausible matches that are simply about the wrong thing.

    -- "mana" is a substring of "manacles", which is how a mana drain became a pair of handcuffs.
    ["items/ability_drain_mana.png"] = "magic-swirl",
    -- "storm" kept landing on `book-storm`: flying books, for a meteor shower.
    ["items/ability_thunder_storm.png"] = "lightning-storm",
    ["items/ability_meteor_storm.png"] = "burning-meteor",
    ["items/ability_gagging_storm.png"] = "poison-gas",
    ["items/ability_grasping_hollow.png"] = "grab", -- was `hollow-cat`, an actual cat
    ["items/censer_grasping_hollow.png"] = "incense",

    -- A bell should be a bell. `bell-shield` is a shield with a bell on it.
    ["items/answering_bell.png"] = "ringing-bell",
    ["items/debt_bell.png"] = "delapouite/ringing-alarm",
    ["items/gathering_bell.png"] = "delapouite/church",
    ["items/rimebell.png"] = "lorc/carillon",

    -- `stone-bridge` is a bridge. These are stones held in a hand.
    ["items/fire_stone.png"] = "delapouite/fire-gem",
    ["items/focus_stone.png"] = "lorc/emerald",
    ["items/philosophers_stone.png"] = "lorc/saphir",
    ["items/throwing_stone.png"] = "lorc/rock",

    -- `hammer-break` is a hammer breaking something -- right for the ability, wrong for the weapon.
    ["items/bell_hammer.png"] = "warhammer",
    ["items/bellfounders_hammer.png"] = "lorc/anvil",
    ["items/frostfall_hammer.png"] = "lorc/stone-crafting",
    ["items/mired_maul.png"] = "lorc/quake-stomp",
    ["items/sleepers_maul.png"] = "lorc/wrecking-ball",
    ["items/splitting_maul.png"] = "caro-asercion/froe-and-mallet",
    ["items/tinkers_maul.png"] = "lorc/tinker",
    ["items/anvil_of_the_ninth.png"] = "anvil-impact",

    ["items/mana_wellspring.png"] = "water-fountain", -- was `spring`, a coil
    ["items/weapon_confessors_needle.png"] = "stiletto", -- a thin blade, not `needle-jaws`
    ["items/ability_updraft.png"] = "wind-hole",
    ["items/hollow_arc.png"] = "energy-arrow",
    ["items/utility_gleaning_rod.png"] = "lorc/wheat",
    ["items/utility_stormglass_rod.png"] = "lorc/lightning-helix",
    ["items/marksmans_lens.png"] = "spyglass",
    ["items/armor_rimeguard.png"] = "ice-shield",

    -- A straw sentry IS a scarecrow; the emplaced one is its built cousin.
    ["items/ability_straw_sentry.png"] = "scarecrow",
    ["items/ability_emplace_sentry.png"] = "watchtower",

    -- ------------------------------------------------- the multiclass shelves
    -- The 21 multiclasses taken to five items each (docs/disciplines-plan.md). Almost every one of
    -- these named an IDEA rather than an object -- "the long wait", "a vow of the march", "crowd's
    -- favour" -- which is exactly the case this file exists for, and why 31 of them scored zero
    -- against all 3953 icons rather than matching something wrong.
    --
    -- The rule followed throughout: draw the MECHANIC, not the title. An item called Contagion is
    -- easier to recognise as a virus than as anything with the word "contagion" in it, and a player
    -- reading an inventory is looking for what a thing does.

    -- Champion, Duelist, Crusader -- the charge shelves.
    ["items/ability_defiant_stand.png"] = "lorc/spartan",        -- the taunt is the visible half
    ["items/utility_crowds_favour.png"] = "laurels",         -- the arena's approval, banked
    ["items/ability_coup_droit.png"] = "knife-thrust",       -- the straight thrust down the centre
    ["items/ability_reckoning.png"] = "hammer-drop",         -- the account, closed in one motion
    ["items/utility_vow_of_the_march.png"] = "lorc/footprint", -- a vow the whole column marches under
    ["items/armor_crusaders_tabard.png"] = "armor-vest",     -- no tabard in the set; the body worn

    -- Warden, Vanguard, Ninja, Poacher.
    ["items/utility_wardens_writ.png"] = "scroll-unfurled",  -- a border is a document before it is a line
    ["items/utility_marchstone.png"] = "menhir",             -- the parish stone, pried up and walking
    ["items/utility_breakers_wedge.png"] = "gears",          -- the shove turned into a breach
    ["items/utility_substitution.png"] = "body-swapping",    -- the clone takes the blow and the tile
    ["items/ability_scatterlight.png"] = "mirror-mirror",    -- three doubles, one of them yours
    ["items/utility_quarrys_due.png"] = "target-shot",       -- the trap paints what it catches
    ["items/ability_throatcut.png"] = "backstab",            -- no cut-throat in the set; the nearest verb
    ["items/utility_the_long_wait.png"] = "delapouite/pendulum-swing",       -- patience, which is the whole item

    -- Paladin, Plague Knight, Theurge, Apothecary.
    ["items/ability_oathkeepers_litany.png"] = "prayer",     -- said FOR somebody, not over them
    ["items/utility_contagion.png"] = "virus",               -- draw the mechanic, not the word
    ["items/ability_benediction.png"] = "holy-symbol",       -- the blessing that reaches everyone
    ["items/consumable_the_tithe.png"] = "chalice-drops",    -- a tenth of everything, collected

    -- Skirmisher, Battlemage, Spellbreaker, Warbrewer.
    ["items/utility_arcane_conduit.png"] = "lorc/ringed-beam",    -- the aura that costs something
    ["items/utility_battle_casting.png"] = "delapouite/bolt-spell-cast",   -- sorcery thrown at arm's length
    ["items/utility_dampening_oath.png"] = "silence",        -- a tax on the incantation
    ["items/utility_spell_eater.png"] = "carnivore-mouth",   -- absorption, said unsubtly
    ["items/utility_field_still.png"] = "bubbling-flask",    -- the supply line, strapped to a back

    -- Herbalist, Artificer, Inquisitor, Saboteur.
    ["items/ability_distil.png"] = "potion-ball",            -- ground rendered into a vial
    ["items/consumable_wildcraft_reagent.png"] = "herbs-bundle", -- what field crafting produces
    ["items/utility_totem_carvers_kit.png"] = "chisel",      -- green wood, and no hurry
    ["items/ability_recall_construct.png"] = "lorc/cogsplosion",    -- unmade and rebuilt, not carried
    ["items/ability_sentence.png"] = "gavel",                -- judgment before the fire
    ["items/ability_the_question.png"] = "handcuffs",        -- the asking, not the answer

    -- Corrections to auto-matches that found the WRONG SENSE of a right word. Four of the icons
    -- involved are now blocked outright (tools/icon_map.lua) so they cannot take anything else; these
    -- are the replacements, plus a handful where the guess was merely weak rather than wrong.
    ["items/ability_beat_the_bounds.png"] = "stone-path",    -- a parish boundary, walked
    ["items/ability_ley_line.png"] = "lorc/interstellar-path",           -- the line between two standing stones
    ["items/consumable_sappers_line.png"] = "land-mine",     -- a line of charges, not a race
    ["items/utility_salvage_rig.png"] = "lorc/mechanical-arm",             -- wreckage worth having
    ["items/utility_cullers_kit.png"] = "meat-cleaver",      -- it renders bodies down, it does not heal
    ["items/ability_bring_it_down.png"] = "demolish",        -- the verb, not the gesture
    ["items/ability_field_assembly.png"] = "clockwork",      -- built in the field, out of the satchel
    ["items/utility_round_for_the_house.png"] = "beer-stein", -- a round, not a building
    ["items/utility_ancestor_mask.png"] = "tribal-mask",     -- an ancestor, not a bat
    ["items/ability_answering_blow.png"] = "sword-spin",     -- the turn with the blade out
    ["items/ability_shadow_trade.png"] = "shadow-follower",  -- trading places with your own double
    ["items/utility_reading_the_blade.png"] = "lorc/magnifying-glass", -- watching the shoulder, not the sword
    -- A gullet, not a blow. The guesser dry-runs the effect and this one reads a live
    -- expedition's haul, which is nought in a composer -- so it deals nothing, reports nothing,
    -- and lands on the flask. What it IS is a thing that holds what you put in it.
    ["items/utility_still_hungry.png"] = "swallower",
    ["items/consumable_borrowed_hands.png"] = "drink-me",    -- an elixir; Lay On Hands keeps the hands

    -- Collateral, and then some housekeeping. Blocking `aid` cost the Snare Stake Kit the icon it had
    -- been quietly holding (`first-aid-kit` -- a kit is a kit to a substring matcher), so it is named
    -- here properly. The five below it were already unmatched before this pass and are cheap to close
    -- while the vocabulary is open.
    ["items/snare_stake_kit.png"] = "stakes-fence",          -- a bundle of stakes, which is what it is
    ["items/ability_flurry.png"] = "high-punch",             -- three bare-handed blows
    ["items/ability_sap.png"] = "wood-club",                 -- the quiet end of a thief's argument
    ["items/ability_shakedown.png"] = "coins",               -- what a shakedown is actually for
    ["items/flung_quills.png"] = "porcupine",                -- the creature the volley comes off
    -- consumable_war_drums stays unmatched on purpose: `drum` is blocklisted (the set's drums are a
    -- modern kit), and a war drum deserves real art rather than a percussion icon in the wrong register.

    -- ------------------------------------------- vocabulary pass, 2026-08-25
    -- Written while the composer GATED this file -- a glyph reached the renderer only if a declared
    -- vocabulary held it, so an entry naming anything else drew nothing. That gate is gone (the
    -- uniqueness pass below), and every slug named here reaches the renderer now.
    --
    -- The dozen below outlive it unchanged, because what they were correcting was never the gate: the
    -- fall-through simply read them wrong. A thrown flask is not a blast, a net is not a curse, and
    -- wine is not a ward.
    ["items/fire_bomb.png"] = "lorc/sparky-bomb",          -- the thrown-flask family, not a bare explosion
    ["items/ice_bomb.png"] = "lorc/snow-bottle",
    ["items/ball_bearings.png"] = "stone-sphere",    -- scattered underfoot; `marbles` is off the shelf
    ["items/spiteful_caltrops.png"] = "lorc/barbed-nails",     -- ground denial, which is what a trap glyph says
    ["items/net.png"] = "mantrap",                   -- a snare, not a hex
    ["items/scent_marker.png"] = "rune-stone",       -- a mark left on the ground
    ["items/wine.png"] = "lorc/wine-glass",             -- a drink is a drink
    ["items/consumable_elixir_of_the_giant.png"] = "delapouite/strong-man",
    ["items/revive_scroll.png"] = "delapouite/papyrus",
    -- War drums were left unmatched above on the reasoning that no icon beats a wrong one. There is no
    -- such thing as no icon any more -- an unmatched consumable composes on a shape some sibling is
    -- already drawing, which is a red spec -- so it takes the rally, and the note above still holds for
    -- why it is not a drum.
    ["items/consumable_war_drums.png"] = "knight-banner",

    -- ------------------------------------------- the skeleton aspect, 2026-09-20
    -- The one item whose whole content is what the BEARER becomes, so a charm glyph says the one thing
    -- about it that is not true: that it is a thing you carry. `skeleton-inside` is literally the
    -- aspect, a body drawn with the bones showing through.
    ["items/marrowlight.png"] = "skeleton-inside",

    -- ---------------------------------------------------------------- props
    -- Board furniture. These sit on the terrain layer rather than the character layer, so an
    -- iconic treatment is the right register -- see the two-register rule in docs/art-assets.md.
    ["props/crate.png"] = "cargo-crate",
    ["props/explosive_barrel.png"] = "barrel",

    -- ------------------------------------------------------------ materials
    ["materials/iron_scrap.png"] = "metal-bar",
    ["materials/steel_ingot.png"] = "delapouite/i-beam",
    ["materials/mythril.png"] = "lorc/crystal-bars",

    -- ------------------------------- the uniqueness pass, 2026-09-20
    -- Two items may no longer draw the same silhouette (docs/art-assets.md, "One item,
    -- one silhouette"), and these are the assets the matcher could not seat on its own.
    -- Every one of them lost its picture the same way: the shape its name reaches for was
    -- claimed by an asset that reaches for it harder, and nothing was left underneath but
    -- a category shape it would have had to share. So each is a decision rather than a
    -- guess -- the MECHANIC drawn, not the title, which is this file's standing rule.

    -- abilities whose name is a verb, not an object
    ["items/ability_anathema.png"]               = "lorc/cursed-star",
    ["items/ability_call_spirit.png"]            = "lorc/haunting",
    ["items/ability_call_the_court.png"]         = "lorc/stone-throne",
    ["items/ability_carved_stake.png"]           = "lorc/stick-splitting",
    ["items/ability_charge.png"]                 = "delapouite/cavalry",
    ["items/ability_cleave.png"]                 = "lorc/sword-slice",
    ["items/ability_consecrate.png"]             = "delapouite/star-altar",
    ["items/ability_corrosive_touch.png"]        = "lorc/acid-blob",
    ["items/ability_early_rites.png"]            = "lorc/lit-candelabra",
    ["items/ability_engulf.png"]                 = "lorc/flaming-sheet",
    ["items/ability_gore.png"]                   = "lorc/boar-tusks",
    ["items/ability_grease_palms.png"]           = "delapouite/pay-money",
    ["items/ability_greater_rite.png"]           = "lorc/pentagram-rose",
    ["items/ability_haste.png"]                  = "lorc/wingfoot",
    ["items/ability_invocation.png"]             = "lorc/glowing-hands",
    ["items/ability_lay_the_hex.png"]            = "lorc/voodoo-doll",
    ["items/ability_ledgers_due.png"]            = "delapouite/archive-register",
    ["items/ability_lesser_rite.png"]            = "lorc/candle-flame",
    ["items/ability_march_wardens_standard.png"] = "lorc/flying-flag",
    ["items/ability_rebind.png"]                 = "lorc/wavy-chains",
    ["items/ability_rend.png"]                   = "lorc/triple-scratches",
    ["items/ability_renewal_banner.png"]         = "delapouite/tower-flag",
    ["items/ability_revive.png"]                 = "lorc/defibrilate",
    ["items/ability_sacred_banner.png"]          = "delapouite/star-flag",
    ["items/ability_safeguard.png"]              = "lorc/surrounded-shield",
    ["items/ability_seal_dark.png"]              = "lorc/eclipse",
    ["items/ability_snare_stake.png"]            = "lorc/tripwire",
    ["items/ability_stilled_hour.png"]           = "lorc/sundial",
    ["items/ability_stillshade.png"]             = "lorc/two-shadows",
    ["items/ability_swailing.png"]               = "lorc/wildfires",
    ["items/ability_the_taking.png"]             = "lorc/snatch",
    ["items/ability_transfusion.png"]            = "lorc/life-tap",
    ["items/ability_understudy.png"]             = "lorc/puppet",
    ["items/ability_vanishing_strike.png"]       = "lorc/hidden",
    ["items/ability_vital_points.png"]           = "lorc/anatomy",

    -- armour -- a coat, a hide, a habit; the shelf the family shape used to cover
    ["items/armor_bristlehide.png"]        = "lorc/dorsal-scales",
    ["items/armor_censer_cloth_habit.png"] = "lorc/cowled",
    ["items/armor_ichor_coat.png"]         = "lorc/dripping-goo",
    ["items/armor_interceding_stole.png"]  = "delapouite/roman-toga",
    ["items/armor_mirrorsilk.png"]         = "delapouite/rolled-cloth",
    ["items/armor_rally_coat.png"]         = "delapouite/moncler-jacket",
    ["items/armor_reliquary_mantle.png"]   = "delapouite/cape",
    ["items/armor_robes_unbidden.png"]     = "delapouite/ample-dress",
    ["items/armor_runners_hide.png"]       = "delapouite/travel-dress",
    ["items/armor_sealed_coat.png"]        = "delapouite/poncho",
    ["items/armor_second_chance_vest.png"] = "delapouite/life-jacket",
    ["items/armor_slipstep_leathers.png"]  = "delapouite/sleeveless-jacket",
    ["items/armor_smoke_mantle.png"]       = "lorc/heat-haze",
    ["items/armor_smokecloth_wrap.png"]    = "delapouite/bandana",
    ["items/armor_stalkers_pelt.png"]      = "delapouite/ermine",
    ["items/armor_unravelling_habit.png"]  = "delapouite/sewing-string",

    -- the rest, alphabetically by the file they draw
    ["items/bared_nerve.png"]                      = "lorc/brain-stem",
    ["items/beckoning_bough.png"]                  = "lorc/tree-branch",
    ["items/boots_of_speed.png"]                   = "delapouite/sonic-shoes",
    ["items/censer.png"]                           = "lorc/lantern",
    ["items/censer_mustered.png"]                  = "lorc/lantern-flame",
    ["items/censer_unravelling.png"]               = "lorc/candle-holder",
    ["items/centering_charm.png"]                  = "lorc/concentration-orb",
    ["items/codex_of_hubris.png"]                  = "lorc/evil-book",
    ["items/codex_unanswered.png"]                 = "lorc/open-book",
    ["items/common_burden.png"]                    = "lorc/knapsack",
    ["items/consecration.png"]                     = "lorc/sunbeams",
    ["items/consumable_berserkers_brew.png"]       = "lorc/fire-bottle",
    ["items/consumable_bitterroot_draught.png"]    = "lorc/spiral-bottle",
    ["items/consumable_crawler_mucus.png"]         = "lorc/vile-fluid",
    ["items/consumable_plaguebearers_draught.png"] = "lorc/overdose",
    ["items/consumable_wildcraft_poultice.png"]    = "lorc/three-leaves",
    ["items/cutpurse_nip.png"]                     = "lorc/curvy-knife",
    ["items/cutpurse_tally.png"]                   = "lorc/dozen",
    ["items/dawn_chrism.png"]                      = "lorc/sunrise",
    ["items/decoy.png"]                            = "lorc/target-dummy",
    ["items/deep_larder.png"]                      = "delapouite/cellar-barrels",
    ["items/distended_hide.png"]                   = "lorc/armoured-shell",
    ["items/drift_touch.png"]                      = "lorc/icicles-aura",
    ["items/gilded_standard.png"]                  = "lorc/winged-emblem",
    ["items/gilt_maw.png"]                         = "lorc/gluttonous-smile",
    ["items/glutted_bulk.png"]                     = "lorc/gluttony",
    ["items/gluttons_purse.png"]                   = "lorc/bloody-stash",
    ["items/hexbrand.png"]                         = "lorc/skull-signet",
    ["items/hoarfrost_antlers.png"]                = "lorc/stag-head",
    ["items/homunculus_fists.png"]                 = "lorc/metal-hand",
    ["items/intercessors_staff.png"]               = "delapouite/bird-scepter",
    ["items/jealous_resin.png"]                    = "lorc/dripping-honey",
    ["items/kept_vigil.png"]                       = "lorc/candlebright",
    ["items/let_it_spread.png"]                    = "lorc/biohazard",
    ["items/long_dark.png"]                        = "lorc/night-sky",
    ["items/long_wait.png"]                        = "lorc/heavy-timer",
    ["items/marginal_gloss.png"]                   = "lorc/quill-ink",
    ["items/martyrs_icon.png"]                     = "lorc/stigmata",
    ["items/odds_against.png"]                     = "delapouite/rolling-dices",
    ["items/oil_flask.png"]                        = "lorc/molotov",
    ["items/opportunists_charm.png"]               = "lorc/clover",
    ["items/overchannelled_staff.png"]             = "lorc/rolling-energy",
    ["items/overdraft.png"]                        = "delapouite/expense",
    ["items/overreach.png"]                        = "lorc/grasping-claws",
    ["items/padded_vest.png"]                      = "lorc/lamellar",
    ["items/panacea.png"]                          = "lorc/miracle-medecine",
    ["items/parasitic_staff.png"]                  = "lorc/leeching-worm",
    ["items/petal_touch.png"]                      = "lorc/twirly-flower",
    ["items/pseudopod.png"]                        = "lorc/curled-tentacle",
    ["items/quenchless_gut.png"]                   = "lorc/mouth-watering",
    ["items/renewal_staff.png"]                    = "lorc/sprout",
    ["items/reviving_salts.png"]                   = "lorc/powder",
    ["items/riftline.png"]                         = "lorc/earth-crack",
    ["items/rooted_oath.png"]                      = "delapouite/tree-roots",
    ["items/sealed_censer.png"]                    = "delapouite/covered-jar",
    ["items/sig_borrowed_pelt.png"]                = "lorc/fox-head",
    ["items/sig_court_kept_waiting.png"]           = "lorc/queen-crown",
    ["items/sig_marching_vow.png"]                 = "lorc/boot-prints",
    ["items/sig_mother_vat.png"]                   = "lorc/cauldron",
    ["items/sig_patient_line.png"]                 = "lorc/wavy-itinerary",
    ["items/sig_quiet_errand.png"]                 = "lorc/envelope",
    ["items/sig_rite_unspoken.png"]                = "delapouite/mute",
    ["items/sig_sealed_bell.png"]                  = "delapouite/gong",
    ["items/sig_second_leash.png"]                 = "lorc/spiked-collar",
    ["items/sig_second_reading.png"]               = "lorc/bookmark",
    ["items/sig_standing_order.png"]               = "lorc/stone-tablet",
    ["items/sig_the_wedge.png"]                    = "lorc/striking-splinter",
    ["items/sig_unbroken_vigil.png"]               = "lorc/candle-light",
    ["items/sig_written_charge.png"]               = "lorc/folded-paper",
    ["items/slipchain_charm.png"]                  = "lorc/crossed-chains",
    ["items/stamina_potion.png"]                   = "lorc/heart-bottle",
    ["items/swift_fist.png"]                       = "lorc/punch",
    ["items/tallow_maw.png"]                       = "lorc/candle-skull",
    ["items/the_gallery.png"]                      = "delapouite/theater-curtains",
    ["items/the_reckoning.png"]                    = "lorc/law-star",
    ["items/trackless_boots.png"]                  = "lorc/barefoot",
    ["items/underbite.png"]                        = "lorc/toad-teeth",
    ["items/unidentified_ability.png"]             = "lorc/uncertainty",
    ["items/unidentified_utility.png"]             = "lorc/jigsaw-piece",
    ["items/unpaid_tithe.png"]                     = "lorc/cash",
    ["items/utility_careful_sigil.png"]            = "lorc/moebius-star",
    ["items/utility_charnel_reliquary.png"]        = "lorc/skull-in-jar",
    ["items/utility_crimson_standard.png"]         = "lorc/black-flag",
    ["items/utility_distant_sigil.png"]            = "lorc/moebius-trefoil",
    ["items/utility_greyveil_cloak.png"]           = "delapouite/fog",
    ["items/utility_miasma_flask.png"]             = "lorc/fizzing-flask",
    ["items/utility_miasmal_plate.png"]            = "lorc/plate-claw",
    ["items/utility_quickened_sigil.png"]          = "lorc/star-swirl",
    ["items/utility_reliquary_of_tallies.png"]     = "delapouite/archive-research",
    ["items/utility_resonant_grip.png"]            = "lorc/resonance",
    ["items/utility_sealed_reliquary.png"]         = "lorc/triple-lock",
    ["items/utility_shared_ledger.png"]            = "lorc/trade",
    ["items/utility_skirmishers_momentum.png"]     = "lorc/run",
    ["items/utility_spiteful_ichor.png"]           = "lorc/splurt",
    ["items/utility_stripped_plate.png"]           = "lorc/slashed-shield",
    ["items/utility_swailing_brand.png"]           = "delapouite/primitive-torch",
    ["items/utility_the_turned_hide.png"]          = "lorc/sewed-shell",
    ["items/utility_the_turned_year.png"]          = "lorc/star-cycle",
    ["items/utility_the_year_behind_her.png"]      = "delapouite/calendar",
    ["items/utility_the_yearling_pelt.png"]        = "caro-asercion/deer",
    ["items/utility_twinned_sigil.png"]            = "lorc/duality",
    ["items/utility_unbroken_surface.png"]         = "lorc/shieldcomb",
    ["items/vampiric_strike.png"]                  = "lorc/dripping-knife",
    ["items/vitreous_bite.png"]                    = "lorc/pretty-fangs",
    ["items/vitriol_wand.png"]                     = "lorc/chemical-bolt",
    ["items/wardens_longbow.png"]                  = "lorc/bowman",
    ["items/weapon_harriers_bow.png"]              = "lorc/broadhead-arrow",
    ["items/weapon_litany_staff.png"]              = "lorc/ankh",
    ["items/weapon_main_gauche.png"]               = "lorc/bowie-knife",
    ["items/whetted_vow.png"]                      = "lorc/sword-smithing",
    ["items/yoked_company.png"]                    = "delapouite/heavy-collar",
    ["materials/banked_cinder.png"]                = "lorc/thrown-charcoal",
    ["materials/ember_slag.png"]                   = "delapouite/melting-metal",
    ["materials/gorge_ivory.png"]                  = "lorc/tooth",
    ["materials/gutter_silver.png"]                = "lorc/metal-disc",
    ["materials/leyglass.png"]                     = "lorc/floating-crystal",
    ["materials/margin_gilt.png"]                  = "lorc/gold-shell",
    ["materials/votive_ash.png"]                   = "lorc/unlit-candelabra",
    ["traps/snare_stake.png"]                      = "lorc/spiked-fence",

    -- ------------------------------------------- the naga shelf, 2026-09-20
    -- Six assets the mapper could not seat: five of them name water or a body that moves through it,
    -- which is a register game-icons covers well but not with the words these use.
    ["items/gillscale_wrap.png"]   = "delapouite/fish-scales",  -- scaled skin, worn
    ["items/naga_coils.png"]       = "lorc/coiling-curl",       -- the body itself, wound
    ["items/riptide.png"]          = "delapouite/low-tide",     -- water pulling AWAY, which is the ability
    ["items/breaker.png"]          = "delapouite/high-tide",    -- ... and water arriving, its mirror
    -- The rest of the shelf, hand-seated because the matcher read the WORDS rather than the objects:
    -- a scale hauberk went to a kitchen scale, rising water to a water flask, and a pike to a spikeball.
    ["items/scale_hauberk.png"]    = "lorc/scale-mail",         -- plates, sewn to a backing
    ["items/rising_water.png"]     = "lorc/water-splash",       -- the board going under
    ["items/undertow_pike.png"]    = "lorc/harpoon-chain",      -- a point that brings something back
    ["items/brine_bolt.png"]       = "lorc/droplet-splash",     -- a fistful of the channel, thrown
    ["items/brackish_lance.png"]   = "lorc/harpoon-trident",    -- the fen's own spear
    ["items/silt_knife.png"]       = "lorc/bone-knife",         -- something's jawbone, ground down
    ["items/utility_the_wake.png"] = "lorc/splashy-stream",     -- what a body leaves behind it
    ["items/armor_cutpurse_coat.png"] = "delapouite/hoodie",      -- a thief wears the hood

    -- ------------------------------- the Ancient Stag, 2026-09-21
    -- Five pieces off data/characters/character_stag_beast.lua. The matcher had four of them on
    -- clashes or on word-matches that mean the wrong thing -- "The Lowered Crown" drew a jewelled
    -- crown and "The Close Herd" drew a closed door -- which is exactly the case this file exists for.
    ["items/stag_antlers.png"]            = "lorc/horned-skull",      -- grown from the skull, as the blueprint says
    ["items/herd_warmth.png"]             = "delapouite/deer-track",  -- the herd, read off the ground it stood on
    ["items/utility_the_close_herd.png"]  = "delapouite/meeple-group", -- bodies standing shoulder to shoulder
    ["items/utility_lowered_crown.png"]   = "delapouite/charging-bull", -- head down, points forward: the lift
    -- The hide is the weak one of the five and is worth revisiting. Every literal hide glyph in the
    -- vendored set is already spoken for (animal-hide on the Ravener's, dorsal-scales on the boar's,
    -- leather-vest on the Quarryhide), and this family already picks for CHARACTER rather than
    -- material -- the Runner's Hide draws a travel dress. A heavy-shouldered ungulate is the nearest
    -- free thing to "cut from the shoulders, where every autumn is stacked up in layers".
    ["items/armor_bellowhide.png"]        = "delapouite/bison",
}
