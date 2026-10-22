// Browser harness entry; imports the actual client renderer/controller.
export { renderUiSnapshot } from "../tgui/packages/tgui/capture/dom-snapshot";
export {
  requestUiSnapshot,
  acknowledgeUiSnapshot,
  cancelUiSnapshot,
} from "../tgui/packages/tgui/capture/controller";
import { configAtom, store } from "../tgui/packages/tgui/events/store";
export function setInterface(name: string) {
  store.set(configAtom, {
    ...store.get(configAtom),
    interface: { name, layout: "default" },
  });
}
