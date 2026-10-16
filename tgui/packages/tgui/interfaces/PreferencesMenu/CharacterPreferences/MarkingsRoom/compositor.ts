// THIS IS AN APHELION UI FILE

/**
 * Hands a room's endless animations to the compositor once nothing else on
 * their element animates the same property.
 *
 * Chrome won't start an animation on the compositor while another animation
 * of the same property runs on the same element, and doesn't look again when
 * that one ends. A neon's flicker-on and its endless hum both animate opacity
 * and start together (the club's side tube, Hotline's sign), so the hum stays
 * on the page's thread, which ticks it every frame for as long as the room is
 * open. When an animation ends, an endless one on the same element has its
 * time set to what it is, which changes nothing it shows but has Chrome start
 * it again, on the compositor this time.
 */
export function rejoinCompositor(event: { target: EventTarget | null }) {
  const target = event.target as Element | null;
  if (!target?.getAnimations) {
    return;
  }
  for (const animation of target.getAnimations()) {
    if (
      animation.playState === 'running' &&
      animation.effect?.getTiming().iterations === Number.POSITIVE_INFINITY
    ) {
      // biome-ignore lint/correctness/noSelfAssign: setting it is what makes Chrome look again.
      animation.currentTime = animation.currentTime;
    }
  }
}
