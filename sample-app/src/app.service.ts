import { Injectable } from '@nestjs/common';
import LoggerService from './logger.service';
import * as expressWinston from 'express-winston';

@Injectable()
export class AppService {
  constructor(private readonly logger: LoggerService) {}
  
  getHello(): string {
    this.logger.info('Hello World endpoint was called'); // Log an info message
    return 'Hello World! Huuuray!!!';
  }

  getPing(): string {
    return 'Pong!';
  }
}
