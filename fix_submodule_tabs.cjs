const fs = require('fs');
const path = require('path');

console.log('🔧 FIXING COMPANY KNOWLEDGE SUBMODULE TABS\n');

// List of files to update
const filesToUpdate = [
  'src/pages/org/cmp/employee/company-knowledge/MyResponsibility.tsx',
  'src/pages/org/cmp/employee/company-knowledge/ProcessesAndPolicies.tsx',
  'src/pages/org/cmp/employee/company-knowledge/CoursesAndTraining.tsx',
  'src/pages/org/cmp/employee/company-knowledge/DocumentsAndFiles.tsx',
  'src/pages/org/cmp/management/company-knowledge/TeamResponsibilities.tsx',
  'src/pages/org/cmp/management/company-knowledge/TeamKnowledgeCompliance.tsx'
];

let updatedFiles = 0;
let totalFiles = filesToUpdate.length;

filesToUpdate.forEach(filePath => {
  try {
    let content = fs.readFileSync(filePath, 'utf8');
    let hasChanges = false;
    
    // Check if file contains the old URL
    if (content.includes("href: '/org/cmp/about-the-company'")) {
      // Determine if it's an employee or management file
      if (filePath.includes('/employee/')) {
        // Update employee files to use employee-specific URL
        content = content.replace(
          "href: '/org/cmp/about-the-company'",
          "href: '/org/cmp/employee/company-knowledge/about-the-company'"
        );
        hasChanges = true;
        console.log(`✅ Updated employee file: ${filePath}`);
      } else if (filePath.includes('/management/')) {
        // Update management files to use management-specific URL
        content = content.replace(
          "href: '/org/cmp/about-the-company'",
          "href: '/org/cmp/management/company-knowledge/about-the-company'"
        );
        hasChanges = true;
        console.log(`✅ Updated management file: ${filePath}`);
      }
      
      if (hasChanges) {
        fs.writeFileSync(filePath, content);
        updatedFiles++;
      }
    } else {
      console.log(`⏭️  No changes needed: ${filePath}`);
    }
  } catch (error) {
    console.log(`❌ Error updating ${filePath}: ${error.message}`);
  }
});

console.log(`\n🎯 SUMMARY:`);
console.log(`- Files processed: ${totalFiles}`);
console.log(`- Files updated: ${updatedFiles}`);
console.log(`- Files unchanged: ${totalFiles - updatedFiles}`);

if (updatedFiles > 0) {
  console.log('\n✅ All Company Knowledge submodule tabs have been updated!');
  console.log('🚀 Ready to test in browser!');
} else {
  console.log('\n⚠️  No files were updated. Check if the URLs are already correct.');
}
