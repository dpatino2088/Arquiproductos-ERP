/**
 * Generate a temporary password for new organization owners
 * @returns A secure random password (10-12 characters)
 */
export function generateTemporaryPassword(): string {
  // Generate a base random string
  const base = Math.random().toString(36).slice(-8);
  
  // Ensure we have required character types
  const uppercase = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ';
  const lowercase = 'abcdefghijklmnopqrstuvwxyz';
  const numbers = '0123456789';
  const symbols = '!@#$%^&*';
  
  // Pick one random character from each required type
  const randomUpper = uppercase[Math.floor(Math.random() * uppercase.length)] || 'A';
  const randomLower = lowercase[Math.floor(Math.random() * lowercase.length)] || 'a';
  const randomNumber = numbers[Math.floor(Math.random() * numbers.length)] || '0';
  const randomSymbol = symbols[Math.floor(Math.random() * symbols.length)] || '!';
  
  // Combine: symbol + uppercase + lowercase + number + base
  const password = randomSymbol + randomUpper + randomLower + randomNumber + base;
  
  // Shuffle the characters for better security
  return password.split('').sort(() => Math.random() - 0.5).join('');
}

