# 🧪 ACCESSIBILITY TESTING GUIDE

## 📋 **COMPREHENSIVE TESTING STRATEGY**

### **🎯 TESTING PHILOSOPHY**
Test accessibility **one page at a time** to ensure thorough coverage and easier debugging. This approach allows for:
- **Focused testing** - Isolate issues to specific pages
- **Faster debugging** - Pinpoint exact problems
- **Better coverage** - Ensure no page is missed
- **Incremental progress** - Build confidence step by step

---

## 🔧 **TESTING ENVIRONMENT SETUP**

### **✅ Prerequisites:**
```bash
# 1. Clean Vite cache (CRITICAL for test stability)
rm -rf node_modules/.vite

# 2. Restart dev server
pkill -f "vite"
npm run dev

# 3. Verify server is responding
curl -I http://localhost:5173
```

### **✅ Playwright Configuration:**
```typescript
// playwright.config.ts - Optimized for accessibility testing
export default defineConfig({
  testDir: './tests',
  fullyParallel: false, // CRITICAL: Disable parallel for stability
  workers: 1, // Single worker prevents conflicts
  timeout: 60000, // Sufficient timeout for loading
  expect: { timeout: 10000 },
  
  use: {
    baseURL: 'http://localhost:5173',
    headless: false, // Headed mode for debugging
    viewport: { width: 1280, height: 720 },
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    timeout: 180000, // Allow time for Vite startup
    stdout: 'pipe',
    stderr: 'pipe',
  }
});
```

---

## 📊 **PAGE-BY-PAGE TESTING STRATEGY**

### **🎯 STEP 1: Create Page-Specific Tests**

