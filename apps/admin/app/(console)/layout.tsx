import Link from 'next/link';

const links = [
  ['Dashboard', '/dashboard'],
  ['Users', '/users'],
  ['Reports', '/reports'],
  ['Media', '/media'],
  ['Analytics', '/analytics'],
  ['Subscriptions', '/subscriptions'],
  ['Plans', '/plans']
] as const;

export default function ConsoleLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="min-h-screen lg:grid lg:grid-cols-[250px_1fr]">
      <aside className="bg-slate-950 p-7 text-white">
        <p className="text-xs font-bold uppercase tracking-[.28em] text-rose-400">TouchMe</p>
        <h1 className="mt-2 text-xl font-black">Admin</h1>
        <nav className="mt-10 flex gap-2 overflow-auto lg:flex-col">
          {links.map(([label, href]) => (
            <Link key={href} className="rounded-xl px-4 py-3 font-semibold hover:bg-slate-800" href={href}>
              {label}
            </Link>
          ))}
        </nav>
      </aside>
      <main className="p-6 lg:p-10">{children}</main>
    </div>
  );
}
