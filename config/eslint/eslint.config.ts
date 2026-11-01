import js from '@eslint/js';
import globals from 'globals';
import tseslint from 'typescript-eslint';
import react from 'eslint-plugin-react';
import reactHooks from 'eslint-plugin-react-hooks';
import nextPlugin from '@next/eslint-plugin-next';
import tailwind from 'eslint-plugin-tailwindcss';

export default tseslint.config(
  {
    /* Global ignores to keep the engine fast */
    ignores: ['.next/**', 'node_modules/**', 'public/**', 'dist/**', 'build/**'],
  },
  js.configs.recommended,
  ...tseslint.configs.strictTypeChecked,
  ...tseslint.configs.stylisticTypeChecked,
  {
    /* Main project configuration */
    files: ['**/*.{ts,tsx,js,jsx}'],
    languageOptions: {
      globals: { ...globals.browser, ...globals.node },
      parserOptions: {
        project: './tsconfig.json',
        ecmaVersion: 'latest',
        sourceType: 'module',
      },
    },
    plugins: {
      react,
      'react-hooks': reactHooks,
      '@next/next': nextPlugin,
      tailwind,
    },
    rules: {
      /* React & Hooks */
      ...react.configs.recommended.rules,
      ...react.configs['jsx-runtime'].rules,
      ...reactHooks.configs.recommended.rules,
      'react-hooks/exhaustive-deps': 'warn',

      /* Next.js Optimization */
      ...nextPlugin.configs.recommended.rules,
      ...nextPlugin.configs['core-web-vitals'].rules,

      /* Tailwind Validation (Class existence, not sorting) */
      ...tailwind.configs['flat/recommended'].rules,

      /* ------------------------------------------------------------------
         BIOME COMPATIBILITY LAYER
         Disable all stylistic rules to prevent conflicts with Biome/Oxlint
         ------------------------------------------------------------------ */
      '@typescript-eslint/indent': 'off',
      '@typescript-eslint/quotes': 'off',
      '@typescript-eslint/semi': 'off',
      '@typescript-eslint/comma-dangle': 'off',
      '@typescript-eslint/no-confusing-void-expression': 'off',
      'object-curly-spacing': 'off',
      'array-bracket-spacing': 'off',
      'import/order': 'off',

      /* ------------------------------------------------------------------
         CUSTOM ENTERPRISE RULES
         ------------------------------------------------------------------ */
      '@typescript-eslint/no-unused-vars': ['warn', { argsIgnorePattern: '^_' }],
      '@typescript-eslint/no-misused-promises': [
        'error',
        { checksVoidReturn: { attributes: false } },
      ],
      'no-console': ['warn', { allow: ['warn', 'error'] }],
    },
    settings: {
      react: { version: 'detect' },
    },
  }
);
