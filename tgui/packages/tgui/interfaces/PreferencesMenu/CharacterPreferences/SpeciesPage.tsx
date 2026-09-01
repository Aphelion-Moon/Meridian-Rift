import { useBackend } from 'tgui/backend';
import {
  BlockQuote,
  Box,
  Button,
  Divider,
  Icon,
  Section,
  Stack,
  Tooltip,
} from 'tgui-core/components';
import { classes } from 'tgui-core/react';

import { CharacterPreview } from '../../common/CharacterPreview';
import { LoadingScreen } from '../../common/LoadingScreen';
import {
  createSetPreference,
  Food,
  type Perk,
  type PreferencesMenuData,
  type ServerData,
  type Species,
} from '../types';
import { useServerPrefs } from '../useServerPrefs';

const FOOD_ICONS = {
  [Food.Bugs]: 'bug',
  [Food.Cloth]: 'tshirt',
  [Food.Dairy]: 'cheese',
  [Food.Fried]: 'bacon',
  [Food.Fruit]: 'apple-alt',
  [Food.Gore]: 'skull',
  [Food.Grain]: 'bread-slice',
  [Food.Gross]: 'trash',
  [Food.Junkfood]: 'pizza-slice',
  [Food.Meat]: 'hamburger',
  [Food.Nuts]: 'seedling',
  [Food.Raw]: 'drumstick-bite',
  [Food.Seafood]: 'fish',
  [Food.Stone]: 'gem',
  [Food.Sugar]: 'candy-cane',
  [Food.Toxic]: 'biohazard',
  [Food.Vegetables]: 'carrot',
};

const FOOD_NAMES: Record<keyof typeof FOOD_ICONS, string> = {
  [Food.Bugs]: 'Bugs',
  [Food.Cloth]: 'Clothing',
  [Food.Dairy]: 'Dairy',
  [Food.Fried]: 'Fried food',
  [Food.Fruit]: 'Fruit',
  [Food.Gore]: 'Gore',
  [Food.Grain]: 'Grain',
  [Food.Gross]: 'Gross food',
  [Food.Junkfood]: 'Junk food',
  [Food.Meat]: 'Meat',
  [Food.Nuts]: 'Nuts',
  [Food.Raw]: 'Raw',
  [Food.Seafood]: 'Seafood',
  [Food.Stone]: 'Rocks',
  [Food.Sugar]: 'Sugar',
  [Food.Toxic]: 'Toxic food',
  [Food.Vegetables]: 'Vegetables',
};

const IGNORE_UNLESS_LIKED: Set<Food> = new Set([
  Food.Bugs,
  Food.Cloth,
  Food.Gross,
  Food.Toxic,
]);

function notIn<T>(set: Set<T>) {
  return (value: T) => {
    return !set.has(value);
  };
}

type FoodListProps = {
  food: Food[];
  icon: string;
  name: string;
  className: string;
};

