import { cn } from "@/lib/utils";

function Skeleton({ className, ...props }: React.ComponentProps<"div">) {
  return (
    <div
      data-slot="skeleton"
      className={cn(
        "animate-pulse rounded-md bg-muted bg-[linear-gradient(100deg,transparent,rgba(255,255,255,0.38),transparent)] bg-[length:220%_100%]",
        className,
      )}
      {...props}
    />
  );
}

export { Skeleton };
