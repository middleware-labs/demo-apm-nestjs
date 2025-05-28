import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ItemsModule } from './items/items.module';
import { UsersModule } from './users/users.module';
// Added for Instrumentation
import { MiddlewareApmModule } from "@middleware.io/nestjs-apm";
import LoggerService from './logger.service';

@Module({
  imports: [
    // Added for Instrumentation
    MiddlewareApmModule.forRoot({
      serviceName: "nest-js-demo",
      accessToken: "evaddjfmazsdz8qip2cxva99muxv30wq6g6c",
      target: "https://plo4e.middleware.io:443",
      pauseMetrics: true,
      pauseTraces: false,
      enableProfiling: false,
      DEBUG: true,
    }),
    ItemsModule, UsersModule],
  controllers: [AppController],
  providers: [LoggerService, AppService],
})
export class AppModule {}
