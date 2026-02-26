import { create } from 'zustand';

type LoadFn = (() => void) | undefined;

interface DirectoryLoadState {
  contactsScopeKey: string | null;
  customersScopeKey: string | null;
  quotesScopeKey: string | null;
  proposalsScopeKey: string | null;
  ordersScopeKey: string | null;
  loadContacts: LoadFn;
  loadCustomers: LoadFn;
  loadQuotes: LoadFn;
  loadProposals: LoadFn;
  loadOrders: LoadFn;
  setContactsScopeKey: (key: string | null) => void;
  setCustomersScopeKey: (key: string | null) => void;
  setQuotesScopeKey: (key: string | null) => void;
  setProposalsScopeKey: (key: string | null) => void;
  setOrdersScopeKey: (key: string | null) => void;
  setLoadContacts: (fn: LoadFn) => void;
  setLoadCustomers: (fn: LoadFn) => void;
  setLoadQuotes: (fn: LoadFn) => void;
  setLoadProposals: (fn: LoadFn) => void;
  setLoadOrders: (fn: LoadFn) => void;
}

export const useDirectoryLoadStore = create<DirectoryLoadState>((set) => ({
  contactsScopeKey: null,
  customersScopeKey: null,
  quotesScopeKey: null,
  proposalsScopeKey: null,
  ordersScopeKey: null,
  loadContacts: undefined,
  loadCustomers: undefined,
  loadQuotes: undefined,
  loadProposals: undefined,
  loadOrders: undefined,
  setContactsScopeKey: (contactsScopeKey) => set({ contactsScopeKey }),
  setCustomersScopeKey: (customersScopeKey) => set({ customersScopeKey }),
  setQuotesScopeKey: (quotesScopeKey) => set({ quotesScopeKey }),
  setProposalsScopeKey: (proposalsScopeKey) => set({ proposalsScopeKey }),
  setOrdersScopeKey: (ordersScopeKey) => set({ ordersScopeKey }),
  setLoadContacts: (loadContacts) => set({ loadContacts }),
  setLoadCustomers: (loadCustomers) => set({ loadCustomers }),
  setLoadQuotes: (loadQuotes) => set({ loadQuotes }),
  setLoadProposals: (loadProposals) => set({ loadProposals }),
  setLoadOrders: (loadOrders) => set({ loadOrders }),
}));
