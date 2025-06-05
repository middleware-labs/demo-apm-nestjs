import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ItemsModule } from './items/items.module';
import { UsersModule } from './users/users.module';
// Added for Instrumentation
import { MiddlewareApmModule } from "@middleware.io/nestjs-apm";
import LoggerService from './logger.service';

// registerIgnoredRoutes([
// '/ping'        // Wildcard patterns
// ]);

const serviceName = process.env.MW_SERVICE_NAME || "nest-js-local";
const accessToken = process.env.MW_API_KEY || "xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx";
const target = process.env.MW_TARGET || "https://xxxxx.middleware.io";
const debugEnv = process.env.MW_DEBUG;
const debug = debugEnv === undefined ? false : debugEnv === 'true' || debugEnv === '1';
console.log("[APM Config] serviceName:", serviceName);
console.log("[APM Config] accessToken:", accessToken);
console.log("[APM Config] target:", target);
console.log("[APM Config] debug:", debug);

@Module({
  imports: [
    // Added for Instrumentation
    MiddlewareApmModule.forRoot({
      serviceName,
      accessToken,
      target,
      pauseMetrics: true,
      pauseTraces: false,
      enableProfiling: false,
      DEBUG: debug,
    }),
    ItemsModule, UsersModule],
  controllers: [AppController],
  providers: [LoggerService, AppService],
})
export class AppModule {}
