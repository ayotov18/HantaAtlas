import Image from "next/image";

import { cn } from "@/lib/utils";

type IPhoneFrameProps = {
  src: string;
  alt: string;
  priority?: boolean;
  className?: string;
};

export function IPhoneFrame({ src, alt, priority = false, className }: IPhoneFrameProps) {
  return (
    <div
      className={cn(
        "phone-shadow relative mx-auto aspect-[1290/2796] w-full max-w-[330px] overflow-hidden rounded-[42px] border-[9px] border-graphite bg-graphite md:max-w-[360px] lg:max-w-[390px]",
        className,
      )}
    >
      <div className="absolute left-1/2 top-3 z-10 h-7 w-32 -translate-x-1/2 rounded-full bg-black/88 md:w-36" />
      <Image
        src={src}
        alt={alt}
        fill
        sizes="(max-width: 768px) 78vw, 390px"
        className="object-cover"
        priority={priority}
      />
    </div>
  );
}
