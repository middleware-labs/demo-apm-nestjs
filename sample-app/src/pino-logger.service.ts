import { Injectable, OnModuleInit } from '@nestjs/common';

@Injectable()
export class PinoLoggerService implements OnModuleInit {
  private logger: any;

  onModuleInit() {
    // Use require() instead of import to ensure the patched version is used
    const pino = require('pino');
    
    // Create the logger during module initialization to ensure pino patching has already occurred
    this.logger = pino({
      level: 'info',
      transport: {
        target: 'pino-pretty',
        options: {
          colorize: true,
          translateTime: 'SYS:standard',
        },
      },
    });
    console.log('Pino logger created in PinoLoggerService after patching');
  }

  info(message: string): void {
    if (!this.logger) {
      console.warn('Pino logger not yet initialized');
      return;
    }
    this.logger.info(message);
  }

  warn(message: string): void {
    if (!this.logger) {
      console.warn('Pino logger not yet initialized');
      return;
    }
    this.logger.warn(message);
  }

  debug(message: string): void {
    if (!this.logger) {
      console.warn('Pino logger not yet initialized');
      return;
    }
    this.logger.debug(message);
  }

  error(message: string): void {
    if (!this.logger) {
      console.warn('Pino logger not yet initialized');
      return;
    }
    this.logger.error(message);
  }
}

export default PinoLoggerService;
