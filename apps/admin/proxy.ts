import { NextRequest, NextResponse } from 'next/server';

const api = process.env.API_INTERNAL_URL ?? 'http://localhost:3000/api/v1';

export async function proxy(request: NextRequest) {
  let access = request.cookies.get('nc_admin_access')?.value;
  const refresh = request.cookies.get('nc_admin_refresh')?.value;
  let rotated: { accessToken: string; refreshToken: string } | undefined;

  if (!access && refresh) {
    const response = await fetch(`${api}/auth/refresh`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ refreshToken: refresh }),
      cache: 'no-store',
    });
    if (response.ok) {
      rotated = (await response.json()) as { accessToken: string; refreshToken: string };
      access = rotated.accessToken;
    }
  }

  if (!access && !request.nextUrl.pathname.startsWith('/login')) {
    const response = NextResponse.redirect(new URL('/login', request.url));
    response.cookies.delete('nc_admin_refresh');
    return response;
  }
  if (access && request.nextUrl.pathname === '/login') {
    return withRotatedSession(NextResponse.redirect(new URL('/dashboard', request.url)), rotated);
  }
  return withRotatedSession(NextResponse.next(), rotated);
}

function withRotatedSession(response: NextResponse, tokens?: { accessToken: string; refreshToken: string }) {
  if (!tokens) return response;
  const secure = process.env.NODE_ENV === 'production';
  response.cookies.set('nc_admin_access', tokens.accessToken, { httpOnly: true, secure, sameSite: 'strict', path: '/', maxAge: 900 });
  response.cookies.set('nc_admin_refresh', tokens.refreshToken, { httpOnly: true, secure, sameSite: 'strict', path: '/', maxAge: 2592000 });
  return response;
}

export const config = {
  matcher: ['/dashboard/:path*', '/users/:path*', '/reports/:path*', '/media/:path*', '/analytics/:path*', '/subscriptions/:path*', '/plans/:path*', '/login'],
};
