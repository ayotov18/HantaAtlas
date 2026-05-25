import { cn } from "@/lib/utils";
import { Reveal } from "@/components/animate-ui/reveal";

type SectionHeadingProps = {
  kicker?: string;
  title: string;
  children?: React.ReactNode;
  className?: string;
};

export function SectionHeading({ kicker, title, children, className }: SectionHeadingProps) {
  return (
    <Reveal className={cn("max-w-3xl", className)}>
      {kicker ? (
        <p className="mb-4 text-xs font-semibold uppercase tracking-[0.18em] text-primary">
          {kicker}
        </p>
      ) : null}
      <h2 className="text-4xl font-semibold leading-[1.05] text-balance md:text-5xl">
        {title}
      </h2>
      {children ? (
        <p className="mt-5 text-lg leading-8 text-muted-foreground">{children}</p>
      ) : null}
    </Reveal>
  );
}
