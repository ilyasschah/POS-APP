import Image from "next/image";

/**
 * The brand mark beside the wordmark in the header and the footer. Decorative:
 * the "Octopus POS" text next to it carries the name for assistive tech.
 */
export default function Mark({ size = 22 }: { size?: number }) {
  return (
    <Image
      src="/logo-NO_Background.png"
      width={size}
      height={size}
      className="brand-mark"
      alt=""
      aria-hidden="true"
    />
  );
}
