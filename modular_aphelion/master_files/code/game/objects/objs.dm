/obj/examine_tags(mob/user)
	. = ..()
	if(obj_flags_nova & ADMIN_ITEM)
		.["administrative"] = "Created by an Admin, somehow."
