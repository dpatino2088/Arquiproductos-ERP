const fs = require('fs');

console.log('🧪 TESTING DIRECTORY TO EMPLOYEE INFO NAVIGATION\n');

// Test 1: Check Directory navigation implementation
console.log('1️⃣ Testing Directory navigation implementation...');
const directoryContent = fs.readFileSync('src/pages/org/cmp/management/people/Directory.tsx', 'utf8');

const hasRouterImport = directoryContent.includes("import { router } from '../../../../../lib/router';");
const hasHandleEditFunction = directoryContent.includes('const handleEditEmployee = (employee: Employee) => {');
const hasSessionStorage = directoryContent.includes("sessionStorage.setItem('selectedEmployee'");
const hasNavigateCall = directoryContent.includes("router.navigate('/org/cmp/management/people/employee-info')");
const hasTableEditButton = directoryContent.includes('onClick={() => handleEditEmployee(employee)}') && 
                           directoryContent.includes('<Edit className="w-4 h-4" />');
const hasGridEditButton = directoryContent.includes('onClick={() => handleEditEmployee(employee)}') &&
                         directoryContent.includes('aria-label={`Edit ${employee.firstName} ${employee.lastName}`}');

console.log(`   - Router import: ${hasRouterImport ? '✅' : '❌'}`);
console.log(`   - HandleEditEmployee function: ${hasHandleEditFunction ? '✅' : '❌'}`);
console.log(`   - SessionStorage usage: ${hasSessionStorage ? '✅' : '❌'}`);
console.log(`   - Navigation call: ${hasNavigateCall ? '✅' : '❌'}`);
console.log(`   - Table Edit button: ${hasTableEditButton ? '✅' : '❌'}`);
console.log(`   - Grid Edit button: ${hasGridEditButton ? '✅' : '❌'}`);

// Test 2: Check EmployeeInfo dynamic data implementation
console.log('\n2️⃣ Testing EmployeeInfo dynamic data implementation...');
const employeeInfoContent = fs.readFileSync('src/pages/org/cmp/management/people/EmployeeInfo.tsx', 'utf8');

const hasDefaultEmployee = employeeInfoContent.includes('const defaultEmployee = {');
const hasEmployeeState = employeeInfoContent.includes('const [employee, setEmployee] = useState(defaultEmployee)');
const hasSessionStorageRead = employeeInfoContent.includes("sessionStorage.getItem('selectedEmployee')");
const hasDataMapping = employeeInfoContent.includes('const mappedEmployee = {') && 
                      employeeInfoContent.includes('fullName: `${parsedEmployee.firstName} ${parsedEmployee.lastName}`');
const hasDynamicBreadcrumbs = employeeInfoContent.includes('{ label: employee.fullName }');
const hasEmployeeReferences = employeeInfoContent.includes('{employee.fullName}') &&
                             employeeInfoContent.includes('{employee.email}') &&
                             employeeInfoContent.includes('{employee.position}');

console.log(`   - Default employee data: ${hasDefaultEmployee ? '✅' : '❌'}`);
console.log(`   - Employee state: ${hasEmployeeState ? '✅' : '❌'}`);
console.log(`   - SessionStorage read: ${hasSessionStorageRead ? '✅' : '❌'}`);
console.log(`   - Data mapping: ${hasDataMapping ? '✅' : '❌'}`);
console.log(`   - Dynamic breadcrumbs: ${hasDynamicBreadcrumbs ? '✅' : '❌'}`);
console.log(`   - Employee references: ${hasEmployeeReferences ? '✅' : '❌'}`);

// Test 3: Check error handling
console.log('\n3️⃣ Testing error handling...');
const hasErrorHandling = employeeInfoContent.includes('try {') && 
                        employeeInfoContent.includes('} catch (error) {') &&
                        employeeInfoContent.includes('console.error') &&
                        employeeInfoContent.includes('setEmployee(defaultEmployee)');

console.log(`   - Error handling: ${hasErrorHandling ? '✅' : '❌'}`);

console.log('\n🎯 SUMMARY:');
if (hasRouterImport && hasHandleEditFunction && hasSessionStorage && hasNavigateCall && 
    hasTableEditButton && hasGridEditButton && hasDefaultEmployee && hasEmployeeState && 
    hasSessionStorageRead && hasDataMapping && hasDynamicBreadcrumbs && hasEmployeeReferences && 
    hasErrorHandling) {
  console.log('✅ All navigation features implemented successfully!');
} else {
  console.log('❌ Some navigation features are missing or incomplete');
}

console.log('\n🚀 HOW TO TEST:');
console.log('1. Go to: http://localhost:5173/org/cmp/management/people/directory');
console.log('2. Click on any Edit button (pencil icon) in table or grid view');
console.log('3. Should navigate to Employee Info page with correct employee data');
console.log('4. Breadcrumbs should show: People / Directory / [Employee Name]');
console.log('5. All employee information should be populated correctly');

console.log('\n📋 NAVIGATION FLOW:');
console.log('Directory → Edit Button → Employee Info Page');
console.log('- Table view: Edit button in Actions column');
console.log('- Grid view: Edit button in top-right of each card');
console.log('- Data transfer: Via sessionStorage');
console.log('- Breadcrumbs: Dynamic with employee name');
console.log('- Fallback: Default employee data if no selection');
