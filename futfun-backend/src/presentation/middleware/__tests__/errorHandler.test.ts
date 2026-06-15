// src/presentation/middleware/__tests__/errorHandler.test.ts
import { z } from 'zod';
import { AppError, handleError } from '../errorHandler';

describe('AppError', () => {
  test('stores message, code, and default statusCode 400', () => {
    const err = new AppError('Not found', 'NOT_FOUND');
    expect(err.message).toBe('Not found');
    expect(err.code).toBe('NOT_FOUND');
    expect(err.statusCode).toBe(400);
  });

  test('accepts a custom statusCode', () => {
    const err = new AppError('Forbidden', 'FORBIDDEN', 403);
    expect(err.statusCode).toBe(403);
  });

  test('is an instance of Error', () => {
    expect(new AppError('x', 'X')).toBeInstanceOf(Error);
  });
});

describe('handleError', () => {
  test('returns 400 with VALIDATION_ERROR for ZodError', async () => {
    const schema = z.object({ name: z.string() });
    let zodError: unknown;
    try {
      schema.parse({ name: 123 });
    } catch (e) {
      zodError = e;
    }

    const res = handleError(zodError);
    expect(res.status).toBe(400);
    const body = await res.json();
    expect(body.error.code).toBe('VALIDATION_ERROR');
    expect(body.error.message).toBe('Validation error');
    expect(body.error.details).toBeDefined();
  });

  test('returns AppError statusCode and code', async () => {
    const err = new AppError('Conflict', 'DUPLICATE', 409);
    const res = handleError(err);
    expect(res.status).toBe(409);
    const body = await res.json();
    expect(body.error.code).toBe('DUPLICATE');
    expect(body.error.message).toBe('Conflict');
  });

  test('returns 500 for unknown errors', async () => {
    const res = handleError(new Error('boom'));
    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body.error.code).toBe('INTERNAL_SERVER_ERROR');
    expect(body.error.message).toBe('Internal server error');
  });

  test('returns 500 for non-Error throws', async () => {
    const res = handleError('plain string error');
    expect(res.status).toBe(500);
    const body = await res.json();
    expect(body.error.code).toBe('INTERNAL_SERVER_ERROR');
    expect(body.error.message).toBe('Internal server error');
  });
});
