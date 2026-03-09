import { Request, Response } from 'express';
import {
  ExceptionFilter,
  Catch,
  ArgumentsHost,
  HttpException,
  HttpStatus,
  Logger,
} from '@nestjs/common';

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

@Catch()
export class HttpExceptionFilter implements ExceptionFilter {
  private readonly logger = new Logger(HttpExceptionFilter.name);

  catch(exception: unknown, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const response = ctx.getResponse<Response>();
    const request = ctx.getRequest<Request>();
    const correlationId = request?.headers?.['x-correlation-id'];

    if (!request || !response) {
      this.logger.error(
        safeStringify({
          timestamp: new Date().toISOString(),
          event: 'request.failed',
          service: 'auth-api',
          outcome: 'error',
          correlationId:
            typeof correlationId === 'string' ? correlationId : undefined,
          errorType: exception instanceof Error ? exception.name : 'Error',
          errorMessage:
            exception instanceof Error ? exception.message : String(exception),
        }),
        exception instanceof Error ? exception.stack : undefined,
      );
      throw exception;
    }

    let status = HttpStatus.INTERNAL_SERVER_ERROR;
    let message = 'An error occurred, please try again later';
    let errorDetails = null;

    if (exception instanceof HttpException) {
      status = exception.getStatus();
      const responseBody = exception.getResponse();

      if (typeof responseBody === 'object' && responseBody !== null) {
        message = (responseBody as { message?: string | string[] }).message
          ? Array.isArray((responseBody as { message?: string | string[] }).message)
            ? (responseBody as { message: string[] }).message.join(', ')
            : (responseBody as { message: string }).message
          : exception.message;

        errorDetails = (responseBody as { errors?: unknown }).errors || null;
      } else {
        message = exception.message;
      }
    } else {
      message = exception instanceof Error ? exception.message : String(exception);
    }

    this.logger.error(
      safeStringify({
        timestamp: new Date().toISOString(),
        event: 'request.failed',
        service: 'auth-api',
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
      path: request?.url || 'unknown',
      message,
      ...(correlationId && { correlationId }),
      ...(typeof errorDetails === 'object' && errorDetails !== null
        ? { errors: errorDetails }
        : {}),
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
