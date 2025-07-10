import { Module } from '@nestjs/common';
import { ItemsController } from './items.controller'
import { ItemsService } from './items.service'
import { PinoLoggerService } from '../pino-logger.service';

@Module({
    controllers: [ItemsController],
    providers: [ItemsService, PinoLoggerService],
})

export class ItemsModule {}
