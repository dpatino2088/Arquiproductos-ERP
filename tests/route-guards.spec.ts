import { test, expect } from '@playwright/test';

test.describe('Route Guards', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to the app (authentication is now bypassed)
    await page.goto('/');
    
    // Wait for the main navigation to appear (no login required)
    await page.waitForSelector('[aria-label="Main navigation"]');
  });

  test('should redirect management routes to personal dashboard when in personal view', async ({ page }) => {
    // Ensure we're in personal view (default) - check the navbar indicator
    await expect(page.locator('div:has-text("Secure Corp") span:has-text("Personal")')).toBeVisible();
    
    // Try to navigate directly to a management route
    await page.goto('/management/dashboard');
    
    // Should be redirected to personal dashboard
    await expect(page).toHaveURL('/personal/dashboard');
    
    // Check console for warning message
    const consoleMessages = [];
    page.on('console', msg => consoleMessages.push(msg.text()));
    
    await page.goto('/management/reports');
    await page.waitForTimeout(100); // Wait for console message
    
    // Should be redirected to personal dashboard
    await expect(page).toHaveURL('/personal/dashboard');
    
    // Should have logged access denial
    const hasAccessDeniedMessage = consoleMessages.some(msg => 
      msg.includes('Access denied to route: /management/reports')
    );
    expect(hasAccessDeniedMessage).toBeTruthy();
  });

  test('should allow access to management routes when in management view', async ({ page }) => {
    // Switch to management view via user dropdown
    await page.click('[aria-label="My Account"]'); // Click user icon
    await page.click('text=Switch to Manager View'); // Click view toggle
    
    // Wait for view to change
    await expect(page.locator('div:has-text("Secure Corp") span:has-text("Management")')).toBeVisible();
    
    // Now try to navigate to management routes - should work
    await page.goto('/management/dashboard');
    await expect(page).toHaveURL('/management/dashboard');
    
    await page.goto('/management/reports');
    await expect(page).toHaveURL('/management/reports');
  });

  test('should allow access to personal routes from both views', async ({ page }) => {
    // Test from personal view
    await page.goto('/personal/dashboard');
    await expect(page).toHaveURL('/personal/dashboard');
    
    await page.goto('/inbox');
    await expect(page).toHaveURL('/inbox');
    
    // Switch to management view via user dropdown
    await page.click('[aria-label="My Account"]'); // Click user icon
    await page.click('text=Switch to Manager View'); // Click view toggle
    await expect(page.locator('div:has-text("Secure Corp") span:has-text("Management")')).toBeVisible();
    
    // Test from management view - personal routes should still work
    await page.goto('/personal/dashboard');
    await expect(page).toHaveURL('/personal/dashboard');
    
    await page.goto('/inbox');
    await expect(page).toHaveURL('/inbox');
  });

  test('should protect payroll route in personal view', async ({ page }) => {
    // Ensure we're in personal view
    await expect(page.locator('div:has-text("Secure Corp") span:has-text("Personal")')).toBeVisible();
    
    // Try to access payroll route
    await page.goto('/payroll');
    
    // Should be redirected to personal dashboard
    await expect(page).toHaveURL('/personal/dashboard');
  });
});
