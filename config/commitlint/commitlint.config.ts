import type { UserConfig } from '@commitlint/types';
import { RuleConfigSeverity } from '@commitlint/types';

const Configuration: UserConfig = {
  /* Use the standard conventional commit rules as a baseline */
  extends: ['@commitlint/config-conventional'],

  rules: {
    /* Enforce a comprehensive list of types required for Enterprise CI/CD and Changelogs */
    'type-enum': [
      RuleConfigSeverity.Error,
      'always',
      [
        'feat',     // New feature or significant enhancement
        'fix',      // Bug fix
        'docs',     // Documentation only changes
        'style',    // Changes that do not affect the meaning of the code (formatting, missing semi-colons, etc)
        'refactor', // Code change that neither fixes a bug nor adds a feature
        'perf',     // Code change that improves performance
        'test',     // Adding missing tests or correcting existing tests
        'build',    // Changes that affect the build system or external dependencies (e.g., bun, ninja, cmake)
        'ci',       // Changes to CI configuration files and scripts (e.g., github actions, lefthook)
        'chore',    // Maintenance tasks that don't modify src or test files
        'revert',   // Reverts a previous commit
        'security', // Security patches or vulnerability fixes
        'infra',    // Infrastructure changes (e.g., terraform, k8s, docker)
      ],
    ],

    /* Restrict scopes to maintain a clean and searchable git history */
    'scope-enum': [
      RuleConfigSeverity.Error,
      'always',
      [
        'ui',       // Frontend, components, styling
        'api',      // Backend, endpoints, controllers
        'db',       // Migrations, schemas, database logic
        'auth',     // Authentication and authorization
        'perf',     // Performance-specific optimizations
        'deps',     // Dependency updates and management
        'config',   // Project-wide configuration
        'docs',     // Documentation updates
        'infra',    // DevOps and infrastructure resources
        'agent',    // AI Agent logic and automation
        'security', // Security-related updates
      ],
    ],

    /* Enforce standard git log readability limits */
    'header-max-length': [RuleConfigSeverity.Error, 'always', 100],
    'subject-max-length': [RuleConfigSeverity.Error, 'always', 72],

    /* Ensure subject starts with lowercase as per standard conventional commits */
    'subject-case': [
      RuleConfigSeverity.Error,
      'never',
      ['sentence-case', 'start-case', 'pascal-case', 'upper-case'],
    ],

    /* Prevent empty fields for mandatory audit trails */
    'type-empty': [RuleConfigSeverity.Error, 'never'],
    'subject-empty': [RuleConfigSeverity.Error, 'never'],
  },

  /* Strategic ignore logic to prevent CI/CD failures on automated messages */
  ignores: [
    (message) =>
      message.startsWith('chore(deps): bump') ||
      message.startsWith('chore: bump') ||
      message.startsWith('Updating') ||
      message.includes('Merge branch') ||
      message.includes('Initial commit'),
  ],
};

export default Configuration;

