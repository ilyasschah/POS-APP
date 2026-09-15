import type { Metadata } from "next";
import HelpCentre from "./HelpCentre";

export const metadata: Metadata = {
  title: "Help centre",
  description:
    "Step-by-step guides for Octopus POS: registering a terminal, opening and closing the register, working offline, printers, the kitchen display and common fixes.",
  alternates: { canonical: "/help" },
};

export default function HelpPage() {
  return <HelpCentre />;
}
