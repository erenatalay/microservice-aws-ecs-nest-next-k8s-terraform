import cookieParser from 'cookie-parser';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';

import { AppModule } from './app.module';
import { applyRequestLogging } from './logging/request-logging';

async function bootstrap() {
  const app = await NestFactory.create(AppModule);

  app.use(cookieParser());
  app.use(applyRequestLogging('gateway'));

  app.enableCors({
    origin: true,
    credentials: true,
  });

  const port = process.env.PORT || 4000;

  await app.listen(port, '0.0.0.0');

  Logger.log(`Gateway is running on: http://localhost:${port}/graphql`);
}

void bootstrap();