#### **Template for Single Page Test:**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility - [PAGE_NAME]', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to specific page
    await page.goto('/[PAGE_URL]');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000); // Allow React to render
  });

  test('should have no accessibility violations on [PAGE_NAME]', async ({ page }) => {
    console.log('🔍 Testing accessibility for [PAGE_NAME]...');
    
    // Run axe-core scan
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .exclude(['.loading', '.spinner']) // Exclude loading states
      .analyze();

    // Log results
    console.log(`📊 Found ${accessibilityScanResults.violations.length} violations`);
    
    if (accessibilityScanResults.violations.length > 0) {
      accessibilityScanResults.violations.forEach((violation, index) => {
        console.log(`${index + 1}. ${violation.id} (${violation.impact}): ${violation.description}`);
      });
    }

    // Assert no critical violations
    const criticalViolations = accessibilityScanResults.violations.filter(
      v => v.impact === 'critical'
    );
    expect(criticalViolations).toEqual([]);
  });

  test('should have proper page structure on [PAGE_NAME]', async ({ page }) => {
    // Check H1 heading
    const h1 = page.locator('h1');
    await expect(h1).toBeVisible();
    
    // Check main content
    const main = page.locator('main, [role="main"]');
    await expect(main).toBeVisible();
    
    // Check navigation
    const nav = page.locator('nav, [role="navigation"]');
    await expect(nav).toBeVisible();
  });

  test('should support keyboard navigation on [PAGE_NAME]', async ({ page }) => {
    // Test tab navigation
    await page.keyboard.press('Tab');
    
    // Verify focus is visible
    const focusedElement = page.locator(':focus');
    await expect(focusedElement).toBeVisible();
    
    // Test skip links
    await page.keyboard.press('Tab');
    const skipLink = page.locator('.skip-link:focus');
    if (await skipLink.isVisible()) {
      console.log('✅ Skip link accessible via keyboard');
    }
  });
});
```

### **🎯 STEP 2: Page Priority List**

#### **🔥 HIGH PRIORITY PAGES (Test First):**
1. **Home/Dashboard** - `/` or `/dashboard`
2. **Employee Dashboard** - `/employee/dashboard`  
3. **Management Dashboard** - `/management/dashboard`
4. **Directory/People** - `/management/people/directory`
5. **Settings** - `/settings` or `/management/settings`

#### **📋 MEDIUM PRIORITY PAGES:**
6. **Time & Attendance** - `/time-and-attendance/*`
7. **PTO & Leaves** - `/pto-and-leaves/*`
8. **Performance** - `/performance/*`
9. **Benefits** - `/benefits/*`
10. **Expenses** - `/expenses/*`

#### **📝 LOW PRIORITY PAGES:**
11. **Company Knowledge** - `/company-knowledge/*`
12. **IT Management** - `/it-management/*`
13. **Wellness** - `/wellness/*`
14. **Payroll** - `/payroll/*` (if accessible)

### **🎯 STEP 3: Testing Commands**

#### **Single Page Testing:**
```bash
# Test specific page
npx playwright test tests/accessibility-[page-name].spec.ts --project=chromium

# Test with debugging
npx playwright test tests/accessibility-[page-name].spec.ts --headed --debug

# Test with trace
npx playwright test tests/accessibility-[page-name].spec.ts --trace=on
```

#### **Progressive Testing:**
```bash
# Test high priority pages first
npx playwright test tests/accessibility-home.spec.ts
npx playwright test tests/accessibility-employee-dashboard.spec.ts  
npx playwright test tests/accessibility-management-dashboard.spec.ts
npx playwright test tests/accessibility-directory.spec.ts
npx playwright test tests/accessibility-settings.spec.ts
```

---

## 🛠️ **COMMON ISSUES & SOLUTIONS**

### **❌ Problem: Vite Cache Issues**
```
Error: 504 (Outdated Optimize Dep)
```
**✅ Solution:**
```bash
rm -rf node_modules/.vite
pkill -f "vite"
npm run dev
```

### **❌ Problem: React Not Loading**
```
Error: body is hidden, no elements found
```
**✅ Solution:**
```typescript
// Add longer waits in tests
await page.waitForLoadState('networkidle');
await page.waitForTimeout(3000);
await page.waitForFunction(() => document.getElementById('root')?.children.length > 0);
```

### **❌ Problem: Navigation Timeouts**
```
Error: page.waitForURL timeout
```
**✅ Solution:**
```typescript
// Use more flexible navigation
await page.click('[data-testid="nav-button"]');
await page.waitForLoadState('networkidle', { timeout: 30000 });
// Don't rely on exact URL matching
```

### **❌ Problem: ARIA Violations**
```
Error: aria-required-children, aria-required-parent
```
**✅ Solution:**
```typescript
// Use proper ARIA structure
// ❌ Wrong:
<ul role="menu">
  <li><button role="menuitem">Item</button></li>
</ul>

// ✅ Correct:
<div role="navigation">
  <button aria-label="Item">Item</button>
</div>

// OR for actual menus:
<div role="menu">
  <button role="menuitem">Item</button>
</div>
```

---

## 📋 **TESTING CHECKLIST PER PAGE**

### **✅ MANDATORY CHECKS:**

#### **1. Axe-Core Scan:**
- [ ] 0 critical violations
- [ ] 0 serious violations  
- [ ] Document any moderate/minor violations

#### **2. HTML Structure:**
- [ ] Has H1 heading
- [ ] Has main content area
- [ ] Has navigation landmarks
- [ ] Proper heading hierarchy (H1 → H2 → H3)

#### **3. Keyboard Navigation:**
- [ ] Tab order is logical
- [ ] All interactive elements focusable
- [ ] Skip links work
- [ ] No keyboard traps

#### **4. ARIA Implementation:**
- [ ] Proper roles and labels
- [ ] Dynamic content has live regions
- [ ] Form elements have labels
- [ ] Error messages are announced

#### **5. Focus Management:**
- [ ] Focus indicators visible
- [ ] Focus moves logically
- [ ] Focus restored after modals
- [ ] Custom focus styles work

#### **6. Color & Contrast:**
- [ ] Text contrast ≥ 4.5:1
- [ ] Interactive elements ≥ 3:1
- [ ] No color-only information
- [ ] High contrast mode support

---

## 🎯 **WCAG 2.2 AA REQUIREMENTS**

### **✅ LEVEL A (MUST HAVE):**
- **1.1.1** Non-text Content
- **1.3.1** Info and Relationships  
- **1.3.2** Meaningful Sequence
- **1.3.3** Sensory Characteristics
- **1.4.1** Use of Color
- **2.1.1** Keyboard
- **2.1.2** No Keyboard Trap
- **2.4.1** Bypass Blocks
- **2.4.2** Page Titled
- **3.1.1** Language of Page
- **4.1.1** Parsing
- **4.1.2** Name, Role, Value

### **✅ LEVEL AA (MUST HAVE):**
- **1.4.3** Contrast (Minimum) - 4.5:1
- **1.4.4** Resize Text - 200%
- **2.4.3** Focus Order
- **2.4.6** Headings and Labels
- **2.4.7** Focus Visible
- **3.1.2** Language of Parts
- **3.2.1** On Focus
- **3.2.2** On Input
- **3.3.1** Error Identification
- **3.3.2** Labels or Instructions

### **✅ LEVEL AAA (NICE TO HAVE):**
- **1.4.6** Contrast (Enhanced) - 7:1
- **2.4.8** Location
- **2.4.9** Link Purpose (Link Only)
- **3.3.5** Help

---

## 📊 **REPORTING TEMPLATE**

### **Page Test Report:**
```markdown
# Accessibility Test Report - [PAGE_NAME]

## 📊 Test Results
- **Date:** [DATE]
- **Page:** [PAGE_URL]
- **WCAG Score:** [SCORE]/100
- **Critical Violations:** [COUNT]
- **Total Violations:** [COUNT]

## ✅ Passed Checks
- [ ] Axe-core scan (0 critical violations)
- [ ] HTML structure (H1, main, nav)
- [ ] Keyboard navigation (tab order, skip links)
- [ ] ARIA implementation (roles, labels)
- [ ] Focus management (indicators, order)
- [ ] Color contrast (4.5:1 minimum)

## ❌ Issues Found
1. **[Issue Type]** - [Description]
   - **Impact:** [Critical/Serious/Moderate/Minor]
   - **Fix:** [Solution]

## 🎯 Recommendations
- [Recommendation 1]
- [Recommendation 2]

## 📈 Next Steps
- [ ] Fix critical issues
- [ ] Re-test page
- [ ] Move to next page
```

---

## 🚀 **AUTOMATION SCRIPTS**

### **Create Page Test Script:**
```bash
#!/bin/bash
# create-page-test.sh

PAGE_NAME=$1
PAGE_URL=$2

if [ -z "$PAGE_NAME" ] || [ -z "$PAGE_URL" ]; then
  echo "Usage: ./create-page-test.sh <page-name> <page-url>"
  exit 1
fi

# Create test file
cat > "tests/accessibility-${PAGE_NAME}.spec.ts" << EOF
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility - ${PAGE_NAME}', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('${PAGE_URL}');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
  });

  test('should have no critical accessibility violations', async ({ page }) => {
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .analyze();

    const critical = results.violations.filter(v => v.impact === 'critical');
    expect(critical).toEqual([]);
  });

  test('should have proper page structure', async ({ page }) => {
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('main, [role="main"]')).toBeVisible();
    await expect(page.locator('nav, [role="navigation"]')).toBeVisible();
  });

  test('should support keyboard navigation', async ({ page }) => {
    await page.keyboard.press('Tab');
    await expect(page.locator(':focus')).toBeVisible();
  });
});
EOF

echo "✅ Created test file: tests/accessibility-${PAGE_NAME}.spec.ts"
echo "🚀 Run with: npx playwright test tests/accessibility-${PAGE_NAME}.spec.ts"
```

### **Batch Test Runner:**
```bash
#!/bin/bash
# test-all-pages.sh

PAGES=(
  "home:/"
  "employee-dashboard:/employee/dashboard"
  "management-dashboard:/management/dashboard"
  "directory:/management/people/directory"
  "settings:/settings"
)

for page in "${PAGES[@]}"; do
  IFS=':' read -r name url <<< "$page"
  echo "🧪 Testing $name ($url)..."
  
  npx playwright test "tests/accessibility-${name}.spec.ts" --project=chromium
  
  if [ $? -eq 0 ]; then
    echo "✅ $name passed"
  else
    echo "❌ $name failed"
    echo "🔍 Check report: npx playwright show-report"
    read -p "Continue? (y/n): " continue
    if [ "$continue" != "y" ]; then
      break
    fi
  fi
done

echo "🎉 All page tests completed!"
```

---

## 🎯 **SUCCESS CRITERIA**

### **✅ PAGE PASSES WHEN:**
1. **0 critical accessibility violations**
2. **All mandatory WCAG 2.2 AA criteria met**
3. **Keyboard navigation works completely**
4. **Screen reader compatibility verified**
5. **Color contrast meets 4.5:1 minimum**
6. **Focus management is proper**

### **✅ PROJECT PASSES WHEN:**
1. **All high-priority pages pass**
2. **90%+ of all pages pass**
3. **No critical violations across site**
4. **Comprehensive test coverage**
5. **Documentation complete**

---

## 📚 **RESOURCES & REFERENCES**

### **🔗 Testing Tools:**
- **Axe-core:** https://github.com/dequelabs/axe-core
- **Playwright:** https://playwright.dev/
- **WAVE:** https://wave.webaim.org/
- **Lighthouse:** https://developers.google.com/web/tools/lighthouse

### **🔗 WCAG Guidelines:**
- **WCAG 2.2:** https://www.w3.org/WAI/WCAG22/quickref/
- **Techniques:** https://www.w3.org/WAI/WCAG22/Techniques/
- **Understanding:** https://www.w3.org/WAI/WCAG22/Understanding/

### **🔗 ARIA Patterns:**
- **APG:** https://www.w3.org/WAI/ARIA/apg/
- **Examples:** https://www.w3.org/WAI/ARIA/apg/patterns/

---

**Remember: Test one page at a time, fix issues immediately, and build confidence progressively. Quality over speed!** 🎯✨

## 📋 **COMPREHENSIVE TESTING STRATEGY**

### **🎯 TESTING PHILOSOPHY**
Test accessibility **one page at a time** to ensure thorough coverage and easier debugging. This approach allows for:
- **Focused testing** - Isolate issues to specific pages
- **Faster debugging** - Pinpoint exact problems
- **Better coverage** - Ensure no page is missed
- **Incremental progress** - Build confidence step by step

---

## 🔧 **TESTING ENVIRONMENT SETUP**

### **✅ Prerequisites:**
```bash
# 1. Clean Vite cache (CRITICAL for test stability)
rm -rf node_modules/.vite

# 2. Restart dev server
pkill -f "vite"
npm run dev

# 3. Verify server is responding
curl -I http://localhost:5173
```

### **✅ Playwright Configuration:**
```typescript
// playwright.config.ts - Optimized for accessibility testing
export default defineConfig({
  testDir: './tests',
  fullyParallel: false, // CRITICAL: Disable parallel for stability
  workers: 1, // Single worker prevents conflicts
  timeout: 60000, // Sufficient timeout for loading
  expect: { timeout: 10000 },
  
  use: {
    baseURL: 'http://localhost:5173',
    headless: false, // Headed mode for debugging
    viewport: { width: 1280, height: 720 },
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    timeout: 180000, // Allow time for Vite startup
    stdout: 'pipe',
    stderr: 'pipe',
  }
});
```

---

## 📊 **PAGE-BY-PAGE TESTING STRATEGY**

### **🎯 STEP 1: Create Page-Specific Tests**

#### **Template for Single Page Test:**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility - [PAGE_NAME]', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to specific page
    await page.goto('/[PAGE_URL]');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000); // Allow React to render
  });

  test('should have no accessibility violations on [PAGE_NAME]', async ({ page }) => {
    console.log('🔍 Testing accessibility for [PAGE_NAME]...');
    
    // Run axe-core scan
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .exclude(['.loading', '.spinner']) // Exclude loading states
      .analyze();

    // Log results
    console.log(`📊 Found ${accessibilityScanResults.violations.length} violations`);
    
    if (accessibilityScanResults.violations.length > 0) {
      accessibilityScanResults.violations.forEach((violation, index) => {
        console.log(`${index + 1}. ${violation.id} (${violation.impact}): ${violation.description}`);
      });
    }

    // Assert no critical violations
    const criticalViolations = accessibilityScanResults.violations.filter(
      v => v.impact === 'critical'
    );
    expect(criticalViolations).toEqual([]);
  });

  test('should have proper page structure on [PAGE_NAME]', async ({ page }) => {
    // Check H1 heading
    const h1 = page.locator('h1');
    await expect(h1).toBeVisible();
    
    // Check main content
    const main = page.locator('main, [role="main"]');
    await expect(main).toBeVisible();
    
    // Check navigation
    const nav = page.locator('nav, [role="navigation"]');
    await expect(nav).toBeVisible();
  });

  test('should support keyboard navigation on [PAGE_NAME]', async ({ page }) => {
    // Test tab navigation
    await page.keyboard.press('Tab');
    
    // Verify focus is visible
    const focusedElement = page.locator(':focus');
    await expect(focusedElement).toBeVisible();
    
    // Test skip links
    await page.keyboard.press('Tab');
    const skipLink = page.locator('.skip-link:focus');
    if (await skipLink.isVisible()) {
      console.log('✅ Skip link accessible via keyboard');
    }
  });
});
```

### **🎯 STEP 2: Page Priority List**

#### **🔥 HIGH PRIORITY PAGES (Test First):**
1. **Home/Dashboard** - `/` or `/dashboard`
2. **Employee Dashboard** - `/employee/dashboard`  
3. **Management Dashboard** - `/management/dashboard`
4. **Directory/People** - `/management/people/directory`
5. **Settings** - `/settings` or `/management/settings`

#### **📋 MEDIUM PRIORITY PAGES:**
6. **Time & Attendance** - `/time-and-attendance/*`
7. **PTO & Leaves** - `/pto-and-leaves/*`
8. **Performance** - `/performance/*`
9. **Benefits** - `/benefits/*`
10. **Expenses** - `/expenses/*`

#### **📝 LOW PRIORITY PAGES:**
11. **Company Knowledge** - `/company-knowledge/*`
12. **IT Management** - `/it-management/*`
13. **Wellness** - `/wellness/*`
14. **Payroll** - `/payroll/*` (if accessible)

### **🎯 STEP 3: Testing Commands**

#### **Single Page Testing:**
```bash
# Test specific page
npx playwright test tests/accessibility-[page-name].spec.ts --project=chromium

# Test with debugging
npx playwright test tests/accessibility-[page-name].spec.ts --headed --debug

# Test with trace
npx playwright test tests/accessibility-[page-name].spec.ts --trace=on
```

#### **Progressive Testing:**
```bash
# Test high priority pages first
npx playwright test tests/accessibility-home.spec.ts
npx playwright test tests/accessibility-employee-dashboard.spec.ts  
npx playwright test tests/accessibility-management-dashboard.spec.ts
npx playwright test tests/accessibility-directory.spec.ts
npx playwright test tests/accessibility-settings.spec.ts
```

---

## 🛠️ **COMMON ISSUES & SOLUTIONS**

### **❌ Problem: Vite Cache Issues**
```
Error: 504 (Outdated Optimize Dep)
```
**✅ Solution:**
```bash
rm -rf node_modules/.vite
pkill -f "vite"
npm run dev
```

### **❌ Problem: React Not Loading**
```
Error: body is hidden, no elements found
```
**✅ Solution:**
```typescript
// Add longer waits in tests
await page.waitForLoadState('networkidle');
await page.waitForTimeout(3000);
await page.waitForFunction(() => document.getElementById('root')?.children.length > 0);
```

### **❌ Problem: Navigation Timeouts**
```
Error: page.waitForURL timeout
```
**✅ Solution:**
```typescript
// Use more flexible navigation
await page.click('[data-testid="nav-button"]');
await page.waitForLoadState('networkidle', { timeout: 30000 });
// Don't rely on exact URL matching
```

### **❌ Problem: ARIA Violations**
```
Error: aria-required-children, aria-required-parent
```
**✅ Solution:**
```typescript
// Use proper ARIA structure
// ❌ Wrong:
<ul role="menu">
  <li><button role="menuitem">Item</button></li>
</ul>

// ✅ Correct:
<div role="navigation">
  <button aria-label="Item">Item</button>
</div>

// OR for actual menus:
<div role="menu">
  <button role="menuitem">Item</button>
</div>
```

---

## 📋 **TESTING CHECKLIST PER PAGE**

### **✅ MANDATORY CHECKS:**

#### **1. Axe-Core Scan:**
- [ ] 0 critical violations
- [ ] 0 serious violations  
- [ ] Document any moderate/minor violations

#### **2. HTML Structure:**
- [ ] Has H1 heading
- [ ] Has main content area
- [ ] Has navigation landmarks
- [ ] Proper heading hierarchy (H1 → H2 → H3)

#### **3. Keyboard Navigation:**
- [ ] Tab order is logical
- [ ] All interactive elements focusable
- [ ] Skip links work
- [ ] No keyboard traps

#### **4. ARIA Implementation:**
- [ ] Proper roles and labels
- [ ] Dynamic content has live regions
- [ ] Form elements have labels
- [ ] Error messages are announced

#### **5. Focus Management:**
- [ ] Focus indicators visible
- [ ] Focus moves logically
- [ ] Focus restored after modals
- [ ] Custom focus styles work

#### **6. Color & Contrast:**
- [ ] Text contrast ≥ 4.5:1
- [ ] Interactive elements ≥ 3:1
- [ ] No color-only information
- [ ] High contrast mode support

---

## 🎯 **WCAG 2.2 AA REQUIREMENTS**

### **✅ LEVEL A (MUST HAVE):**
- **1.1.1** Non-text Content
- **1.3.1** Info and Relationships  
- **1.3.2** Meaningful Sequence
- **1.3.3** Sensory Characteristics
- **1.4.1** Use of Color
- **2.1.1** Keyboard
- **2.1.2** No Keyboard Trap
- **2.4.1** Bypass Blocks
- **2.4.2** Page Titled
- **3.1.1** Language of Page
- **4.1.1** Parsing
- **4.1.2** Name, Role, Value

### **✅ LEVEL AA (MUST HAVE):**
- **1.4.3** Contrast (Minimum) - 4.5:1
- **1.4.4** Resize Text - 200%
- **2.4.3** Focus Order
- **2.4.6** Headings and Labels
- **2.4.7** Focus Visible
- **3.1.2** Language of Parts
- **3.2.1** On Focus
- **3.2.2** On Input
- **3.3.1** Error Identification
- **3.3.2** Labels or Instructions

### **✅ LEVEL AAA (NICE TO HAVE):**
- **1.4.6** Contrast (Enhanced) - 7:1
- **2.4.8** Location
- **2.4.9** Link Purpose (Link Only)
- **3.3.5** Help

---

## 📊 **REPORTING TEMPLATE**

### **Page Test Report:**
```markdown
# Accessibility Test Report - [PAGE_NAME]

## 📊 Test Results
- **Date:** [DATE]
- **Page:** [PAGE_URL]
- **WCAG Score:** [SCORE]/100
- **Critical Violations:** [COUNT]
- **Total Violations:** [COUNT]

## ✅ Passed Checks
- [ ] Axe-core scan (0 critical violations)
- [ ] HTML structure (H1, main, nav)
- [ ] Keyboard navigation (tab order, skip links)
- [ ] ARIA implementation (roles, labels)
- [ ] Focus management (indicators, order)
- [ ] Color contrast (4.5:1 minimum)

## ❌ Issues Found
1. **[Issue Type]** - [Description]
   - **Impact:** [Critical/Serious/Moderate/Minor]
   - **Fix:** [Solution]

## 🎯 Recommendations
- [Recommendation 1]
- [Recommendation 2]

## 📈 Next Steps
- [ ] Fix critical issues
- [ ] Re-test page
- [ ] Move to next page
```

---

## 🚀 **AUTOMATION SCRIPTS**

### **Create Page Test Script:**
```bash
#!/bin/bash
# create-page-test.sh

PAGE_NAME=$1
PAGE_URL=$2

if [ -z "$PAGE_NAME" ] || [ -z "$PAGE_URL" ]; then
  echo "Usage: ./create-page-test.sh <page-name> <page-url>"
  exit 1
fi

# Create test file
cat > "tests/accessibility-${PAGE_NAME}.spec.ts" << EOF
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility - ${PAGE_NAME}', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('${PAGE_URL}');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
  });

  test('should have no critical accessibility violations', async ({ page }) => {
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .analyze();

    const critical = results.violations.filter(v => v.impact === 'critical');
    expect(critical).toEqual([]);
  });

  test('should have proper page structure', async ({ page }) => {
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('main, [role="main"]')).toBeVisible();
    await expect(page.locator('nav, [role="navigation"]')).toBeVisible();
  });

  test('should support keyboard navigation', async ({ page }) => {
    await page.keyboard.press('Tab');
    await expect(page.locator(':focus')).toBeVisible();
  });
});
EOF

echo "✅ Created test file: tests/accessibility-${PAGE_NAME}.spec.ts"
echo "🚀 Run with: npx playwright test tests/accessibility-${PAGE_NAME}.spec.ts"
```

### **Batch Test Runner:**
```bash
#!/bin/bash
# test-all-pages.sh

PAGES=(
  "home:/"
  "employee-dashboard:/employee/dashboard"
  "management-dashboard:/management/dashboard"
  "directory:/management/people/directory"
  "settings:/settings"
)

for page in "${PAGES[@]}"; do
  IFS=':' read -r name url <<< "$page"
  echo "🧪 Testing $name ($url)..."
  
  npx playwright test "tests/accessibility-${name}.spec.ts" --project=chromium
  
  if [ $? -eq 0 ]; then
    echo "✅ $name passed"
  else
    echo "❌ $name failed"
    echo "🔍 Check report: npx playwright show-report"
    read -p "Continue? (y/n): " continue
    if [ "$continue" != "y" ]; then
      break
    fi
  fi
done

echo "🎉 All page tests completed!"
```

---

## 🎯 **SUCCESS CRITERIA**

### **✅ PAGE PASSES WHEN:**
1. **0 critical accessibility violations**
2. **All mandatory WCAG 2.2 AA criteria met**
3. **Keyboard navigation works completely**
4. **Screen reader compatibility verified**
5. **Color contrast meets 4.5:1 minimum**
6. **Focus management is proper**

### **✅ PROJECT PASSES WHEN:**
1. **All high-priority pages pass**
2. **90%+ of all pages pass**
3. **No critical violations across site**
4. **Comprehensive test coverage**
5. **Documentation complete**

---

## 📚 **RESOURCES & REFERENCES**

### **🔗 Testing Tools:**
- **Axe-core:** https://github.com/dequelabs/axe-core
- **Playwright:** https://playwright.dev/
- **WAVE:** https://wave.webaim.org/
- **Lighthouse:** https://developers.google.com/web/tools/lighthouse

### **🔗 WCAG Guidelines:**
- **WCAG 2.2:** https://www.w3.org/WAI/WCAG22/quickref/
- **Techniques:** https://www.w3.org/WAI/WCAG22/Techniques/
- **Understanding:** https://www.w3.org/WAI/WCAG22/Understanding/

### **🔗 ARIA Patterns:**
- **APG:** https://www.w3.org/WAI/ARIA/apg/
- **Examples:** https://www.w3.org/WAI/ARIA/apg/patterns/

---

**Remember: Test one page at a time, fix issues immediately, and build confidence progressively. Quality over speed!** 🎯✨

## 📋 **COMPREHENSIVE TESTING STRATEGY**

### **🎯 TESTING PHILOSOPHY**
Test accessibility **one page at a time** to ensure thorough coverage and easier debugging. This approach allows for:
- **Focused testing** - Isolate issues to specific pages
- **Faster debugging** - Pinpoint exact problems
- **Better coverage** - Ensure no page is missed
- **Incremental progress** - Build confidence step by step

---

## 🔧 **TESTING ENVIRONMENT SETUP**

### **✅ Prerequisites:**
```bash
# 1. Clean Vite cache (CRITICAL for test stability)
rm -rf node_modules/.vite

# 2. Restart dev server
pkill -f "vite"
npm run dev

# 3. Verify server is responding
curl -I http://localhost:5173
```

### **✅ Playwright Configuration:**
```typescript
// playwright.config.ts - Optimized for accessibility testing
export default defineConfig({
  testDir: './tests',
  fullyParallel: false, // CRITICAL: Disable parallel for stability
  workers: 1, // Single worker prevents conflicts
  timeout: 60000, // Sufficient timeout for loading
  expect: { timeout: 10000 },
  
  use: {
    baseURL: 'http://localhost:5173',
    headless: false, // Headed mode for debugging
    viewport: { width: 1280, height: 720 },
    video: 'retain-on-failure',
    screenshot: 'only-on-failure',
  },
  
  webServer: {
    command: 'npm run dev',
    url: 'http://localhost:5173',
    timeout: 180000, // Allow time for Vite startup
    stdout: 'pipe',
    stderr: 'pipe',
  }
});
```

---

## 📊 **PAGE-BY-PAGE TESTING STRATEGY**

### **🎯 STEP 1: Create Page-Specific Tests**

#### **Template for Single Page Test:**
```typescript
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility - [PAGE_NAME]', () => {
  test.beforeEach(async ({ page }) => {
    // Navigate to specific page
    await page.goto('/[PAGE_URL]');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000); // Allow React to render
  });

  test('should have no accessibility violations on [PAGE_NAME]', async ({ page }) => {
    console.log('🔍 Testing accessibility for [PAGE_NAME]...');
    
    // Run axe-core scan
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .exclude(['.loading', '.spinner']) // Exclude loading states
      .analyze();

    // Log results
    console.log(`📊 Found ${accessibilityScanResults.violations.length} violations`);
    
    if (accessibilityScanResults.violations.length > 0) {
      accessibilityScanResults.violations.forEach((violation, index) => {
        console.log(`${index + 1}. ${violation.id} (${violation.impact}): ${violation.description}`);
      });
    }

    // Assert no critical violations
    const criticalViolations = accessibilityScanResults.violations.filter(
      v => v.impact === 'critical'
    );
    expect(criticalViolations).toEqual([]);
  });

  test('should have proper page structure on [PAGE_NAME]', async ({ page }) => {
    // Check H1 heading
    const h1 = page.locator('h1');
    await expect(h1).toBeVisible();
    
    // Check main content
    const main = page.locator('main, [role="main"]');
    await expect(main).toBeVisible();
    
    // Check navigation
    const nav = page.locator('nav, [role="navigation"]');
    await expect(nav).toBeVisible();
  });

  test('should support keyboard navigation on [PAGE_NAME]', async ({ page }) => {
    // Test tab navigation
    await page.keyboard.press('Tab');
    
    // Verify focus is visible
    const focusedElement = page.locator(':focus');
    await expect(focusedElement).toBeVisible();
    
    // Test skip links
    await page.keyboard.press('Tab');
    const skipLink = page.locator('.skip-link:focus');
    if (await skipLink.isVisible()) {
      console.log('✅ Skip link accessible via keyboard');
    }
  });
});
```

### **🎯 STEP 2: Page Priority List**

#### **🔥 HIGH PRIORITY PAGES (Test First):**
1. **Home/Dashboard** - `/` or `/dashboard`
2. **Employee Dashboard** - `/employee/dashboard`  
3. **Management Dashboard** - `/management/dashboard`
4. **Directory/People** - `/management/people/directory`
5. **Settings** - `/settings` or `/management/settings`

#### **📋 MEDIUM PRIORITY PAGES:**
6. **Time & Attendance** - `/time-and-attendance/*`
7. **PTO & Leaves** - `/pto-and-leaves/*`
8. **Performance** - `/performance/*`
9. **Benefits** - `/benefits/*`
10. **Expenses** - `/expenses/*`

#### **📝 LOW PRIORITY PAGES:**
11. **Company Knowledge** - `/company-knowledge/*`
12. **IT Management** - `/it-management/*`
13. **Wellness** - `/wellness/*`
14. **Payroll** - `/payroll/*` (if accessible)

### **🎯 STEP 3: Testing Commands**

#### **Single Page Testing:**
```bash
# Test specific page
npx playwright test tests/accessibility-[page-name].spec.ts --project=chromium

# Test with debugging
npx playwright test tests/accessibility-[page-name].spec.ts --headed --debug

# Test with trace
npx playwright test tests/accessibility-[page-name].spec.ts --trace=on
```

#### **Progressive Testing:**
```bash
# Test high priority pages first
npx playwright test tests/accessibility-home.spec.ts
npx playwright test tests/accessibility-employee-dashboard.spec.ts  
npx playwright test tests/accessibility-management-dashboard.spec.ts
npx playwright test tests/accessibility-directory.spec.ts
npx playwright test tests/accessibility-settings.spec.ts
```

---

## 🛠️ **COMMON ISSUES & SOLUTIONS**

### **❌ Problem: Vite Cache Issues**
```
Error: 504 (Outdated Optimize Dep)
```
**✅ Solution:**
```bash
rm -rf node_modules/.vite
pkill -f "vite"
npm run dev
```

### **❌ Problem: React Not Loading**
```
Error: body is hidden, no elements found
```
**✅ Solution:**
```typescript
// Add longer waits in tests
await page.waitForLoadState('networkidle');
await page.waitForTimeout(3000);
await page.waitForFunction(() => document.getElementById('root')?.children.length > 0);
```

### **❌ Problem: Navigation Timeouts**
```
Error: page.waitForURL timeout
```
**✅ Solution:**
```typescript
// Use more flexible navigation
await page.click('[data-testid="nav-button"]');
await page.waitForLoadState('networkidle', { timeout: 30000 });
// Don't rely on exact URL matching
```

### **❌ Problem: ARIA Violations**
```
Error: aria-required-children, aria-required-parent
```
**✅ Solution:**
```typescript
// Use proper ARIA structure
// ❌ Wrong:
<ul role="menu">
  <li><button role="menuitem">Item</button></li>
</ul>

// ✅ Correct:
<div role="navigation">
  <button aria-label="Item">Item</button>
</div>

// OR for actual menus:
<div role="menu">
  <button role="menuitem">Item</button>
</div>
```

---

## 📋 **TESTING CHECKLIST PER PAGE**

### **✅ MANDATORY CHECKS:**

#### **1. Axe-Core Scan:**
- [ ] 0 critical violations
- [ ] 0 serious violations  
- [ ] Document any moderate/minor violations

#### **2. HTML Structure:**
- [ ] Has H1 heading
- [ ] Has main content area
- [ ] Has navigation landmarks
- [ ] Proper heading hierarchy (H1 → H2 → H3)

#### **3. Keyboard Navigation:**
- [ ] Tab order is logical
- [ ] All interactive elements focusable
- [ ] Skip links work
- [ ] No keyboard traps

#### **4. ARIA Implementation:**
- [ ] Proper roles and labels
- [ ] Dynamic content has live regions
- [ ] Form elements have labels
- [ ] Error messages are announced

#### **5. Focus Management:**
- [ ] Focus indicators visible
- [ ] Focus moves logically
- [ ] Focus restored after modals
- [ ] Custom focus styles work

#### **6. Color & Contrast:**
- [ ] Text contrast ≥ 4.5:1
- [ ] Interactive elements ≥ 3:1
- [ ] No color-only information
- [ ] High contrast mode support

---

## 🎯 **WCAG 2.2 AA REQUIREMENTS**

### **✅ LEVEL A (MUST HAVE):**
- **1.1.1** Non-text Content
- **1.3.1** Info and Relationships  
- **1.3.2** Meaningful Sequence
- **1.3.3** Sensory Characteristics
- **1.4.1** Use of Color
- **2.1.1** Keyboard
- **2.1.2** No Keyboard Trap
- **2.4.1** Bypass Blocks
- **2.4.2** Page Titled
- **3.1.1** Language of Page
- **4.1.1** Parsing
- **4.1.2** Name, Role, Value

### **✅ LEVEL AA (MUST HAVE):**
- **1.4.3** Contrast (Minimum) - 4.5:1
- **1.4.4** Resize Text - 200%
- **2.4.3** Focus Order
- **2.4.6** Headings and Labels
- **2.4.7** Focus Visible
- **3.1.2** Language of Parts
- **3.2.1** On Focus
- **3.2.2** On Input
- **3.3.1** Error Identification
- **3.3.2** Labels or Instructions

### **✅ LEVEL AAA (NICE TO HAVE):**
- **1.4.6** Contrast (Enhanced) - 7:1
- **2.4.8** Location
- **2.4.9** Link Purpose (Link Only)
- **3.3.5** Help

---

## 📊 **REPORTING TEMPLATE**

### **Page Test Report:**
```markdown
# Accessibility Test Report - [PAGE_NAME]

## 📊 Test Results
- **Date:** [DATE]
- **Page:** [PAGE_URL]
- **WCAG Score:** [SCORE]/100
- **Critical Violations:** [COUNT]
- **Total Violations:** [COUNT]

## ✅ Passed Checks
- [ ] Axe-core scan (0 critical violations)
- [ ] HTML structure (H1, main, nav)
- [ ] Keyboard navigation (tab order, skip links)
- [ ] ARIA implementation (roles, labels)
- [ ] Focus management (indicators, order)
- [ ] Color contrast (4.5:1 minimum)

## ❌ Issues Found
1. **[Issue Type]** - [Description]
   - **Impact:** [Critical/Serious/Moderate/Minor]
   - **Fix:** [Solution]

## 🎯 Recommendations
- [Recommendation 1]
- [Recommendation 2]

## 📈 Next Steps
- [ ] Fix critical issues
- [ ] Re-test page
- [ ] Move to next page
```

---

## 🚀 **AUTOMATION SCRIPTS**

### **Create Page Test Script:**
```bash
#!/bin/bash
# create-page-test.sh

PAGE_NAME=$1
PAGE_URL=$2

if [ -z "$PAGE_NAME" ] || [ -z "$PAGE_URL" ]; then
  echo "Usage: ./create-page-test.sh <page-name> <page-url>"
  exit 1
fi

# Create test file
cat > "tests/accessibility-${PAGE_NAME}.spec.ts" << EOF
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

test.describe('Accessibility - ${PAGE_NAME}', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('${PAGE_URL}');
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(2000);
  });

  test('should have no critical accessibility violations', async ({ page }) => {
    const results = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .analyze();

    const critical = results.violations.filter(v => v.impact === 'critical');
    expect(critical).toEqual([]);
  });

  test('should have proper page structure', async ({ page }) => {
    await expect(page.locator('h1')).toBeVisible();
    await expect(page.locator('main, [role="main"]')).toBeVisible();
    await expect(page.locator('nav, [role="navigation"]')).toBeVisible();
  });

  test('should support keyboard navigation', async ({ page }) => {
    await page.keyboard.press('Tab');
    await expect(page.locator(':focus')).toBeVisible();
  });
});
EOF

echo "✅ Created test file: tests/accessibility-${PAGE_NAME}.spec.ts"
echo "🚀 Run with: npx playwright test tests/accessibility-${PAGE_NAME}.spec.ts"
```

### **Batch Test Runner:**
```bash
#!/bin/bash
# test-all-pages.sh

PAGES=(
  "home:/"
  "employee-dashboard:/employee/dashboard"
  "management-dashboard:/management/dashboard"
  "directory:/management/people/directory"
  "settings:/settings"
)

for page in "${PAGES[@]}"; do
  IFS=':' read -r name url <<< "$page"
  echo "🧪 Testing $name ($url)..."
  
  npx playwright test "tests/accessibility-${name}.spec.ts" --project=chromium
  
  if [ $? -eq 0 ]; then
    echo "✅ $name passed"
  else
    echo "❌ $name failed"
    echo "🔍 Check report: npx playwright show-report"
    read -p "Continue? (y/n): " continue
    if [ "$continue" != "y" ]; then
      break
    fi
  fi
done

echo "🎉 All page tests completed!"
```

---

## 🎯 **SUCCESS CRITERIA**

### **✅ PAGE PASSES WHEN:**
1. **0 critical accessibility violations**
2. **All mandatory WCAG 2.2 AA criteria met**
3. **Keyboard navigation works completely**
4. **Screen reader compatibility verified**
5. **Color contrast meets 4.5:1 minimum**
6. **Focus management is proper**

### **✅ PROJECT PASSES WHEN:**
1. **All high-priority pages pass**
2. **90%+ of all pages pass**
3. **No critical violations across site**
4. **Comprehensive test coverage**
5. **Documentation complete**

---

## 📚 **RESOURCES & REFERENCES**

### **🔗 Testing Tools:**
- **Axe-core:** https://github.com/dequelabs/axe-core
- **Playwright:** https://playwright.dev/
- **WAVE:** https://wave.webaim.org/
- **Lighthouse:** https://developers.google.com/web/tools/lighthouse

### **🔗 WCAG Guidelines:**
- **WCAG 2.2:** https://www.w3.org/WAI/WCAG22/quickref/
- **Techniques:** https://www.w3.org/WAI/WCAG22/Techniques/
- **Understanding:** https://www.w3.org/WAI/WCAG22/Understanding/

### **🔗 ARIA Patterns:**
- **APG:** https://www.w3.org/WAI/ARIA/apg/
- **Examples:** https://www.w3.org/WAI/ARIA/apg/patterns/

---

**Remember: Test one page at a time, fix issues immediately, and build confidence progressively. Quality over speed!** 🎯✨
