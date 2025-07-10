import { Controller, Get, Post, Header, Body } from '@nestjs/common';
import { CreateItemDto } from './dto/create-item.dto';
import { ItemsService } from './items.service';
import { Item } from './interfaces/item.interface';
import { PinoLoggerService } from '../pino-logger.service';

@Controller('items')
export class ItemsController {
    constructor(
        private itemsService: ItemsService,
        private logger: PinoLoggerService // Inject logger
    ) {}

    @Post()
    @Header('Cache-Control', 'none')
    async create(@Body() createItemDto: CreateItemDto) {
        this.itemsService.create(createItemDto);
    }

    @Get()
    async findAll(): Promise<Item[]> {
        this.logger.info('GET /items endpoint hit'); // Log with Pino-compatible logger
        return this.itemsService.findAll();
    }
}
