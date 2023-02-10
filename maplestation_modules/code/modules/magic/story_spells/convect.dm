/datum/component/uses_mana/story_spell/pointed/convect

#define CONVECT_HEAT_ATTUNEMENT 0.5
#define CONVECT_ICE_ATTUNEMENT 0.5
/datum/component/uses_mana/story_spell/pointed/convect/get_attunement_dispositions()
	. = ..()
	if (!istype(spell_parent, /datum/action/cooldown/spell/pointed/convect))
		return
	var/datum/action/cooldown/spell/pointed/convect/convect_spell = spell_parent
	if (convect_spell.temperature_for_cast == 0)
		return
	if (convect_spell.temperature_for_cast > 0)
		.[MAGIC_ELEMENT_FIRE] += CONVECT_HEAT_ATTUNEMENT
		.[MAGIC_ELEMENT_ICE] -= CONVECT_HEAT_ATTUNEMENT
		return
	else
		.[MAGIC_ELEMENT_ICE] += CONVECT_ICE_ATTUNEMENT
		.[MAGIC_ELEMENT_FIRE] -= CONVECT_ICE_ATTUNEMENT

#undef CONVECT_HEAT_ATTUNEMENT
#undef CONVECT_ICE_ATTUNEMENT

/datum/component/uses_mana/story_spell/pointed/convect/get_mana_required(...)
	. = ..()
	if (!istype(spell_parent, /datum/action/cooldown/spell/pointed/convect))
		return INFINITY //placeholder shit until i improve this

	var/datum/action/cooldown/spell/pointed/convect/convect_spell = spell_parent
	return ((abs(convect_spell.temperature_for_cast)*CONVECT_MANA_COST_PER_KELVIN) * convect_spell.owner.get_base_casting_cost())
	// todo: methodize the casting cost mult part

/datum/component/uses_mana/story_spell/pointed/convect/react_to_successful_use(atom/cast_on)
	. = ..()

	drain_mana()

/datum/action/cooldown/spell/pointed/convect
	name = "Convect"
	desc = "Manipulate the temperature of matter around you. Right-click the spell icon to set the temperature alteration."
	school = SCHOOL_TRANSMUTATION

	active_msg = "Nearby matter seems to still eversoslightly."
	deactive_msg = "Your surroundings normalize."

	aim_assist = FALSE
	cast_range = 1 //physical touching

	unset_after_click = FALSE
	spell_requirements = SPELL_REQUIRES_NO_ANTIMAGIC

	var/temperature_for_cast = 25

/datum/action/cooldown/spell/pointed/convect/New(Target, original)
	. = ..()

	AddComponent(/datum/component/uses_mana/story_spell/pointed/convect, src)

/datum/action/cooldown/spell/pointed/convect/is_valid_target(atom/cast_on)
	return TRUE //cant call suepr cause i want to be able to use this on myself

/datum/action/cooldown/spell/pointed/convect/Trigger(trigger_flags, atom/target)
	if (trigger_flags & TRIGGER_SECONDARY_ACTION)
		get_new_cast_temperature()
		return FALSE

	. = ..()

/datum/action/cooldown/spell/pointed/convect/proc/get_new_cast_temperature()
	var/temperature = tgui_input_number(owner, "How many degrees (kelvin) do you wish to shift temperature by?", "Convect", null, max_value = INFINITY, min_value = -INFINITY, timeout = 5 SECONDS)
	if (!temperature)
		return FALSE
	temperature_for_cast = temperature
	owner.balloon_alert(owner, "Casting temperature set to [temperature]K")

/datum/action/cooldown/spell/pointed/convect/on_activation(mob/on_who)
	. = ..()
	if (temperature_for_cast == null)
		get_new_cast_temperature()
		if (temperature_for_cast == null)
			unset_click_ability(on_who)
			return FALSE

/datum/action/cooldown/spell/pointed/convect/on_deactivation(mob/on_who, refund_cooldown)
	. = ..()
	//temperature_for_cast = 0

/datum/action/cooldown/spell/pointed/convect/cast(atom/cast_on)
	. = ..()

	var/hot_or_cold
	var/heat_or_cool
	if (temperature_for_cast > 0)
		hot_or_cold = "heat"
		heat_or_cool = "heat"
	else
		hot_or_cold = "cold"
		heat_or_cool = "cool"
	if (iscarbon(cast_on))
		var/mob/living/carbon/carbon_target = cast_on
		carbon_target.adjust_bodytemperature(temperature_for_cast, use_insulation = TRUE)
		to_chat(carbon_target, span_warning("You feel a wave of [hot_or_cold] eminate from [owner]..."))
	var/turf/turf_target = get_turf(cast_on)
	if (turf_target != null)
		var/datum/gas_mixture/turf_air = turf_target.return_air()
		if (turf_air)
			turf_air.temperature += temperature_for_cast //this sucks.
			turf_target.air_update_turf()
	cast_on.reagents?.expose_temperature(temperature_for_cast)
	to_chat(owner, span_warning("You [heat_or_cool] [cast_on] by [temperature_for_cast]K."))
