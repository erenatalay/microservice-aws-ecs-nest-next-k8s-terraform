import { Request, Response } from 'express';
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';

type JsonPrimitive = string | number | boolean | null;
type JsonValue = JsonPrimitive | JsonObject | JsonValue[];
type JsonObject = { [key: string]: JsonValue | undefined };

interface ExceptionResponseBody extends JsonObject {
  message?: string | string[];
  errors?: JsonValue;
}

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

const isExceptionResponseBody = (
  value: unknown,
): value is ExceptionResponseBody =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

const extractErrorMessage = (
  responseBody: ExceptionResponseBody,
  fallbackMessage: string,
) => {
  if (Array.isArray(responseBody.message)) {
    return responseBody.message.join(', ');
  }

  if (
    typeof responseBody.message === 'string' &&
    responseBody.message.length > 0
  ) {
    return responseBody.message;
  }

  return fallbackMessage;
};

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const correlationId = request?.headers?.['x-correlation-id'];

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'An error occurred, please try again later';
    let errorDetails: JsonValue | null = null;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const responseBody = exception.getResponse();

      if (isExceptionResponseBody(responseBody)) {
        message = extractErrorMessage(responseBody, exception.message);
        errorDetails = responseBody.errors ?? null;
      } else {
        message = exception.message;
      }
    } else {
      message =
        exception instanceof Error ? exception.message : String(exception);
    }

    this.logger.error(
      safeStringify({
        timestamp: new Date().toISOString(),
        event: 'request.failed',
        service: 'product-api',
        outcome: 'error',
        correlationId:
          typeof correlationId === 'string' ? correlationId : undefined,
        method: request.method,
        path: request.originalUrl || request.url,
        statusCode: status,
        errorType: exception instanceof Error ? exception.name : 'Error',
        errorMessage: message,
      }),
      exception instanceof Error ? exception.stack : undefined,
    );

    const isDevelopment = process.env.NODE_ENV === 'development';
    const errorResponse = {
      statusCode: status,
      timestamp: new Date().toISOString(),
      path: request.url,
      message,
      ...(typeof correlationId === 'string' ? { correlationId } : {}),
      ...(errorDetails !== null ? { errors: errorDetails } : {}),
      ...(isDevelopment && {
        stack: exception instanceof Error ? exception.stack : undefined,
      }),
      ...(isDevelopment && {
        type: exception instanceof HttpException ? exception.name : 'Error',
      }),
    };

    response.status(status).json(errorResponse);
  }
}
