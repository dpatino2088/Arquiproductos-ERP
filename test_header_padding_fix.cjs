const fs = require('fs');

console.log('📐 TESTING HEADER PADDING AND LAYOUT FIX\n');

// Test 1: Check main container padding
console.log('1️⃣ Testing main container padding...');
const employeeInfoContent = fs.readFileSync('src/pages/org/cmp/management/people/EmployeeInfo.tsx', 'utf8');

const hasMainPadding = employeeInfoContent.includes('return (\n    <div className="p-6">');
const hasHeaderMargin = employeeInfoContent.includes('<div className="mb-8">');
const hasHeaderStructure = employeeInfoContent.includes('<h1 className="text-title font-semibold text-foreground mb-1">') &&
                          employeeInfoContent.includes('<p className="text-small text-muted-foreground">');

console.log(`   - Main container p-6: ${hasMainPadding ? '✅' : '❌'}`);
console.log(`   - Header margin mb-8: ${hasHeaderMargin ? '✅' : '❌'}`);
console.log(`   - Header structure: ${hasHeaderStructure ? '✅' : '❌'}`);

// Test 2: Check section spacing
console.log('\n2️⃣ Testing section spacing...');
const hasHeroMargin = employeeInfoContent.includes('rounded-xl p-6 mb-6');
const hasSectionNavMargin = employeeInfoContent.includes('rounded-lg p-3 mb-6');
const noSpaceY = !employeeInfoContent.includes('space-y-6');

console.log(`   - Hero section mb-6: ${hasHeroMargin ? '✅' : '❌'}`);
console.log(`   - Section nav mb-6: ${hasSectionNavMargin ? '✅' : '❌'}`);
console.log(`   - No space-y-6 classes: ${noSpaceY ? '✅' : '❌'}`);

// Test 3: Compare with other pages
console.log('\n3️⃣ Comparing with other pages...');

// Check Directory page
const directoryContent = fs.readFileSync('src/pages/org/cmp/management/people/Directory.tsx', 'utf8');
const directoryHasP6 = directoryContent.includes('return (\n    <div className="p-6">');
const directoryHasMb6 = directoryContent.includes('mb-6');

// Check Management Dashboard
const dashboardContent = fs.readFileSync('src/pages/org/cmp/management/Dashboard.tsx', 'utf8');
const dashboardHasP6 = dashboardContent.includes('return (\n    <div className="p-6">');
const dashboardHasMb8 = dashboardContent.includes('<div className="mb-8">');

// Check Inbox
const inboxContent = fs.readFileSync('src/pages/org/cmp/Inbox.tsx', 'utf8');
const inboxHasP6 = inboxContent.includes('return (\n    <div className="p-6">');
const inboxHasMb8 = inboxContent.includes('<div className="mb-8">');

console.log(`   - Directory uses p-6: ${directoryHasP6 ? '✅' : '❌'}`);
console.log(`   - Dashboard uses p-6: ${dashboardHasP6 ? '✅' : '❌'}`);
console.log(`   - Inbox uses p-6: ${inboxHasP6 ? '✅' : '❌'}`);
console.log(`   - Dashboard uses mb-8: ${dashboardHasMb8 ? '✅' : '❌'}`);
console.log(`   - Inbox uses mb-8: ${inboxHasMb8 ? '✅' : '❌'}`);

// Test 4: Check typography consistency
console.log('\n4️⃣ Testing typography consistency...');
const hasTextTitle = employeeInfoContent.includes('text-title font-semibold text-foreground');
const hasTextSmall = employeeInfoContent.includes('text-small text-muted-foreground');
const hasMb1 = employeeInfoContent.includes('mb-1');

console.log(`   - Uses text-title: ${hasTextTitle ? '✅' : '❌'}`);
console.log(`   - Uses text-small: ${hasTextSmall ? '✅' : '❌'}`);
console.log(`   - Header has mb-1: ${hasMb1 ? '✅' : '❌'}`);

// Test 5: Check layout pattern consistency
console.log('\n5️⃣ Testing layout pattern consistency...');

// Expected pattern: p-6 > mb-8 > content sections with mb-6
const hasCorrectPattern = employeeInfoContent.includes('p-6') &&
                         employeeInfoContent.includes('mb-8') &&
                         employeeInfoContent.includes('mb-6');

const followsStandardPattern = hasMainPadding && hasHeaderMargin && hasHeroMargin && hasSectionNavMargin;

console.log(`   - Follows p-6 > mb-8 > mb-6 pattern: ${hasCorrectPattern ? '✅' : '❌'}`);
console.log(`   - Matches standard layout pattern: ${followsStandardPattern ? '✅' : '❌'}`);

console.log('\n🎯 SUMMARY:');
if (hasMainPadding && hasHeaderMargin && hasHeaderStructure && hasHeroMargin && 
    hasSectionNavMargin && noSpaceY && followsStandardPattern) {
  console.log('✅ All header padding and layout fixes implemented successfully!');
  console.log('🎯 Employee Info now matches the standard page layout pattern!');
} else {
  console.log('❌ Some layout fixes are missing or incomplete');
}

console.log('\n📐 LAYOUT PATTERN APPLIED:');
console.log('📦 Main Container: <div className="p-6">');
console.log('📋 Page Header: <div className="mb-8">');
console.log('  ├── H1: text-title font-semibold text-foreground mb-1');
console.log('  └── P: text-small text-muted-foreground');
console.log('🎨 Hero Section: mb-6');
console.log('🧭 Section Navigation: mb-6');
console.log('📊 Content Sections: (no space-y, individual margins)');

console.log('\n🔄 CONSISTENCY CHECK:');
console.log(`📁 Directory: ${directoryHasP6 ? 'MATCHES' : 'DIFFERENT'} (p-6)`);
console.log(`📊 Dashboard: ${dashboardHasP6 && dashboardHasMb8 ? 'MATCHES' : 'DIFFERENT'} (p-6 + mb-8)`);
console.log(`📬 Inbox: ${inboxHasP6 && inboxHasMb8 ? 'MATCHES' : 'DIFFERENT'} (p-6 + mb-8)`);
console.log(`👤 Employee Info: ${followsStandardPattern ? 'MATCHES' : 'DIFFERENT'} (p-6 + mb-8 + mb-6)`);

console.log('\n🧪 HOW TO TEST:');
console.log('1. Navigate to Employee Info page');
console.log('2. Compare header position with Directory page');
console.log('3. Compare header position with Dashboard page');
console.log('4. Verify header starts at same horizontal and vertical position');
console.log('5. Check that spacing between sections is consistent');
console.log('6. Verify typography matches other pages');

console.log('\n✨ EXPECTED RESULT:');
console.log('🎯 Header starts at exact same position as Directory, Dashboard, Inbox');
console.log('🎯 Consistent 24px padding around entire page content');
console.log('🎯 Consistent 32px margin below page header');
console.log('🎯 Consistent 24px margins between major sections');
console.log('🎯 Typography matches design system (text-title, text-small)');
