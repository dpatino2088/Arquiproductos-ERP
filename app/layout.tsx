import './globals.css';
import { Inter } from 'next/font/google';
import type { Metadata } from 'next';
import { cn } from '@/components/ui/cn';

const inter = Inter({
  subsets: ['latin'],
  variable: '--font-inter',
  display: 'swap'
});

export const metadata: Metadata = {
  title: 'Arquiproductos ERP',
  description: 'Multi-company ERP for Arquiproductos',
  applicationName: 'ArquiproductosERP'
};

export default function RootLayout({ children }: { children: React.ReactNode }) {
  return (
    <html lang="es" className={cn(inter.variable)}>
      <body className="bg-background text-foreground">{children}</body>
    </html>
  );
}

