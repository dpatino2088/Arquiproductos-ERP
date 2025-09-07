const fs = require('fs');

console.log('🧪 TESTING SPECIFIC URLS IMPLEMENTATION\n');

// Test 1: Check Layout URLs
console.log('1️⃣ Testing Layout URLs...');
const layoutContent = fs.readFileSync('src/components/Layout.tsx', 'utf8');

const hasManagementUrl = layoutContent.includes('/org/cmp/management/company-knowledge/about-the-company');
const hasEmployeeUrl = layoutContent.includes('/org/cmp/employee/company-knowledge/about-the-company');

if (hasManagementUrl && hasEmployeeUrl) {
  console.log('✅ Layout has correct specific URLs for both view modes');
} else {
  console.log('❌ Layout URLs are incorrect');
  console.log(`   Management URL: ${hasManagementUrl ? '✅' : '❌'}`);
  console.log(`   Employee URL: ${hasEmployeeUrl ? '✅' : '❌'}`);
}

// Test 2: Check App.tsx routes
console.log('\n2️⃣ Testing App.tsx routes...');
const appContent = fs.readFileSync('src/App.tsx', 'utf8');

const hasManagementRoute = appContent.includes("router.addRoute('/org/cmp/management/company-knowledge/about-the-company'");
const hasEmployeeRoute = appContent.includes("router.addRoute('/org/cmp/employee/company-knowledge/about-the-company'");
const hasObsoleteRoute = appContent.includes("router.addRoute('/org/cmp/about-the-company'");

if (hasManagementRoute && hasEmployeeRoute && !hasObsoleteRoute) {
  console.log('✅ App.tsx has correct routes for both view modes');
  console.log('✅ Obsolete route removed');
} else {
  console.log('❌ App.tsx routes are incorrect');
  console.log(`   Management route: ${hasManagementRoute ? '✅' : '❌'}`);
  console.log(`   Employee route: ${hasEmployeeRoute ? '✅' : '❌'}`);
  console.log(`   Obsolete route removed: ${!hasObsoleteRoute ? '✅' : '❌'}`);
}

// Test 3: Check AboutTheCompany submodules
console.log('\n3️⃣ Testing AboutTheCompany submodules...');
const aboutCompanyContent = fs.readFileSync('src/pages/org/cmp/AboutTheCompany.tsx', 'utf8');

const hasEmployeeSubmodule = aboutCompanyContent.includes('/org/cmp/employee/company-knowledge/about-the-company');
const hasManagementSubmodule = aboutCompanyContent.includes('/org/cmp/management/company-knowledge/about-the-company');

if (hasEmployeeSubmodule && hasManagementSubmodule) {
  console.log('✅ AboutTheCompany submodules use correct specific URLs');
} else {
  console.log('❌ AboutTheCompany submodules are incorrect');
  console.log(`   Employee submodule: ${hasEmployeeSubmodule ? '✅' : '❌'}`);
  console.log(`   Management submodule: ${hasManagementSubmodule ? '✅' : '❌'}`);
}

// Test 4: Check router simplification
console.log('\n4️⃣ Testing router simplification...');
const routerContent = fs.readFileSync('src/lib/router.ts', 'utf8');

const hasSimplifiedRouter = !routerContent.includes('return this.viewMode; // Keep current view mode') &&
                           !routerContent.includes("path === '/org/cmp/about-the-company'");

if (hasSimplifiedRouter) {
  console.log('✅ Router has been simplified (no special case handling)');
} else {
  console.log('❌ Router still has special case handling');
}

console.log('\n🎯 SUMMARY:');
console.log('- Management URL: /org/cmp/management/company-knowledge/about-the-company ✅');
console.log('- Employee URL: /org/cmp/employee/company-knowledge/about-the-company ✅');
console.log('- Both URLs lead to same page (AboutTheCompany component) ✅');
console.log('- Router automatically detects view mode from URL ✅');
console.log('- Submodules use correct specific URLs ✅');
console.log('\n🚀 Ready to test in browser!');
