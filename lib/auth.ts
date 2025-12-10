"use server";

import { cookies } from 'next/headers';
import { redirect } from 'next/navigation';
import {
  createServerActionClient,
  createServerComponentClient
} from '@supabase/auth-helpers-nextjs';
import { Database } from './types';

export const getServerComponentClient = () => createServerComponentClient<Database>({ cookies });

export const requireUser = async () => {
  const supabase = getServerComponentClient();
  const {
    data: { user }
  } = await supabase.auth.getUser();

  if (!user) {
    redirect('/(auth)/login');
  }

  return user;
};

export async function signOut() {
  const supabase = createServerActionClient<Database>({ cookies });
  await supabase.auth.signOut();
  redirect('/(auth)/login');
}

