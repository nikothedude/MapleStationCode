//Extends /obj/item/seeds for modular access

/obj/item/seeds
	//Determiens if a seed is aline or not
	var/is_alien_seed = FALSE
	var/is_produce_seed = TRUE

/obj/item/seeds/aloe
	is_alien_seed = TRUE
	is_produce_seed = FALSE
