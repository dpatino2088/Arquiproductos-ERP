import { expect, test } from '@playwright/test';

const E2E_EMAIL = process.env.ADAPTIO_E2E_EMAIL;
const E2E_PASSWORD = process.env.ADAPTIO_E2E_PASSWORD;

async function loginIfNeeded(page: import('@playwright/test').Page) {
  await page.goto('/accounting/chart');

  if (!page.url().includes('/login')) return;

  if (!E2E_EMAIL || !E2E_PASSWORD) {
    throw new Error('Missing ADAPTIO_E2E_EMAIL or ADAPTIO_E2E_PASSWORD environment variables.');
  }

  await page.getByLabel('Email').fill(E2E_EMAIL);
  await page.getByLabel('Password').fill(E2E_PASSWORD);
  await page.getByRole('button', { name: 'Sign In' }).click();
  await expect(page).not.toHaveURL(/\/login$/);
}

test.describe('Accounting smoke', () => {
  test('module tabs are visible and navigable', async ({ page }) => {
    test.skip(!E2E_EMAIL || !E2E_PASSWORD, 'Set ADAPTIO_E2E_EMAIL and ADAPTIO_E2E_PASSWORD for smoke tests.');
    await loginIfNeeded(page);

    await page.goto('/accounting/chart');
    await expect(page.getByRole('heading', { name: 'Chart of Accounts' })).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Chart of Accounts' })).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Journal Entries' })).toBeVisible();
    await expect(page.getByRole('tab', { name: 'Reports' })).toBeVisible();

    await page.getByRole('tab', { name: 'Journal Entries' }).click();
    await expect(page).toHaveURL(/\/accounting\/journal$/);
    await expect(page.getByRole('heading', { name: 'Journal Entries' })).toBeVisible();

    await page.getByRole('tab', { name: 'Reports' }).click();
    await expect(page).toHaveURL(/\/accounting\/reports$/);
    await expect(page.getByRole('heading', { name: 'Accounting Reports' })).toBeVisible();
  });

  test('manual journal form enforces balanced entry before submit', async ({ page }) => {
    test.skip(!E2E_EMAIL || !E2E_PASSWORD, 'Set ADAPTIO_E2E_EMAIL and ADAPTIO_E2E_PASSWORD for smoke tests.');
    await loginIfNeeded(page);

    await page.goto('/accounting/journal/new');
    await expect(page.getByRole('heading', { name: 'Nuevo Asiento Manual' })).toBeVisible();

    await page.getByPlaceholder('Ej: Pago de alquiler de marzo').fill('Smoke validation only');
    await page.locator('select').nth(0).selectOption({ label: '1200 · Inventory Asset' });
    await page.locator('select').nth(1).selectOption({ label: '3000 · Owners Equity' });

    const debitFirstRow = page.locator('input[type="number"]').nth(0);
    const creditSecondRow = page.locator('input[type="number"]').nth(3);
    const submitButton = page.getByRole('button', { name: 'Postear asiento' });

    await debitFirstRow.fill('1000');
    await expect(submitButton).toBeDisabled();

    await creditSecondRow.fill('1000');
    await expect(submitButton).toBeEnabled();
  });

  test('reports page loads all report tabs', async ({ page }) => {
    test.skip(!E2E_EMAIL || !E2E_PASSWORD, 'Set ADAPTIO_E2E_EMAIL and ADAPTIO_E2E_PASSWORD for smoke tests.');
    await loginIfNeeded(page);

    await page.goto('/accounting/reports');
    await expect(page.getByRole('heading', { name: 'Accounting Reports' })).toBeVisible();

    await page.getByRole('button', { name: 'Trial Balance' }).click();
    await expect(page.getByText('As of:')).toBeVisible();

    await page.getByRole('button', { name: 'General Ledger' }).click();
    await expect(page.getByRole('combobox', { name: 'Todas las cuentas' })).toBeVisible();

    await page.getByRole('button', { name: 'Profit & Loss' }).click();
    await expect(page.getByText('UTILIDAD NETA')).toBeVisible();

    await page.getByRole('button', { name: 'Balance Sheet' }).click();
    await expect(page.getByText('TOTAL ACTIVOS')).toBeVisible();
  });
});
