#define COMSIG_KB_ADMIN_COMBOHUD_DOWN "keybinding_admin_combohud_down"
#define COMSIG_KB_ADMIN_WALLHACKS_DOWN "keybinding_admin_wallhacks_down"

/// Company for Admin unique items
#define COMPANY_ADMIN "You can somehow tell that <b>[span_green("Central Command")]</b> produced this item."

/// Admin Tool Slot Catcher
#define ITEM_SLOT_ADMIN (ITEM_SLOT_POCKETS | ITEM_SLOT_BELT | ITEM_SLOT_SUITSTORE | ITEM_SLOT_BACK | ITEM_SLOT_ID )

/// Prevents an item from being stripped unless you are an admin privileges holder.
#define NOSTRIP (1<<3)
/// Is this an Admin item? Adds an 'admistrative' obj detail, similar to how sec gloves show they cuff quickly or insuls provide insulation
#define ADMIN_ITEM (1<<4)

/// Admin Items and Flags
/// These three defines belong to three different bitfields and are NOT interchangeable - the bits overlap.
/// ADMIN_OBJ_FLAGS goes on obj_flags, ADMIN_OBJ_FLAGS_NOVA goes on obj_flags_nova, ADMIN_CLOTHING_FLAGS goes on clothing_flags.
#define ADMIN_OBJ_FLAGS (UNIQUE_RENAME)
/// Prevents removal through strip menu, and tags the item as administrative on examine
#define ADMIN_OBJ_FLAGS_NOVA (NOSTRIP | ADMIN_ITEM)
/// Admin worn gear doesn't get knocked off. Apply with |= so the parent type's own flags survive.
/// Moths are kept off it by resistance_flags & INDESTRUCTIBLE, which every admin clothing type
/// already carries - drop that from one and it becomes edible again.
#define ADMIN_CLOTHING_FLAGS (SNUG_FIT)

/// Used by Admin fabricators to select from admin / debug / useful / fun prints
#define ADMIN_TECHWEB (1<<12)

/// Trait which obscures identity like the Infiltration module, but provides text unique for admin techs
#define TRAIT_ADMIN_STEALTH "admin_stealth"
/// Trait which provides an early return TRUE on IsReachableBy() that checks for CanSeeTarget
#define TRAIT_ADMIN_REACHABLE "admin_reachable"

// Trait which shows wire legend when applied to something
#define TRAIT_SHOW_ALL_WIRES "show_all_wires"

//Admin Traits
/// Trait for wallhacks admin verb
#define TRAIT_ADMIN_WALLHACKS "admin_wallhacks"
/// Trait for clothing which provides the effects of the book of babel, which is handled by the babel_clothing element
#define TRAIT_BABEL_CLOTHING "babel_clothing"
/// Trait marking a mob the babel_clothing element already listens to, so a second babel item doesn't double-register
#define TRAIT_BABEL_LISTENER "babel_listener"
/// Trait involved in reveal_wires element, to show the wire legend of anything when working
#define TRAIT_REVEAL_WIRES_ITEM "reveal_wires_item"

// This file contains all of the trait sources, or all of the things that grant traits.
// Several things such as `type` or `REF(src)` may be used in the ADD_TRAIT() macro as the "source", but this file contains all of the defines for immutable static strings.

// Admin Traits
/// Logical trait to prevent conflicts. Does nothing but exist and then not exist as needed on specific admin items.
#define ADMIN_GEAR_TRAIT "admin_gear_trait"
