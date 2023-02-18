/datum/spellbook_item/spell

	var/datum/action/our_action_typepath
	entry_type = SPELLBOOK_SPELL

/datum/spellbook_item/spell/apply(mob/living/carbon/human/target, list/params)
	. = ..()

	var/datum/action/our_spell = new our_action_typepath(target.mind || target)
	apply_params(arglist(list(our_spell) + params))
	our_spell.Grant(target)

/datum/spellbook_item/spell/proc/apply_params(/datum/action/our_spell, ...)
	return
