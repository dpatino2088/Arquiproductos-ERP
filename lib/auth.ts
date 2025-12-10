"use server";

import { redirect } from 'next/navigation';

export type SimpleUser = {
  id: string;
  email: string;
  name?: string;
};

export async function getUser(): Promise<SimpleUser> {
  // TEMP: simple auth stub for local development.
  // Later we will plug in Supabase auth properly.
  return {
    id: 'dev-user-id',
    email: 'dev@arquiproductos.local',
    name: 'Dev User'
  };
}

// Stub signOut to keep existing callers working during local dev.
export async function signOut() {
  redirect('/(auth)/login');
}

