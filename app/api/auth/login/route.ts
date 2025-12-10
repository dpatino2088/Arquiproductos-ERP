import { cookies } from 'next/headers';
import { NextResponse } from 'next/server';
import { createRouteHandlerClient } from '@supabase/auth-helpers-nextjs';
import { Database } from '@/lib/types';

export async function POST(request: Request) {
  const formData = await request.formData();
  const email = String(formData.get('email') ?? '');
  const password = String(formData.get('password') ?? '');

  const supabase = createRouteHandlerClient<Database>({ cookies });
  const { error } = await supabase.auth.signInWithPassword({ email, password });

  if (error) {
    const url = new URL(request.url);
    url.searchParams.set('error', 'Invalid credentials');
    return NextResponse.redirect(url, { status: 302 });
  }

  return NextResponse.redirect(new URL('/(dashboard)', request.url), { status: 302 });
}

