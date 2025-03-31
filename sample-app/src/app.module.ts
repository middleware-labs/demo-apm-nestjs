import { Module } from '@nestjs/common';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ItemsModule } from './items/items.module';
import { UsersModule } from './users/users.module';
// Added for Instrumentation
import { MiddlewareApmModule } from "@middleware.io/nestjs-apm";

@Module({
  imports: [
    // Added for Instrumentation
    MiddlewareApmModule.forRoot({
      serviceName: "nest-js-demo",
      accessToken: "YOUR_API_KEY",
      target: "YOUR_TARGET_URL",
      pauseMetrics: true,
      pauseTraces: true,
    }),
    ItemsModule, UsersModule],
  controllers: [AppController],
  providers: [AppService],
})
export class AppModule {}
