'use client';
import { FormEvent, useState } from 'react';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const router = useRouter();
  const [error, setError] = useState('');
  const [busy, setBusy] = useState(false);

  async function submit(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setBusy(true);
    setError('');
    const form = new FormData(event.currentTarget);
    const email = String(form.get('email') ?? '').trim().toLowerCase();
    const password = String(form.get('password') ?? '');
    const response = await fetch('/api/session', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ email, password }),
    });
    setBusy(false);
    if (!response.ok) {
      const body = (await response.json().catch(() => null)) as { error?: string } | null;
      setError(body?.error === 'Administrator role required'
        ? 'This account does not have admin access. Run the database seed first.'
        : 'Invalid credentials or insufficient privileges.');
      return;
    }
    router.replace('/dashboard');
    router.refresh();
  }

  return (
    <main className="grid min-h-screen place-items-center bg-gradient-to-br from-rose-100 via-white to-orange-100 p-6">
      <form
        method="post"
        onSubmit={submit}
        className="w-full max-w-md rounded-3xl bg-white p-10 shadow-xl"
      >
        <p className="mb-2 text-sm font-bold uppercase tracking-[.3em] text-rose-500">TouchMe</p>
        <h1 className="mb-2 text-3xl font-black">Operations console</h1>
        <p className="mb-8 text-sm text-slate-600">Sign in with your admin email and password.</p>
        <label className="mb-2 block text-sm font-semibold" htmlFor="email">Email</label>
        <input
          id="email"
          name="email"
          type="email"
          required
          autoComplete="username"
          defaultValue="admin@touchme.local"
          className="mb-5 w-full rounded-xl border border-slate-300 p-3"
        />
        <label className="mb-2 block text-sm font-semibold" htmlFor="password">Password</label>
        <input
          id="password"
          name="password"
          type="password"
          required
          autoComplete="current-password"
          className="mb-6 w-full rounded-xl border border-slate-300 p-3"
        />
        {error && <p role="alert" className="mb-4 text-sm text-red-700">{error}</p>}
        <button
          type="submit"
          disabled={busy}
          className="w-full rounded-xl bg-rose-500 p-3 font-bold text-white disabled:opacity-50"
        >
          {busy ? 'Signing in…' : 'Sign in'}
        </button>
      </form>
    </main>
  );
}
