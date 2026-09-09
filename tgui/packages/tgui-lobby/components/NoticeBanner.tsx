// THIS IS AN APHELION UI FILE
/** The big red admin notice banner (SStitle.current_notice / the "Title Screen: Set Notice" admin verb). */
export function NoticeBanner({ text }: { text: string }) {
  return (
    <div className="container_notice">
      <p className="menu_notice">{text}</p>
    </div>
  );
}
