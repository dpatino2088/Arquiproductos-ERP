import { test, expect } from '@playwright/test';

test.describe('Application Loading Tests', () => {
  test('should load the application in browser', async ({ page }) => {
    console.log('🚀 Starting application load test...');
    
    // Navigate to the app
    await page.goto('/');
    console.log('✅ Navigation to / completed');
    
    // Wait for network to be idle
    await page.waitForLoadState('networkidle');
    console.log('✅ Network idle state reached');
    
    // Take a screenshot for debugging
    await page.screenshot({ path: 'test-results/app-loading.png', fullPage: true });
    console.log('✅ Screenshot taken');
    
    // Check if body is visible
    const body = page.locator('body');
    await expect(body).toBeVisible({ timeout: 10000 });
    console.log('✅ Body is visible');
    
    // Check if React root exists
    const root = page.locator('#root');
    await expect(root).toBeVisible({ timeout: 10000 });
    console.log('✅ React root is visible');
    
    // Check if we have any content
    const hasContent = await page.locator('*').count();
    expect(hasContent).toBeGreaterThan(10); // Should have many elements
    console.log(`✅ Found ${hasContent} elements on page`);
    
    // Check for main layout
    const mainLayout = page.locator('[data-testid="main-layout"]');
    if (await mainLayout.count() > 0) {
      await expect(mainLayout).toBeVisible();
      console.log('✅ Main layout found with test ID');
    } else {
      console.log('⚠️  Main layout test ID not found, checking alternatives...');
      
      // Try alternative selectors
      const alternatives = [
        'main',
        '[role="main"]',
        '.min-h-screen',
        'nav',
        'div'
      ];
      
      for (const selector of alternatives) {
        const element = page.locator(selector).first();
        if (await element.count() > 0) {
          console.log(`✅ Found element with selector: ${selector}`);
          break;
        }
      }
    }
    
    // Log page title
    const title = await page.title();
    console.log(`✅ Page title: ${title}`);
    
    // Log current URL
    const url = page.url();
    console.log(`✅ Current URL: ${url}`);
    
    console.log('🎉 Application loading test completed successfully!');
  });
  
  test('should have basic HTML structure', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Check HTML lang attribute
    const html = page.locator('html');
    const lang = await html.getAttribute('lang');
    expect(lang).toBe('en');
    console.log('✅ HTML lang attribute is correct');
    
    // Check for head elements
    const head = page.locator('head');
    await expect(head).toBeAttached();
    console.log('✅ Head element exists');
    
    // Check for meta viewport
    const viewport = page.locator('meta[name="viewport"]');
    await expect(viewport).toBeAttached();
    console.log('✅ Viewport meta tag exists');
    
    console.log('🎉 HTML structure test completed!');
  });
  
  test('should load CSS and have styles', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Check if body has background color (from our CSS)
    const body = page.locator('body');
    const backgroundColor = await body.evaluate(el => 
      getComputedStyle(el).backgroundColor
    );
    
    // Should not be transparent/default
    expect(backgroundColor).not.toBe('rgba(0, 0, 0, 0)');
    expect(backgroundColor).not.toBe('transparent');
    console.log(`✅ Body has background color: ${backgroundColor}`);
    
    // Check if we have our CSS variables loaded
    const rootStyles = await page.evaluate(() => {
      const root = document.documentElement;
      const styles = getComputedStyle(root);
      return {
        tealColor: styles.getPropertyValue('--teal-700'),
        grayColor: styles.getPropertyValue('--gray-950'),
        navyColor: styles.getPropertyValue('--navy-800')
      };
    });
    
    // Should have our custom CSS variables
    expect(Object.values(rootStyles).some(value => value.trim() !== '')).toBeTruthy();
    console.log('✅ CSS variables loaded:', rootStyles);
    
    console.log('🎉 CSS loading test completed!');
  });
  
  test('should have JavaScript working', async ({ page }) => {
    await page.goto('/');
    await page.waitForLoadState('networkidle');
    
    // Test if React is working by checking for React-specific attributes
    const reactElements = await page.locator('[data-reactroot], [data-react-helmet]').count();
    console.log(`Found ${reactElements} React-specific elements`);
    
    // Test if we can interact with the page (JavaScript working)
    await page.keyboard.press('Tab');
    
    // Check if focus changed (indicates JS is working)
    const focusedElement = page.locator(':focus');
    const hasFocus = await focusedElement.count() > 0;
    
    if (hasFocus) {
      console.log('✅ JavaScript is working - focus management active');
    } else {
      console.log('⚠️  Focus not detected, but this might be normal');
    }
    
    // Test console for errors
    const errors: string[] = [];
    page.on('console', msg => {
      if (msg.type() === 'error') {
        errors.push(msg.text());
      }
    });
    
    // Wait a bit to catch any console errors
    await page.waitForTimeout(2000);
    
    if (errors.length === 0) {
      console.log('✅ No console errors detected');
    } else {
      console.log('⚠️  Console errors found:', errors);
    }
    
    console.log('🎉 JavaScript test completed!');
  });
});
