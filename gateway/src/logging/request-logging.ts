import { randomUUID } from 'crypto';
import { Logger } from '@nestjs/common';
import type { NextFunction, Request, Response } from 'express';

export const CORRELATION_ID_HEADER = 'x-correlation-id';

const CORRELATION_ID_COOKIE = 'correlation-id';

const isObject = (value: unknown): value is Record<string, unknown> =>
  Boolean(value) && typeof value === 'object' && !Array.isArray(value);

const safeJsonParse = (value: unknown): unknown => {
  if (Buffer.isBuffer(value)) {
    return safeJsonParse(value.toString('utf8'));
  }

  if (typeof value !== 'string') {
    return value;
  }

  try {
    return JSON.parse(value);
  } catch {
    return value;
  }
};

const safeStringify = (value: unknown) => {
  const seen = new WeakSet();
  return JSON.stringify(value, (_key, currentValue) => {
    if (typeof currentValue === 'object' && currentValue !== null) {
      if (seen.has(currentValue)) return '[CIRCULAR]';
      seen.add(currentValue);
    }

    return currentValue;
  });
};

const firstHeaderValue = (value: string | string[] | undefined) => {
  if (Array.isArray(value)) return value[0];
  return value;
};

const extractOperationName = (body: unknown) => {
  const parsedBody = safeJsonParse(body);

  if (!isObject(parsedBody)) return undefined;

  const operationName = parsedBody.operationName;
  return typeof operationName === 'string' && operationName.length > 0
    ? operationName
    : undefined;
};

const extractErrorMessage = (body: unknown) => {
  const parsedBody = safeJsonParse(body);

  if (!isObject(parsedBody)) {
    return typeof parsedBody === 'string' && parsedBody.length > 0
      ? parsedBody
      : undefined;
  }

  if (Array.isArray(parsedBody.errors) && parsedBody.errors.length > 0) {
    const [firstError] = parsedBody.errors;

    if (isObject(firstError) && typeof firstError.message === 'string') {
      return firstError.message;
    }
  }

  if (typeof parsedBody.message === 'string') {
    return parsedBody.message;
  }

  if (Array.isArray(parsedBody.message) && parsedBody.message.length > 0) {
    return parsedBody.message
      .filter((value): value is string => typeof value === 'string')
      .join(', ');
  }

  return undefined;
};

const extractGraphqlErrorCount = (body: unknown) => {
  const parsedBody = safeJsonParse(body);

  if (!isObject(parsedBody) || !Array.isArray(parsedBody.errors)) {
    return 0;
  }

  return parsedBody.errors.length;
};

export function applyRequestLogging(service: string) {
  const logger = new Logger(`${service}-request`);

  return (request: Request, response: Response, next: NextFunction) => {
    const headerValue = firstHeaderValue(request.headers[CORRELATION_ID_HEADER]);
    const cookieValue = request.cookies?.[CORRELATION_ID_COOKIE];
    const correlationId =
      typeof headerValue === 'string' && headerValue.length > 0
        ? headerValue
        : typeof cookieValue === 'string' && cookieValue.length > 0
          ? cookieValue
          : randomUUID();

    (request.headers as Record<string, string>)[CORRELATION_ID_HEADER] =
      correlationId;
    response.setHeader(CORRELATION_ID_HEADER, correlationId);
    response.cookie(CORRELATION_ID_COOKIE, correlationId, {
      sameSite: 'lax',
    });

    const startedAt = process.hrtime.bigint();
    const requestBytes = Number(firstHeaderValue(request.headers['content-length']) || 0);
    const operationName = extractOperationName(request.body);
    const originalSend = response.send.bind(response);
    const originalJson = response.json.bind(response);
    let responseBody: unknown;

    response.send = (body: unknown) => {
      responseBody = body;
      return originalSend(body);
    };

    response.json = (body: unknown) => {
      responseBody = body;
      return originalJson(body);
    };

    response.on('finish', () => {
      const durationMs =
        Number(process.hrtime.bigint() - startedAt) / 1_000_000;
      const statusCode = response.statusCode;
      const graphqlErrorCount = extractGraphqlErrorCount(responseBody);
      const errorMessage =
        statusCode >= 400 || graphqlErrorCount > 0
          ? extractErrorMessage(responseBody)
          : undefined;

      const logEntry = {
        timestamp: new Date().toISOString(),
        event: 'request.completed',
        service,
        correlationId,
        outcome: statusCode >= 400 || graphqlErrorCount > 0 ? 'error' : 'success',
        method: request.method,
        path: request.originalUrl || request.url,
        statusCode,
        durationMs: Number(durationMs.toFixed(1)),
        clientIp: firstHeaderValue(request.headers['x-forwarded-for']) || request.ip,
        userAgent: firstHeaderValue(request.headers['user-agent']),
        operationName,
        requestBytes,
        responseBytes: Number(response.getHeader('content-length') ?? 0) || 0,
        graphqlErrorCount: graphqlErrorCount > 0 ? graphqlErrorCount : undefined,
        errorMessage,
      };

      const payload = safeStringify(logEntry);

      if (logEntry.outcome === 'error') {
        logger.error(payload);
        return;
      }

      logger.log(payload);
    });

    next();
  };
}
