// -- Hydroponics tray additions --
#define TRAY_MODIFIED_BASE_NUTRIDRAIN 0.5

/obj/machinery/hydroponics/constructable
	// Nutriment drain is halved so they can not worry about fertilizer as much
	nutridrain = TRAY_MODIFIED_BASE_NUTRIDRAIN

/obj/machinery/hydroponics/set_self_sustaining(new_value)
	var/old_self_sustaining = self_sustaining
	. = ..()
	if(self_sustaining != old_self_sustaining)
		if(self_sustaining)
			nutridrain /= 2
		else
			nutridrain *= 2

/obj/machinery/hydroponics/constructable/RefreshParts()
	. = ..()
	// Dehardcodes the nutridrain scaling factor
	nutridrain = initial(nutridrain) / rating
	// Adds a flat 100 max water (doesn't really matter cause autogrow)
	maxwater += 100

#undef TRAY_MODIFIED_BASE_NUTRIDRAIN

/obj/machinery/hydroponics
	//Var that makes regular trays unable to handle xenobotany seeds
	var/accept_alien_seeds = FALSE
	var/accept_produce_seeds = TRUE

//Xenobotany tray
/obj/machinery/hydroponics/xeno_tray
	name = "xenobotany tray"
	icon_state = "hydrotray2"
	accept_alien_seeds = TRUE
	accept_produce_seeds = FALSE

//We don't wanna grow weird stuff!
/obj/machinery/hydroponics/constructable
	accept_alien_seeds = FALSE

/obj/machinery/hydroponics/soil
	accept_alien_seeds = FALSE

//Alien seed check
/obj/machinery/hydroponics/proc/alien_check(mob/user, obj/item/seeds/seed)
	if(seed.is_alien_seed && !accept_alien_seeds)
		to_chat(user, span_warning("This tray does not accept [seed]!"))
		return FALSE
	return TRUE

//Produce seed check
/obj/machinery/hydroponics/proc/produce_check(mob/user, obj/item/seeds/seed)
	if(seed.is_produce_seed && !accept_produce_seeds)
		to_chat(user, span_warning("This tray does not accept [seed]!"))
		return FALSE
	return TRUE
