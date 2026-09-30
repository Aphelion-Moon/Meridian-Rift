// THIS IS AN APHELION UI FILE
import { Icon, LabeledList } from 'tgui-core/components';

import type { Food, Species } from '../../types';
import { FOOD_ICONS, FOOD_NAMES, IGNORE_UNLESS_LIKED } from './constants';

const notIgnored = (food: Food) => !IGNORE_UNLESS_LIKED.has(food);

function FoodList(props: { foods: Food[] }) {
  return (
    <span className="SpeciesDiet__foods">
      {props.foods.map((food) => (
        <span key={food} className="SpeciesDiet__food">
          <Icon name={FOOD_ICONS[food] ?? 'utensils'} />
          {FOOD_NAMES[food] ?? food}
        </span>
      ))}
    </span>
  );
}

/** Liked, disliked and toxic foods, leaving out dislikes nearly everyone has. */
export function SpeciesDiet(props: { diet: NonNullable<Species['diet']> }) {
  const { liked_food, disliked_food, toxic_food } = props.diet;
  const rows = [
    { key: 'likes', label: 'Likes', icon: 'heart', foods: liked_food },
    {
      key: 'dislikes',
      label: 'Dislikes',
      icon: 'thumbs-down',
      foods: disliked_food.filter(notIgnored),
    },
    {
      key: 'toxic',
      label: 'Toxic',
      icon: 'biohazard',
      foods: toxic_food.filter(notIgnored),
    },
  ].filter(({ foods }) => foods.length > 0);

  if (!rows.length) {
    return null;
  }

  return (
    <div className="SpeciesDiet">
      <LabeledList>
        {rows.map(({ key, label, icon, foods }) => (
          <LabeledList.Item
            key={key}
            className={`SpeciesDiet__row SpeciesDiet__row--${key}`}
            label={
              <>
                <Icon name={icon} mr={0.5} />
                {label}
              </>
            }
          >
            <FoodList foods={foods} />
          </LabeledList.Item>
        ))}
      </LabeledList>
    </div>
  );
}
