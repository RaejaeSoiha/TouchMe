import { NextRequest, NextResponse } from 'next/server';
const api = process.env.API_INTERNAL_URL ?? 'http://localhost:3000/api/v1';
export async function PATCH(request: NextRequest, context: { params: Promise<{ path: string[] }> }) {
  const csrfCookie = request.cookies.get('nc_csrf')?.value; const csrfHeader = request.headers.get('x-csrf-token');
  if (!csrfCookie || csrfCookie !== csrfHeader) return NextResponse.json({ error: 'CSRF validation failed' }, { status: 403 });
  const origin = request.headers.get('origin'); if (origin && origin !== request.nextUrl.origin) return NextResponse.json({ error: 'Origin rejected' }, { status: 403 });
  const token = request.cookies.get('nc_admin_access')?.value; if (!token) return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  const { path } = await context.params; const response = await fetch(`${api}/admin/${path.join('/')}`, { method: 'PATCH', headers: { authorization: `Bearer ${token}`, 'content-type': 'application/json' }, body: JSON.stringify(await request.json()), cache: 'no-store' });
  return new NextResponse(await response.text(), { status: response.status, headers: { 'content-type': response.headers.get('content-type') ?? 'application/json' } });
}
