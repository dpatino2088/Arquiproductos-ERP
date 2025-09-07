const fs = require('fs');

// Read the Layout.tsx file
let content = fs.readFileSync('src/components/Layout.tsx', 'utf8');

// Fix the Company Knowledge URLs to use the correct path
content = content.replace(
  `  { name: 'Company Knowledge', href: '/cmp/about-the-company', icon: BookMarked },`,
  `  { name: 'Company Knowledge', href: '/org/cmp/about-the-company', icon: BookMarked },`
);

content = content.replace(
  `      const companyKnowledgeItem = { name: 'Company Knowledge', href: '/cmp/about-the-company', icon: BookMarked };`,
  `      const companyKnowledgeItem = { name: 'Company Knowledge', href: '/org/cmp/about-the-company', icon: BookMarked };`
);

// Write the updated content back
fs.writeFileSync('src/components/Layout.tsx', content);

console.log('✅ Fixed Company Knowledge URLs in Layout.tsx');
