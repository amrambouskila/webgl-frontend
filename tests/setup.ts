import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';
import '@testing-library/jest-dom';

// Vitest does NOT auto-cleanup like Jest.
// This ensures DOM state is cleaned between tests.
afterEach(() => {
  cleanup();
});