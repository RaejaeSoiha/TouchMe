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

async function signOut() {
  'use server';
  const { cookies } = await import('next/headers');
  const { redirect } = await import('next/navigation');
  const jar = await cookies();
  jar.delete('nc_admin_access');
  jar.delete('nc_admin_refresh');
  jar.delete('nc_csrf');
  redirect('/login');
}

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
        <form action={signOut} className="mt-10">
          <button type="submit" className="w-full rounded-xl bg-slate-800 px-4 py-3 text-left font-semibold hover:bg-slate-700">
            Sign out
          </button>
        </form>
      </aside>
      <main className="p-6 lg:p-10">{children}</main>
    </div>
  );
}
