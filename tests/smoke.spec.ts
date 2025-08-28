import { test, expect } from '@playwright/test'

test('app loads successfully', async ({ page }) => {
  await page.goto('/')
  
  // Basic smoke test - just check that the page loads and has some content
  await expect(page.locator('body')).toBeVisible()
  
  // Check for React app root
  await expect(page.locator('#root')).toBeVisible()
  
  // Page should have a title
  await expect(page).toHaveTitle(/React/)
})
