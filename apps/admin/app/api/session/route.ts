import { randomBytes } from 'crypto';
import { NextRequest, NextResponse } from 'next/server';
const api = process.env.API_INTERNAL_URL ?? 'http://localhost:3000/api/v1';
export async function POST(request: NextRequest) {
  const response = await fetch(`${api}/auth/login`, { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(await request.json()), cache: 'no-store' });
  if (!response.ok) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  const tokens = await response.json() as { accessToken: string; refreshToken: string };
  const authorized = await fetch(`${api}/admin/analytics`, { headers: { authorization: `Bearer ${tokens.accessToken}` }, cache: 'no-store' });
  if (!authorized.ok) return NextResponse.json({ error: 'Administrator role required' }, { status: 403 });
  const csrf = randomBytes(32).toString('base64url'); const result = NextResponse.json({ ok: true }); const secure = process.env.NODE_ENV === 'production';
  result.cookies.set('nc_admin_access', tokens.accessToken, { httpOnly: true, secure, sameSite: 'strict', path: '/', maxAge: 900 });
  result.cookies.set('nc_admin_refresh', tokens.refreshToken, { httpOnly: true, secure, sameSite: 'strict', path: '/', maxAge: 2592000 });
  result.cookies.set('nc_csrf', csrf, { httpOnly: false, secure, sameSite: 'strict', path: '/', maxAge: 2592000 });
  return result;
}
export async function DELETE() { const response = NextResponse.json({ ok: true }); response.cookies.delete('nc_admin_access'); response.cookies.delete('nc_admin_refresh'); response.cookies.delete('nc_csrf'); return response; }
