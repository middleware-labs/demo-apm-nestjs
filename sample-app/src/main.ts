import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { errorHandler } from '@middleware.io/nestjs-apm';
import { Catch, ArgumentsHost, ExceptionFilter } from '@nestjs/common';

@Catch()
export class ExpressErrorAdapterFilter implements ExceptionFilter {
  catch(exception: any, host: ArgumentsHost) {
    const ctx = host.switchToHttp();
    const req = ctx.getRequest();
    const res = ctx.getResponse();
    const next = ctx.getNext();
    // Call your existing Express-style error handler
    errorHandler(exception, req, res, next);
  }
}

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  app.useGlobalFilters(new ExpressErrorAdapterFilter());
  await app.listen(3000);
}
bootstrap();
