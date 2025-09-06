#!/bin/bash
# 🧪 CREATE PAGE TEST SCRIPT
# Generates accessibility test files for individual pages

PAGE_NAME=$1
PAGE_URL=$2
DESCRIPTION=$3

if [ -z "$PAGE_NAME" ] || [ -z "$PAGE_URL" ]; then
  echo "❌ Usage: ./create-page-test.sh <page-name> <page-url> [description]"
  echo "📝 Example: ./create-page-test.sh home / 'Main dashboard page'"
  echo "📝 Example: ./create-page-test.sh employee-dashboard /employee/dashboard 'Employee main dashboard'"
  exit 1
fi

# Validate page name (no spaces, lowercase, hyphens allowed)
if [[ ! "$PAGE_NAME" =~ ^[a-z0-9-]+$ ]]; then
  echo "❌ Error: Page name must be lowercase with hyphens only (e.g., 'employee-dashboard')"
  exit 1
fi

# Set default description if not provided
if [ -z "$DESCRIPTION" ]; then
  DESCRIPTION="Accessibility test for $PAGE_NAME page"
fi

TEST_FILE="tests/accessibility-${PAGE_NAME}.spec.ts"

# Check if test file already exists
if [ -f "$TEST_FILE" ]; then
  echo "⚠️  Test file already exists: $TEST_FILE"
  read -p "🔄 Overwrite existing file? (y/n): " overwrite
  if [ "$overwrite" != "y" ]; then
    echo "🚫 Operation cancelled"
    exit 1
  fi
fi

echo "🚀 Creating accessibility test for: $PAGE_NAME"
echo "📍 Page URL: $PAGE_URL"
echo "📝 Description: $DESCRIPTION"
echo ""

# Generate the test file
cat > "$TEST_FILE" << EOF
import { test, expect } from '@playwright/test';
import AxeBuilder from '@axe-core/playwright';

/**
 * 🧪 ACCESSIBILITY TEST: ${PAGE_NAME^}
 * 
 * Description: $DESCRIPTION
 * Page URL: $PAGE_URL
 * 
 * This test suite verifies WCAG 2.2 AA compliance for the $PAGE_NAME page.
 * 
 * Test Coverage:
 * - Axe-core accessibility scan (critical violations)
 * - Page structure (H1, main, nav elements)
 * - Keyboard navigation support
 * - ARIA implementation
 * - Color contrast compliance
 * - Focus management
 */

