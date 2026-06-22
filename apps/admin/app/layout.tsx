import type { Metadata } from 'next';
import './globals.css';
export const metadata: Metadata = { title: 'TouchMe Admin', description: 'Moderation and platform operations' };
export default function RootLayout({ children }: Readonly<{ children: React.ReactNode }>) { return <html lang="en"><body>{children}</body></html>; }

