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
    ["items/ability_mana_sunder.png"] = "disintegrate",
    ["items/ability_mark_of_heresy.png"] = "crown-of-thorns",
    ["items/ability_mirror_image.png"] = "invisible",
    ["items/ability_muster_rift.png"] = "portal",
    ["items/ability_not_yet.png"] = "stopwatch",
    ["items/ability_omnislash.png"] = "crossed-swords",
    ["items/ability_overcharge.png"] = "energise",
    ["items/ability_polymorph.png"] = "transform",
    ["items/ability_provoke.png"] = "shouting",
    ["items/ability_scouring_mercy.png"] = "bleeding-wound",
    ["items/ability_set_charge.png"] = "smoke-bomb",
    ["items/ability_single_combat.png"] = "duel",
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
    ["items/armor_choking_apron.png"] = "poison-gas",
    ["items/armor_everdraught_bandolier.png"] = "round-potion",
    ["items/armor_quarryhide.png"] = "leather-vest",
    ["items/armor_whirlplate.png"] = "snake-spiral",
    ["items/mail_of_the_unappeased.png"] = "chest-armor",
    ["items/mailpiercer.png"] = "spotted-arrowhead",
    ["items/utility_brawlers_bandolier.png"] = "fist",
    ["items/utility_aegis_of_the_oath.png"] = "shield",
    ["items/wardens_oath.png"] = "shield",
    ["items/weapon_throughline.png"] = "spear-hook",
    ["items/kingsfall.png"] = "crown-coin",
    ["items/demon_bane.png"] = "daemon-skull",
    ["items/maw_of_the_unfed.png"] = "bull-horns",
    ["items/stillhunter.png"] = "spotted-arrowhead",
    ["items/sunderers_answer.png"] = "sword-break",
    ["items/quarrys_answer.png"] = "broken-shield",
    ["items/wolfs_portion.png"] = "wolf-head",
    ["items/whitening.png"] = "frostfire",

    -- ---------------------------------------------------------- consumables
    ["items/consumable_elixir_of_heroism.png"] = "round-potion",
    ["items/consumable_elixir_of_the_adept.png"] = "magic-potion",
    ["items/alchemists_reservoir.png"] = "round-potion",
    ["items/alchemic_mastery.png"] = "magic-swirl",
    ["items/long_fuse_reagent.png"] = "smoke-bomb",
    ["items/sig_aqua_vitae.png"] = "health-potion",
    ["items/ball_bearings.png"] = "marbles",
    ["items/demonic_essence.png"] = "daemon-skull",
    ["items/bloodstone_focus.png"] = "crystal-cluster",
    ["items/sig_overflowing_focus.png"] = "crystal-ball",
    ["items/emberwand.png"] = "wizard-staff",
    ["items/censer_red_hour.png"] = "incense",
    ["items/reliquary_unbidden.png"] = "jeweled-chalice",
    ["items/sig_reliquary_kept_trust.png"] = "jeweled-chalice",
    ["items/utility_spirit_fetish.png"] = "totem",
    ["items/conductor.png"] = "lightning-arc",
    ["items/avalanche.png"] = "falling-rocks",
    ["items/nightjar.png"] = "moon-bats",

    -- --------------------------------------------- ledgers, oaths and tempo
    -- The Ledger line is bookkeeping made into a weapon; it reads as tallies and verdicts.
    ["items/forty_one_marks.png"] = "tally-mark-5",
    ["items/long_count.png"] = "abacus",
    ["items/names_he_kept.png"] = "tied-scroll",
    ["items/struck_name.png"] = "tied-scroll",
    ["items/relief_order.png"] = "tied-scroll",
    ["items/second_utterance.png"] = "shouting",
    -- The ABILITY of the same name (the charm above banks the free cast for its bearer; this one hands it
    -- to an ally). Matched to the charm on purpose: one word, one picture, wherever it is granted from.
    ["items/ability_second_utterance.png"] = "shouting",
    -- The hand that would have reached to help, refused. The matcher guesses "hand", which reads as a
    -- grab; what this ability does is REFUSE one working, so the interdiction sign is the closer idea.
    ["items/ability_sealed_hand.png"] = "interdiction",
    ["items/slow_verdict.png"] = "gavel",
    ["items/reapers_due.png"] = "reaper-scythe",
    ["items/tempo_debt.png"] = "hourglass",
    ["items/utility_hour_returned.png"] = "backward-time",
    ["items/first_motion.png"] = "sprint",
    ["items/the_stillness.png"] = "meditation",
    ["items/attunement.png"] = "aura",

    -- ------------------------------------------------- knacks and resolves
    -- Traits and passives: the picture has to say "a body that has learned something".
    ["items/adrenal_surge.png"] = "muscle-up",
    ["items/endurance.png"] = "muscle-up",
    ["items/toughness.png"] = "brutal-helm",
    ["items/tempered_gut.png"] = "muscle-fat",
    ["items/feral_instinct.png"] = "claws",
    ["items/duelists_reflex.png"] = "duel",
    ["items/utility_duelists_poise.png"] = "duel",
    ["items/survivors_reflex.png"] = "bandage-roll",
    ["items/veterans_resolve.png"] = "ribbon-medal",
    ["items/utility_reprisal.png"] = "sword-break",
    ["items/vanishing_act.png"] = "invisible",
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
    ["items/debt_bell.png"] = "ringing-bell",
    ["items/gathering_bell.png"] = "ringing-bell",
    ["items/rimebell.png"] = "ringing-bell",

    -- `stone-bridge` is a bridge. These are stones held in a hand.
    ["items/fire_stone.png"] = "stone-sphere",
    ["items/focus_stone.png"] = "stone-sphere",
    ["items/philosophers_stone.png"] = "stone-sphere",
    ["items/throwing_stone.png"] = "stone-sphere",

    -- `hammer-break` is a hammer breaking something -- right for the ability, wrong for the weapon.
    ["items/bell_hammer.png"] = "warhammer",
    ["items/bellfounders_hammer.png"] = "warhammer",
    ["items/frostfall_hammer.png"] = "warhammer",
    ["items/mired_maul.png"] = "warhammer",
    ["items/sleepers_maul.png"] = "warhammer",
    ["items/splitting_maul.png"] = "warhammer",
    ["items/tinkers_maul.png"] = "warhammer",
    ["items/anvil_of_the_ninth.png"] = "anvil-impact",

    ["items/mana_wellspring.png"] = "water-fountain", -- was `spring`, a coil
    ["items/weapon_confessors_needle.png"] = "stiletto", -- a thin blade, not `needle-jaws`
    ["items/ability_updraft.png"] = "wind-hole",
    ["items/hollow_arc.png"] = "energy-arrow",
    ["items/utility_gleaning_rod.png"] = "wizard-staff",
    ["items/utility_stormglass_rod.png"] = "wizard-staff",
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
    ["items/ability_defiant_stand.png"] = "shouting",        -- the taunt is the visible half
    ["items/utility_crowds_favour.png"] = "laurels",         -- the arena's approval, banked
    ["items/ability_coup_droit.png"] = "knife-thrust",       -- the straight thrust down the centre
    ["items/ability_reckoning.png"] = "hammer-drop",         -- the account, closed in one motion
    ["items/utility_vow_of_the_march.png"] = "knight-banner", -- a vow the whole column marches under
    ["items/armor_crusaders_tabard.png"] = "armor-vest",     -- no tabard in the set; the body worn

    -- Warden, Vanguard, Ninja, Poacher.
    ["items/utility_wardens_writ.png"] = "scroll-unfurled",  -- a border is a document before it is a line
    ["items/utility_marchstone.png"] = "menhir",             -- the parish stone, pried up and walking
    ["items/utility_breakers_wedge.png"] = "gears",          -- the shove turned into a breach
    ["items/utility_substitution.png"] = "body-swapping",    -- the clone takes the blow and the tile
    ["items/ability_scatterlight.png"] = "mirror-mirror",    -- three doubles, one of them yours
    ["items/utility_quarrys_due.png"] = "target-shot",       -- the trap paints what it catches
    ["items/ability_throatcut.png"] = "backstab",            -- no cut-throat in the set; the nearest verb
    ["items/utility_the_long_wait.png"] = "hourglass",       -- patience, which is the whole item

    -- Paladin, Plague Knight, Theurge, Apothecary.
    ["items/ability_oathkeepers_litany.png"] = "prayer",     -- said FOR somebody, not over them
    ["items/utility_contagion.png"] = "virus",               -- draw the mechanic, not the word
    ["items/ability_benediction.png"] = "holy-symbol",       -- the blessing that reaches everyone
    ["items/consumable_the_tithe.png"] = "chalice-drops",    -- a tenth of everything, collected

    -- Skirmisher, Battlemage, Spellbreaker, Warbrewer.
    ["items/utility_arcane_conduit.png"] = "magic-swirl",    -- the aura that costs something
    ["items/utility_battle_casting.png"] = "energy-arrow",   -- sorcery thrown at arm's length
    ["items/utility_dampening_oath.png"] = "silence",        -- a tax on the incantation
    ["items/utility_spell_eater.png"] = "carnivore-mouth",   -- absorption, said unsubtly
    ["items/utility_field_still.png"] = "bubbling-flask",    -- the supply line, strapped to a back

    -- Herbalist, Artificer, Inquisitor, Saboteur.
    ["items/ability_distil.png"] = "potion-ball",            -- ground rendered into a vial
    ["items/consumable_wildcraft_reagent.png"] = "herbs-bundle", -- what field crafting produces
    ["items/utility_totem_carvers_kit.png"] = "chisel",      -- green wood, and no hurry
    ["items/ability_recall_construct.png"] = "clockwork",    -- unmade and rebuilt, not carried
    ["items/ability_sentence.png"] = "gavel",                -- judgment before the fire
    ["items/ability_the_question.png"] = "handcuffs",        -- the asking, not the answer

    -- Corrections to auto-matches that found the WRONG SENSE of a right word. Four of the icons
    -- involved are now blocked outright (tools/icon_map.lua) so they cannot take anything else; these
    -- are the replacements, plus a handful where the guess was merely weak rather than wrong.
    ["items/ability_beat_the_bounds.png"] = "stone-path",    -- a parish boundary, walked
    ["items/ability_ley_line.png"] = "stone-path",           -- the line between two standing stones
    ["items/consumable_sappers_line.png"] = "land-mine",     -- a line of charges, not a race
    ["items/utility_salvage_rig.png"] = "gears",             -- wreckage worth having
    ["items/utility_cullers_kit.png"] = "meat-cleaver",      -- it renders bodies down, it does not heal
    ["items/ability_bring_it_down.png"] = "demolish",        -- the verb, not the gesture
    ["items/ability_field_assembly.png"] = "clockwork",      -- built in the field, out of the satchel
    ["items/utility_round_for_the_house.png"] = "beer-stein", -- a round, not a building
    ["items/utility_ancestor_mask.png"] = "tribal-mask",     -- an ancestor, not a bat
    ["items/ability_answering_blow.png"] = "sword-spin",     -- the turn with the blade out
    ["items/ability_shadow_trade.png"] = "shadow-follower",  -- trading places with your own double
    ["items/utility_reading_the_blade.png"] = "cloak-dagger", -- watching the shoulder, not the sword
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
    -- The composer now GATES this file: a glyph reaches the renderer only if it is in
    -- BASE_VOCABULARY (tools/icon_compose.lua), and anything else falls through to what the ability
    -- does, or when the charm fires, or the type base. So an entry here is only worth writing when it
    -- names a slug the vocabulary holds -- `delapouite/caltrops` and `lorc/fire-bomb` are perfectly
    -- good matches that now draw nothing, because one item is not enough to buy a drawing.
    --
    -- These are the dozen the fall-through read wrong: a thrown flask is not a blast, a net is not a
    -- curse, and wine is not a ward.
    ["items/fire_bomb.png"] = "smoke-bomb",          -- the thrown-flask family, not a bare explosion
    ["items/ice_bomb.png"] = "smoke-bomb",
    ["items/ball_bearings.png"] = "stone-sphere",    -- scattered underfoot; `marbles` is off the shelf
    ["items/spiteful_caltrops.png"] = "mantrap",     -- ground denial, which is what a trap glyph says
    ["items/net.png"] = "mantrap",                   -- a snare, not a hex
    ["items/scent_marker.png"] = "rune-stone",       -- a mark left on the ground
    ["items/wine.png"] = "round-potion",             -- a drink is a drink
    ["items/consumable_elixir_of_the_giant.png"] = "round-potion",
    ["items/consumable_elixir_of_the_adept.png"] = "round-potion",
    ["items/revive_scroll.png"] = "tied-scroll",
    -- War drums were left unmatched above on the reasoning that no icon beats a wrong one. Under the
    -- gate there is no such thing as no icon -- an unmatched consumable now composes as the ward shield
    -- -- so it takes the rally instead, and the note above still holds for why it is not a drum.
    ["items/consumable_war_drums.png"] = "knight-banner",

    -- ---------------------------------------------------------------- props
    -- Board furniture. These sit on the terrain layer rather than the character layer, so an
    -- iconic treatment is the right register -- see the two-register rule in docs/art-assets.md.
    ["props/crate.png"] = "cargo-crate",
    ["props/explosive_barrel.png"] = "barrel",

    -- ------------------------------------------------------------ materials
    ["materials/iron_scrap.png"] = "metal-bar",
    ["materials/steel_ingot.png"] = "metal-bar",
    ["materials/mythril.png"] = "crystal-cluster",
}