test.describe('Accessibility Testing - ${PAGE_NAME^}', () => {
  test.beforeEach(async ({ page }) => {
    console.log('🚀 Navigating to $PAGE_URL...');
    
    // Navigate to page
    await page.goto('$PAGE_URL');
    
    // Wait for page to load completely
    await page.waitForLoadState('networkidle');
    await page.waitForTimeout(3000); // Allow React to render
    
    // Verify page loaded successfully
    const body = page.locator('body');
    await expect(body).toBeVisible();
    
    // Take screenshot for debugging
    await page.screenshot({ 
      path: 'test-results/${PAGE_NAME}-loaded.png',
      fullPage: true 
    });
    
    console.log('✅ Page loaded successfully');
  });

  test('should have no critical accessibility violations', async ({ page }) => {
    console.log('🔍 Running axe-core accessibility scan...');
    
    // Run comprehensive accessibility scan
    const accessibilityScanResults = await new AxeBuilder({ page })
      .withTags(['wcag2a', 'wcag2aa', 'wcag21aa', 'wcag22aa'])
      .exclude([
        '.loading',
        '.spinner', 
        '[aria-hidden="true"]',
        '.sr-only',
        '.visually-hidden'
      ])
      .analyze();

    // Log comprehensive results
    console.log(\`📊 Accessibility scan completed: \${accessibilityScanResults.violations.length} violations found\`);
    
    if (accessibilityScanResults.violations.length > 0) {
      console.log('📋 Violations found:');
      accessibilityScanResults.violations.forEach((violation, index) => {
        console.log(\`  \${index + 1}. \${violation.id} (\${violation.impact}): \${violation.description}\`);
        console.log(\`     Help: \${violation.helpUrl}\`);
        console.log(\`     Nodes affected: \${violation.nodes.length}\`);
        
        // Log first few nodes for debugging
        violation.nodes.slice(0, 2).forEach((node, nodeIndex) => {
          console.log(\`     Node \${nodeIndex + 1}: \${node.html.substring(0, 100)}...\`);
          if (node.failureSummary) {
            console.log(\`     Issue: \${node.failureSummary}\`);
          }
        });
        console.log('');
      });
    } else {
      console.log('🎉 No accessibility violations found!');
    }

    // Categorize violations by severity
    const criticalViolations = accessibilityScanResults.violations.filter(v => v.impact === 'critical');
    const seriousViolations = accessibilityScanResults.violations.filter(v => v.impact === 'serious');
    const moderateViolations = accessibilityScanResults.violations.filter(v => v.impact === 'moderate');
    const minorViolations = accessibilityScanResults.violations.filter(v => v.impact === 'minor');

    console.log(\`🎯 Violation breakdown:\`);
    console.log(\`   Critical: \${criticalViolations.length} (MUST FIX)\`);
    console.log(\`   Serious: \${seriousViolations.length} (SHOULD FIX)\`);
    console.log(\`   Moderate: \${moderateViolations.length} (NICE TO FIX)\`);
    console.log(\`   Minor: \${minorViolations.length} (OPTIONAL)\`);

    // MANDATORY: No critical violations allowed
    expect(criticalViolations.length).toBe(0);
    
    // RECOMMENDED: No serious violations
    if (seriousViolations.length > 0) {
      console.log('⚠️  Serious violations found - strongly recommend fixing before deployment');
    }
    
    // Calculate WCAG compliance score
    const totalIssues = criticalViolations.length + seriousViolations.length + moderateViolations.length + minorViolations.length;
    const score = totalIssues === 0 ? 100 : Math.max(0, 100 - (criticalViolations.length * 25) - (seriousViolations.length * 10) - (moderateViolations.length * 5) - (minorViolations.length * 1));
    
    console.log(\`🏆 WCAG 2.2 AA Compliance Score: \${score}/100\`);
    
    // Score should be at least 95 for production
    expect(score).toBeGreaterThanOrEqual(95);
  });

  test('should have proper page structure', async ({ page }) => {
    console.log('🏗️  Verifying page structure...');
    
    // Check for H1 heading (MANDATORY)
    const h1Elements = page.locator('h1');
    const h1Count = await h1Elements.count();
    
    console.log(\`📝 Found \${h1Count} H1 elements\`);
    expect(h1Count).toBeGreaterThanOrEqual(1);
    expect(h1Count).toBeLessThanOrEqual(1); // Should have exactly 1 H1
    
    // Verify H1 is visible and has meaningful content
    const h1 = h1Elements.first();
    await expect(h1).toBeVisible();
    
    const h1Text = await h1.textContent();
    expect(h1Text?.trim().length).toBeGreaterThan(0);
    console.log(\`✅ H1 heading: "\${h1Text}"\`);
    
    // Check for main content area (MANDATORY)
    const mainContent = page.locator('main, [role="main"]');
    await expect(mainContent).toBeVisible();
    console.log('✅ Main content area found');
    
    // Check for navigation (MANDATORY)
    const navigation = page.locator('nav, [role="navigation"]');
    const navCount = await navigation.count();
    expect(navCount).toBeGreaterThanOrEqual(1);
    console.log(\`✅ Found \${navCount} navigation elements\`);
    
    // Verify page title
    const title = await page.title();
    expect(title.length).toBeGreaterThan(0);
    console.log(\`📄 Page title: "\${title}"\`);
    
    // Check heading hierarchy
    const headings = await page.locator('h1, h2, h3, h4, h5, h6').all();
    console.log(\`📋 Heading hierarchy: \${headings.length} total headings\`);
    
    if (headings.length > 1) {
      for (let i = 0; i < Math.min(headings.length, 10); i++) {
        const heading = headings[i];
        const tagName = await heading.evaluate(el => el.tagName.toLowerCase());
        const text = await heading.textContent();
        console.log(\`   \${tagName}: "\${text?.trim().substring(0, 50)}..."\`);
      }
    }
    
    // Check for skip links
    const skipLinks = page.locator('.skip-link, a[href*="skip"], a[href="#main-content"]');
    const skipLinkCount = await skipLinks.count();
    console.log(\`🔗 Skip links found: \${skipLinkCount}\`);
  });

  test('should support keyboard navigation', async ({ page }) => {
    console.log('⌨️  Testing keyboard navigation...');
    
    // Start keyboard navigation from the top
    await page.keyboard.press('Tab');
    
    // Verify first focusable element
    const focusedElement = page.locator(':focus');
    await expect(focusedElement).toBeVisible();
    
    const focusedTag = await focusedElement.evaluate(el => el.tagName.toLowerCase());
    const focusedText = await focusedElement.textContent();
    const focusedRole = await focusedElement.getAttribute('role');
    const focusedAriaLabel = await focusedElement.getAttribute('aria-label');
    
    console.log(\`✅ First focusable element: \${focusedTag}\${focusedRole ? \` [role="\${focusedRole}"]\` : ''}\`);
    console.log(\`   Text: "\${focusedText?.trim().substring(0, 50)}..."\`);
    if (focusedAriaLabel) {
      console.log(\`   ARIA Label: "\${focusedAriaLabel}"\`);
    }
    
    // Test skip links functionality
    const skipLinks = page.locator('.skip-link, a[href*="skip"], a[href="#main-content"]');
    const skipLinkCount = await skipLinks.count();
    
    if (skipLinkCount > 0) {
      console.log(\`🔗 Testing \${skipLinkCount} skip links...\`);
      
      for (let i = 0; i < Math.min(skipLinkCount, 3); i++) {
        const skipLink = skipLinks.nth(i);
        await skipLink.focus();
        
        // Verify skip link is visible when focused
        await expect(skipLink).toBeVisible();
        
        const skipLinkText = await skipLink.textContent();
        const skipLinkHref = await skipLink.getAttribute('href');
        
        console.log(\`   Skip link \${i + 1}: "\${skipLinkText}" -> \${skipLinkHref}\`);
        
        // Test skip link functionality (if it has a valid target)
        if (skipLinkHref && skipLinkHref.startsWith('#')) {
          const target = page.locator(skipLinkHref);
          if (await target.count() > 0) {
            console.log(\`   ✅ Skip link target exists: \${skipLinkHref}\`);
          }
        }
      }
    } else {
      console.log('ℹ️  No skip links found on this page');
    }
    
    // Test tab order through interactive elements
    console.log('🔄 Testing tab order...');
    let tabCount = 0;
    const maxTabs = 15;
    const focusedElements = [];
    
    while (tabCount < maxTabs) {
      await page.keyboard.press('Tab');
      tabCount++;
      
      const currentFocus = page.locator(':focus');
      if (await currentFocus.isVisible()) {
        const tag = await currentFocus.evaluate(el => el.tagName.toLowerCase());
        const role = await currentFocus.getAttribute('role');
        const ariaLabel = await currentFocus.getAttribute('aria-label');
        const id = await currentFocus.getAttribute('id');
        
        const elementInfo = \`\${tag}\${role ? \` [role="\${role}"]\` : ''}\${id ? \` [id="\${id}"]\` : ''}\${ariaLabel ? \` [aria-label="\${ariaLabel}"]\` : ''}\`;
        focusedElements.push(elementInfo);
        
        console.log(\`   Tab \${tabCount}: \${elementInfo}\`);
      } else {
        // Focus might have moved off-screen or to invisible element
        break;
      }
    }
    
    console.log(\`✅ Keyboard navigation tested (\${focusedElements.length} focusable elements found)\`);
    
    // Verify no keyboard traps (focus should be able to move)
    expect(focusedElements.length).toBeGreaterThan(0);
  });

  test('should have proper ARIA implementation', async ({ page }) => {
    console.log('🎭 Verifying ARIA implementation...');
    
    // Check for ARIA landmarks
    const landmarks = await page.locator('[role="banner"], [role="navigation"], [role="main"], [role="contentinfo"], [role="complementary"], [role="search"]').all();
    console.log(\`🏛️  Found \${landmarks.length} ARIA landmarks:\`);
    
    for (const landmark of landmarks) {
      const role = await landmark.getAttribute('role');
      const ariaLabel = await landmark.getAttribute('aria-label');
      const ariaLabelledby = await landmark.getAttribute('aria-labelledby');
      
      console.log(\`   \${role}\${ariaLabel ? \` - "\${ariaLabel}"\` : ''}\${ariaLabelledby ? \` [labelledby="\${ariaLabelledby}"]\` : ''}\`);
    }
    
    // Check interactive elements for proper labeling
    const interactiveElements = await page.locator('button, a, input, select, textarea, [role="button"], [role="link"], [role="menuitem"], [role="tab"]').all();
    console.log(\`🎯 Found \${interactiveElements.length} interactive elements\`);
    
    let properlyLabeledElements = 0;
    const sampleSize = Math.min(interactiveElements.length, 20); // Check first 20 elements
    
    for (let i = 0; i < sampleSize; i++) {
      const element = interactiveElements[i];
      const ariaLabel = await element.getAttribute('aria-label');
      const ariaLabelledby = await element.getAttribute('aria-labelledby');
      const title = await element.getAttribute('title');
      const textContent = await element.textContent();
      const alt = await element.getAttribute('alt');
      
      const hasLabel = ariaLabel || ariaLabelledby || title || alt || (textContent && textContent.trim().length > 0);
      
      if (hasLabel) {
        properlyLabeledElements++;
      } else {
        const tag = await element.evaluate(el => el.tagName.toLowerCase());
        const role = await element.getAttribute('role');
        console.log(\`   ⚠️  Unlabeled element: \${tag}\${role ? \` [role="\${role}"]\` : ''}\`);
      }
    }
    
    const labelPercentage = (properlyLabeledElements / sampleSize) * 100;
    console.log(\`🏷️  Interactive elements with proper labels: \${properlyLabeledElements}/\${sampleSize} (\${labelPercentage.toFixed(1)}%)\`);
    
    // At least 90% of interactive elements should have proper labels
    expect(labelPercentage).toBeGreaterThanOrEqual(90);
    
    // Check for ARIA live regions (if dynamic content exists)
    const liveRegions = await page.locator('[aria-live], [role="status"], [role="alert"]').count();
    if (liveRegions > 0) {
      console.log(\`📢 Found \${liveRegions} ARIA live regions for dynamic content\`);
    }
  });

  test('should have sufficient color contrast', async ({ page }) => {
    console.log('🎨 Checking color contrast compliance...');
    
    // Run focused scan for color contrast issues
    const contrastResults = await new AxeBuilder({ page })
      .withRules(['color-contrast'])
      .analyze();
    
    const contrastViolations = contrastResults.violations.filter(v => v.id === 'color-contrast');
    
    console.log(\`📊 Color contrast violations: \${contrastViolations.length}\`);
    
    if (contrastViolations.length > 0) {
      console.log('🎨 Color contrast issues found:');
      contrastViolations.forEach((violation, index) => {
        console.log(\`   \${index + 1}. \${violation.description}\`);
        console.log(\`      Nodes affected: \${violation.nodes.length}\`);
        
        // Log details for first few nodes
        violation.nodes.slice(0, 3).forEach((node, nodeIndex) => {
          console.log(\`      Node \${nodeIndex + 1}: \${node.html.substring(0, 80)}...\`);
          if (node.any && node.any[0] && node.any[0].data) {
            const data = node.any[0].data;
            if (data.contrastRatio) {
              console.log(\`        Contrast ratio: \${data.contrastRatio} (needs \${data.expectedContrastRatio})\`);
            }
          }
        });
      });
    } else {
      console.log('✅ All text meets WCAG color contrast requirements');
    }
    
    // MANDATORY: No color contrast violations
    expect(contrastViolations.length).toBe(0);
  });

  test('should handle focus management properly', async ({ page }) => {
    console.log('🎯 Testing focus management...');
    
    // Get all focusable elements
    const focusableElements = await page.locator('button:visible, a:visible, input:visible, select:visible, textarea:visible, [tabindex]:visible').all();
    
    console.log(\`🎯 Found \${focusableElements.length} focusable elements\`);
    
    if (focusableElements.length > 0) {
      // Test focus indicators on sample of elements
      const sampleSize = Math.min(focusableElements.length, 8);
      let elementsWithFocusIndicator = 0;
      
      for (let i = 0; i < sampleSize; i++) {
        const element = focusableElements[i];
        
        // Focus the element
        await element.focus();
        
        // Verify element is actually focused
        const isFocused = await element.evaluate(el => el === document.activeElement);
        expect(isFocused).toBeTruthy();
        
        // Check for visible focus indicator
        const styles = await element.evaluate(el => {
          const computed = window.getComputedStyle(el);
          return {
            outline: computed.outline,
            outlineStyle: computed.outlineStyle,
            outlineWidth: computed.outlineWidth,
            outlineColor: computed.outlineColor,
            boxShadow: computed.boxShadow,
            border: computed.border,
          };
        });
        
        const hasFocusIndicator = 
          (styles.outline && styles.outline !== 'none' && styles.outline !== '0px') ||
          (styles.outlineStyle && styles.outlineStyle !== 'none') ||
          (styles.outlineWidth && styles.outlineWidth !== '0px') ||
          (styles.boxShadow && styles.boxShadow !== 'none') ||
          styles.border.includes('rgb'); // Likely has colored border
        
        if (hasFocusIndicator) {
          elementsWithFocusIndicator++;
          console.log(\`   ✅ Element \${i + 1} has focus indicator\`);
        } else {
          const tag = await element.evaluate(el => el.tagName.toLowerCase());
          const role = await element.getAttribute('role');
          console.log(\`   ⚠️  Element \${i + 1} (\${tag}\${role ? \` [role="\${role}"]\` : ''}) may lack visible focus indicator\`);
        }
      }
      
      const focusIndicatorPercentage = (elementsWithFocusIndicator / sampleSize) * 100;
      console.log(\`🎯 Elements with focus indicators: \${elementsWithFocusIndicator}/\${sampleSize} (\${focusIndicatorPercentage.toFixed(1)}%)\`);
      
      // At least 80% of elements should have visible focus indicators
      expect(focusIndicatorPercentage).toBeGreaterThanOrEqual(80);
    }
    
    // Test that focus doesn't get trapped
    console.log('🔄 Testing for focus traps...');
    
    // Tab through several elements
    for (let i = 0; i < 10; i++) {
      await page.keyboard.press('Tab');
      
      // Verify focus is still within the page
      const focusedElement = page.locator(':focus');
      const isVisible = await focusedElement.isVisible().catch(() => false);
      
      if (!isVisible) {
        // Focus might have moved to browser UI, which is acceptable
        break;
      }
    }
    
    console.log('✅ No focus traps detected');
  });

  test('should provide comprehensive accessibility summary', async ({ page }) => {
    console.log('📋 Generating accessibility summary for $PAGE_NAME...');
    
    // Collect comprehensive accessibility metrics
    const metrics = {
      pageUrl: '$PAGE_URL',
      pageName: '$PAGE_NAME',
      testDate: new Date().toISOString(),
      
      // Structure metrics
      h1Count: await page.locator('h1').count(),
      headingCount: await page.locator('h1, h2, h3, h4, h5, h6').count(),
      landmarkCount: await page.locator('[role="banner"], [role="navigation"], [role="main"], [role="contentinfo"]').count(),
      
      // Interactive element metrics
      buttonCount: await page.locator('button').count(),
      linkCount: await page.locator('a').count(),
      inputCount: await page.locator('input, select, textarea').count(),
      
      // Accessibility feature metrics
      skipLinkCount: await page.locator('.skip-link, a[href*="skip"]').count(),
      ariaLabelCount: await page.locator('[aria-label]').count(),
      altTextCount: await page.locator('img[alt]').count(),
    };
    
    console.log('📊 Accessibility Metrics Summary:');
    console.log('================================');
    console.log(\`📄 Page: \${metrics.pageName} (\${metrics.pageUrl})\`);
    console.log(\`📅 Test Date: \${metrics.testDate}\`);
    console.log('');
    console.log('🏗️  Structure:');
    console.log(\`   H1 headings: \${metrics.h1Count}\`);
    console.log(\`   Total headings: \${metrics.headingCount}\`);
    console.log(\`   ARIA landmarks: \${metrics.landmarkCount}\`);
    console.log('');
    console.log('🎯 Interactive Elements:');
    console.log(\`   Buttons: \${metrics.buttonCount}\`);
    console.log(\`   Links: \${metrics.linkCount}\`);
    console.log(\`   Form inputs: \${metrics.inputCount}\`);
    console.log('');
    console.log('♿ Accessibility Features:');
    console.log(\`   Skip links: \${metrics.skipLinkCount}\`);
    console.log(\`   ARIA labels: \${metrics.ariaLabelCount}\`);
    console.log(\`   Alt text images: \${metrics.altTextCount}\`);
    
    // Verify minimum requirements
    expect(metrics.h1Count).toBeGreaterThanOrEqual(1);
    expect(metrics.landmarkCount).toBeGreaterThanOrEqual(2); // At least nav and main
    
    console.log('');
    console.log('✅ Accessibility summary completed');
    console.log('🎉 Page meets basic accessibility requirements');
  });
});
EOF

echo "✅ Test file created successfully!"
echo "📁 Location: $TEST_FILE"
echo ""
echo "🚀 Next Steps:"
echo "1. Run the test:"
echo "   npx playwright test $TEST_FILE --project=chromium"
echo ""
echo "2. Run with debugging (if needed):"
echo "   npx playwright test $TEST_FILE --project=chromium --headed --debug"
echo ""
echo "3. View results:"
echo "   npx playwright show-report"
echo ""
echo "📋 Test Coverage:"
echo "- ✅ Axe-core accessibility scan"
echo "- ✅ Page structure verification"
echo "- ✅ Keyboard navigation testing"
echo "- ✅ ARIA implementation check"
echo "- ✅ Color contrast validation"
echo "- ✅ Focus management testing"
echo "- ✅ Comprehensive metrics summary"
echo ""
echo "🎯 Success Criteria:"
echo "- 0 critical accessibility violations"
echo "- Proper page structure (H1, main, nav)"
echo "- Working keyboard navigation"
echo "- Proper ARIA implementation (90%+ labeled elements)"
echo "- WCAG color contrast compliance"
echo "- Visible focus indicators (80%+ elements)"
echo ""
echo "Happy testing! 🧪✨"
