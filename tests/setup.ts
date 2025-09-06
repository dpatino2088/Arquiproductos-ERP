import { test as base } from '@playwright/test';

// Extend the base test with custom setup
export const test = base.extend({
  // Custom page fixture with better error handling
  page: async ({ page }, use) => {
    // Set longer timeouts
    page.setDefaultTimeout(30000);
    page.setDefaultNavigationTimeout(30000);
    
    // Add better error handling
    page.on('pageerror', (error) => {
      console.log('Page error:', error.message);
    });
    
    page.on('console', (msg) => {
      if (msg.type() === 'error') {
        console.log('Console error:', msg.text());
      }
    });
    
    // Add request/response logging for debugging
    page.on('request', (request) => {
      if (request.url().includes('localhost')) {
        console.log('Request:', request.method(), request.url());
      }
    });
    
    page.on('response', (response) => {
      if (response.url().includes('localhost') && !response.ok()) {
        console.log('Failed response:', response.status(), response.url());
      }
    });
    
    await use(page);
  },
});

export { expect } from '@playwright/test';
