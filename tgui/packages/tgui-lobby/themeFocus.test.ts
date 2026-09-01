// THIS IS AN APHELION UI FILE
import { describe, expect, it } from 'bun:test';
import {
  isLobbyDisplayControlInteractionTarget,
  isLobbyKeyboardInteractionTarget,
} from './themeFocus';

describe('lobby display-picker focus integration', () => {
  it('does not queue map focus when opening the title screen manager', () => {
    const controls = document.createElement('div');
    controls.className = 'lobby__display-controls';
    const managerButton = document.createElement('button');
    const icon = document.createElement('span');
    managerButton.appendChild(icon);
    controls.appendChild(managerButton);

    expect(isLobbyDisplayControlInteractionTarget(icon)).toBe(true);
  });

  it('recognizes the theme picker trigger and its portaled floating menu', () => {
    const triggerRoot = document.createElement('span');
    triggerRoot.className = 'MeridianThemePicker';
    const trigger = document.createElement('button');
    triggerRoot.appendChild(trigger);

    const floatingRoot = document.createElement('div');
    floatingRoot.className = 'MeridianThemePicker__floating';
    const option = document.createElement('button');
    floatingRoot.appendChild(option);

    expect(isLobbyDisplayControlInteractionTarget(trigger)).toBe(true);
    expect(isLobbyDisplayControlInteractionTarget(option)).toBe(true);
    expect(isLobbyKeyboardInteractionTarget(option)).toBe(true);
    expect(isLobbyDisplayControlInteractionTarget(document.body)).toBe(false);
    expect(isLobbyDisplayControlInteractionTarget(null)).toBe(false);
  });

  it('lets native lobby controls retain keyboard focus', () => {
    const navButton = document.createElement('button');
    const label = document.createElement('span');
    navButton.appendChild(label);

    expect(isLobbyKeyboardInteractionTarget(label)).toBe(true);
    expect(isLobbyKeyboardInteractionTarget(document.body)).toBe(false);

    navButton.disabled = true;
    expect(isLobbyKeyboardInteractionTarget(label)).toBe(false);

    const scrollRegion = document.createElement('div');
    scrollRegion.tabIndex = 0;
    expect(isLobbyKeyboardInteractionTarget(scrollRegion)).toBe(true);
  });
});
