/**
 * Two light "sabers" chasing each other around a rounded border — replaces the
 * static white ring on the hero screenshot card. Pure CSS (conic-gradient masked
 * to the border, rotated via the @property --beam-angle defined in globals.css),
 * so it's cheap and SSR-safe. Drop inside a `position: relative` rounded element;
 * it inherits the parent's border-radius.
 */
export function BorderBeam({ className }: { className?: string }) {
  return (
    <div
      aria-hidden="true"
      className={`border-beam pointer-events-none absolute inset-0 rounded-[inherit] ${className ?? ""}`}
    />
  );
}
