"use client";

import { ClerkProvider } from "@clerk/nextjs";

export default function MyApp({ children }: { children: React.ReactNode }) {
  return <ClerkProvider>{children}</ClerkProvider>;
}
