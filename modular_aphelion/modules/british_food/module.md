## British food

Module ID: BRITISH_FOOD

### Description:

British dishes with their recipes, grab-and-go vendor versions, and the vendor that sells them.

- **Dishes.** Hunter's chicken, steak and ale pie, pork pie, chicken and mushroom pie, Cornish pasty, beans
  on toast, Welsh cawl, Eton mess, scones with jam and cream, sticky toffee pudding, the deep fried Mars bar
  and the sausage, bean and cheese melt. The steak pie cuts into five slices. The pork and chicken pies are
  single servings that cut into quarters. Eton mess comes in a drinking glass: the recipe takes one and eating
  leaves it, as bowl dishes do with bowls. Welsh cawl is a soup from the soup pot, served in a bowl.
- **Drinks.** Irn-Bru and dandelion and burdock cans, each with its own in-hand and crushed sprites. Both
  also stock the standard Robust Softdrinks machine.
- **Deep fried Mars bar.** Each bar holds saturated fat, which takes minutes to clear from the blood. Three bars
  within about five minutes overdose and damage the heart, and each bar past that hurts more; one now and then
  never does.
- **Vendor food.** `/obj/item/food/british_pack` items are eaten from their container. Most can also be used
  in hand to take the food out, which keeps the bites already taken and leaves the empty container. They are
  junkier and less nutritious than the home-cooked dishes.
- **Mrs. Luvvit's Pie & Mash** (`/obj/machinery/vending/imported/luvvits`), an imported vendor. It is
  mapped into the Interlink, the ghost cafe, two station maps and five ruins, and its refill joins the
  imported vendors' cargo crate. Hot food comes out piping hot
  (`/datum/component/piping_hot`): it steams for 10 to 30 seconds, and each bite before it cools burns the
  eater's tongue a little and stops them eating for a few seconds. Masochists keep eating. It can't hurt
  mobs that resist heat or lava, can't feel pain, or have a body built for lavaland heat (lizards, golems,
  kobolds) or hotter.

### TG Proc/File Changes:

- `code/game/objects/effects/spawners/random/trash.dm`: the empty containers join
  `/obj/effect/spawner/random/trash/food_packaging`
- `code/modules/unit_tests/trash_food.dm`: the drinking glass joins the blacklist, beside plates and bowls
- `code/modules/reagents/reagent_containers/cups/soda.dm`: the three crush paths style their crushed can with
  `style_crushed_can()`

### Modular Overrides:

- `modular_aphelion/master_files/code/modules/reagents/reagent_containers/cups/soda.dm`:
  `/obj/item/reagent_containers/cup/soda_cans/proc/style_crushed_can()`, which the cans here override
- `modular_aphelion/master_files/code/modules/vending/vendor/_vending.dm`: `panel_over_light_mask`, for
  vendors whose light mask lies under their open panel

### Defines:

- N/A

### Included files that are not contained in this module:

- `modular_nova/modules/deforest_medical_items/code/vendor.dm` and `icons/vendor.dmi`: the DeForest
  Med-Vend's `panel15`, which blocks its light mask while open
- `modular_nova/modules/customization/modules/reagents/chemistry/reagents/drinks.dm`: the imported cans' crushed
  cans take their sprites through `style_crushed_can()`
- `modular_nova/modules/modular_vending/code/cola.dm`: the two cans join the Robust Softdrinks stock
- `modular_nova/modules/modular_items/code/summon_beacon.dm`: the vendor joins the summonable machines