function FoodList(props: FoodListProps) {
  const { food = [], icon, name, className } = props;

  if (food.length === 0) {
    return null;
  }

  return (
    <Tooltip
      position="bottom-end"
      content={
        <Box>
          <Icon name={icon} /> <b>{name}</b>
          <Divider />
          <Box>
            {food
              .reduce((names, food) => {
                const foodName = FOOD_NAMES[food];
                return foodName ? names.concat(foodName) : names;
              }, [])
              .join(', ')}
          </Box>
        </Box>
      }
    >
      {/* // APHELION EDIT REMOVAL START - MERIDIAN_UI
      <Stack ml={2}>
      // APHELION EDIT REMOVAL END */}
      {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
      <Stack
        className="PreferencesMenu__SpeciesDietGroup"
        align="center"
        g={0.5}
      >
      {/* APHELION EDIT ADDITION END */}
        {food.map((food) => {
          return (
            FOOD_ICONS[food] && (
              <Stack.Item key={food}> {/* APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: <Stack.Item> */}
                <Icon
                  className={className}
                  size={1.4}
                  // key={food} // APHELION EDIT REMOVAL - MERIDIAN_UI
                  name={FOOD_ICONS[food]}
                />
              </Stack.Item>
            )
          );
        })}
      </Stack>
    </Tooltip>
  );
}

type DietProps = {
  diet: Species['diet'];
};

function Diet(props: DietProps) {
  const { diet } = props;
  if (!diet) {
    return null;
  }

  const { liked_food, disliked_food, toxic_food } = diet;

  return (
    <Stack className="PreferencesMenu__SpeciesDiet" align="center" g={0.5}> {/* APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: <Stack> */}
      <Stack.Item>
        <FoodList
          food={liked_food}
          icon="heart"
          name="Liked food"
          className="color-pink"
        />
      </Stack.Item>

      <Stack.Item>
        <FoodList
          food={disliked_food.filter(notIn(IGNORE_UNLESS_LIKED))}
          icon="thumbs-down"
          name="Disliked food"
          className="color-red"
        />
      </Stack.Item>

      <Stack.Item>
        <FoodList
          food={toxic_food.filter(notIn(IGNORE_UNLESS_LIKED))}
          icon="biohazard"
          name="Toxic food"
          className="color-olive"
        />
      </Stack.Item>
    </Stack>
  );
}

type SpeciesPerkProps = {
  className: string;
  perk: Perk;
};

export function SpeciesPerk(props: SpeciesPerkProps) { // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: function SpeciesPerk(props: SpeciesPerkProps) {
  const { className, perk } = props;

  return (
    <Tooltip
      position="bottom-end"
      content={
        <Box>
          <Box as="b">{perk.name}</Box>
          <Divider />
          <Box>{perk.description}</Box>
        </Box>
      }
    >
      {/* // APHELION EDIT REMOVAL START - MERIDIAN_UI
      <Box className={className} width="32px" height="32px">
        <Icon
          name={perk.ui_icon}
          size={1.5}
          ml={0}
          mt={1}
          style={{
            textAlign: 'center',
            height: '100%',
            width: '100%',
          }}
        />
      </Box>
      // APHELION EDIT REMOVAL END */}
      {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
      <Box
        className={classes(['PreferencesMenu__SpeciesPerk', className])}
        width="32px"
        height="32px"
      >
        <Icon name={perk.ui_icon} size={1.5} />
      </Box>
      {/* APHELION EDIT ADDITION END */}
    </Tooltip>
  );
}

type SpeciesPerksProps = {
  perks: Species['perks'];
};

function SpeciesPerks(props: SpeciesPerksProps) {
  const { positive, negative, neutral } = props.perks;

  return (
    <Stack fill justify="space-between">
      <Stack.Item>
        <Stack>
          {positive.map((perk) => {
            return (
              <Stack.Item key={perk.name}>
                <SpeciesPerk className="color-bg-green" perk={perk} />
              </Stack.Item>
            );
          })}
        </Stack>
      </Stack.Item>

      <Stack>
        {neutral.map((perk) => {
          return (
            <Stack.Item key={perk.name}>
              <SpeciesPerk className="color-bg-grey" perk={perk} />
            </Stack.Item>
          );
        })}
      </Stack>

      <Stack>
        {negative.map((perk) => {
          return (
            <Stack.Item key={perk.name}>
              <SpeciesPerk className="color-bg-red" perk={perk} />
            </Stack.Item>
          );
        })}
      </Stack>
    </Stack>
  );
}

type SpeciesPageInnerProps = {
  handleClose: () => void;
  species: ServerData['species'];
};

function SpeciesPageInner(props: SpeciesPageInnerProps) {
  const { act, data } = useBackend<PreferencesMenuData>();
  const setSpecies = createSetPreference(act, 'species');

  const species: [string, Species][] = Object.entries(props.species).map(
    ([species, data]) => {
      return [species, data];
    },
  );

  // Humans are always the top of the list
  const humanIndex = species.findIndex(([species]) => species === 'human');
  const swapWith = species[0];
  species[0] = species[humanIndex];
  species[humanIndex] = swapWith;

  const currentSpecies = species.filter(([speciesKey]) => {
    return speciesKey === data.character_preferences.misc.species;
  })[0][1];

  return (
    <Stack vertical fill>
      <Stack.Item>
        <Button icon="arrow-left" onClick={props.handleClose}>
          Go Back
        </Button>
      </Stack.Item>

      <Stack.Item grow>
        <Stack fill>
          <Stack.Item>
            {/* // APHELION EDIT REMOVAL START - MERIDIAN_UI
            <Box height="calc(100vh - 170px)" overflowY="auto" pr={3}>
            // APHELION EDIT REMOVAL END */}
            {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
            <Box
              className="PreferencesMenu__SpeciesList"
              height="calc(100vh - 170px)"
              overflowY="auto"
              pr={3}
            >
            {/* APHELION EDIT ADDITION END */}
              {species.map(([speciesKey, species]) => {
                // NOVA EDIT START - Nova star-only species
                let speciesPage = (
                  <Button
                    className="PreferencesMenu__SpeciesButton" // APHELION EDIT ADDITION
                    key={speciesKey}
                    onClick={() => {
                      if (
                        data.nova_star_restrictions &&
                        species.nova_stars_only &&
                        !data.is_nova_star
                      ) {
                        return;
                      }
                      setSpecies(speciesKey);
                    }}
                    selected={
                      data.character_preferences.misc.species === speciesKey
                    }
                    tooltip={species.name}
                    style={{
                      display: 'block',
                      height: '66px', // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: height: '64px',
                      width: '66px', // APHELION EDIT CHANGE - MERIDIAN_UI - ORIGINAL: width: '64px',
                    }}
                  >
                    {/* // APHELION EDIT REMOVAL START - MERIDIAN_UI
                    <Box
                      className={classes(['species64x64', species.icon])}
                      ml={-1}
                    />
                    // APHELION EDIT REMOVAL END */}
                    {/* APHELION EDIT ADDITION START - MERIDIAN_UI */}
                    <Box className={classes(['species64x64', species.icon])} />
                    {/* APHELION EDIT ADDITION END */}
                  </Button>
                );
                if (
                  data.nova_star_restrictions &&
                  species.nova_stars_only &&
                  !data.is_nova_star
                ) {
                  const tooltipContent =
                    species.name +
                    ' - You need to be a Nova star to select this race, apply today!';
                  speciesPage = (
                    <Tooltip content={tooltipContent}>{speciesPage}</Tooltip>
                  );
                }
                return speciesPage;
                // NOVA EDIT END
              })}
            </Box>
          </Stack.Item>

          <Stack.Item grow>
            <Box>
              <Box>
                <Stack fill>
                  <Stack.Item width="70%">
                    <Section
                      title={currentSpecies.name}
                      buttons={
                        // NOHUNGER species have no diet (diet = null),
                        // so we have nothing to show
                        currentSpecies.diet && (
                          <Diet diet={currentSpecies.diet} />
                        )
                      }
                    >
                      {/* NOVA EDIT CHANGE START - Adds maxHeight, scrollable*/}
                      <Section title="Description" maxHeight="14vh" scrollable>
                        {/* NOVA EDIT CHANGE END */}
                        {currentSpecies.desc}
                      </Section>

                      <Section title="Features">
                        <SpeciesPerks perks={currentSpecies.perks} />
                      </Section>
                    </Section>
                  </Stack.Item>

                  <Stack.Item width="30%">
                    <CharacterPreview
                      id={data.character_preview_view}
                      height="100%"
                    />
                  </Stack.Item>
                </Stack>
              </Box>

              <Box mt={1}>
                <Section title="Lore">
                  <BlockQuote /* NOVA EDIT START - scrollable lore */
                    overflowY="auto"
                    maxHeight="45vh"
                    mr={-1} /* NOVA EDIT END */
                  >
                    {currentSpecies.lore.map((text, index) => (
                      <Box key={index} maxWidth="100%">
                        {text}
                        {index !== currentSpecies.lore.length - 1 && (
                          <>
                            <br />
                            <br />
                          </>
                        )}
                      </Box>
                    ))}
                  </BlockQuote>
                </Section>
              </Box>
            </Box>
          </Stack.Item>
        </Stack>
      </Stack.Item>
    </Stack>
  );
}

type SpeciesPageProps = {
  closeSpecies: () => void;
};

export function SpeciesPage(props: SpeciesPageProps) {
  const serverData = useServerPrefs();
  if (!serverData) {
    return <LoadingScreen />;
  }

  return (
    <SpeciesPageInner
      handleClose={props.closeSpecies}
      species={serverData.species}
    />
  );
}
