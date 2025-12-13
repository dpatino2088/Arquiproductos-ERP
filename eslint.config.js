import js from '@eslint/js';
import globals from 'globals';
import tseslint from 'typescript-eslint';

export default tseslint.config(
  {
    ignores: ['dist', '*.config.*', '*.cjs', 'public/sw.js'],
  },
  js.configs.recommended,
  ...tseslint.configs.recommended,
  {
    files: ['**/*.{ts,tsx}'],
    languageOptions: {
      ecmaVersion: 2022,
      globals: globals.browser,
    },
    rules: {
      // TypeScript specific rules
      '@typescript-eslint/no-unused-vars': [
        'warn',
        {
          argsIgnorePattern: '^_',
          varsIgnorePattern: '^_',
        },
      ],
      '@typescript-eslint/no-explicit-any': 'warn', // Flag explicit 'any' usage
      '@typescript-eslint/explicit-function-return-type': 'off', // Too strict for now
      
      // Console logs - error in production, allow warn/error
      'no-console': [
        'error',
        {
          allow: ['warn', 'error'],
        },
      ],
      
      // Best practices
      'no-debugger': 'error',
      'no-alert': 'error',
      'prefer-const': 'warn',
      'no-var': 'error',
      
      // Code quality
      'eqeqeq': ['error', 'always'], // Require === and !==
      'curly': ['error', 'all'], // Require curly braces for all control statements
    },
  },
);
