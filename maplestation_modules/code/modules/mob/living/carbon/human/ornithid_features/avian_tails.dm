// currently unused until someone figures out tailcode/i bother to figure out tail code

/* /obj/item/organ/external/tail/avian
	name = "tail"
	preference = "feature_avian_tail"
	dna_block = DNA_AVIAN_TAIL_BLOCK
	bodypart_overlay = /datum/bodypart_overlay/mutant/tail/avian
	// I will NOT be adding wagging. for a variety of reasons, chief of which being I am NOT animating all of the sprites
	// and because with how bird tails work, this would basically just be twerking. Fuck you.

/datum/bodypart_overlay/mutant/tail/avian
	feature_key = "tail_avian"
	layers = EXTERNAL_BEHIND | EXTERNAL_FRONT
	color_source = ORGAN_COLOR_HAIR

/datum/bodypart_overlay/mutant/tail/avian/New()
	. = ..()

/datum/bodypart_overlay/mutant/tail/avian/get_global_feature_list()
	return GLOB.tails_list_avian

/datum/sprite_accessory/tails/avian
	icon = 'maplestation_modules/icons/mob/ornithidfeatures.dmi'

/datum/sprite_accessory/tails/avian/eagle
	name = "Eagle"
	icon_state = "eagle" */ // commented this out because ultimately, I decided to keep this unused for the time being. visuals, being a pain in the ass to work with, etc.


/* /datum/sprite_accessory/tails/avian/swallow // commented this out for the time being
	name = "Swallow"
	icon_state = "swallow"
	color_src = HAIR */

// continue additional tails from here