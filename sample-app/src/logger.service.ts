import winston from 'winston';
import * as expressWinston from 'express-winston';
import { Injectable } from '@nestjs/common';
import { OpenTelemetryTransportV3 } from '@opentelemetry/winston-transport';

@Injectable()
export class LoggerService {
  public accessLogHandler;
  private logger: winston.Logger;

  constructor() {
    const logFormat = winston.format.printf(({ level, message, timestamp }) => {
      return `${timestamp} [${level}]: ${message}`;
    });

    this.logger = winston.createLogger({
      level: 'info',
      format: winston.format.combine(
        winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        winston.format.simple(),
        logFormat
      ),
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          ),
        }),
        // Add the OpenTelemetry transport
        new OpenTelemetryTransportV3(),
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'logs/app.log' })
      ]
    });

    this.accessLogHandler = expressWinston.logger({
      transports: [
        new winston.transports.Console({
          format: winston.format.combine(
            winston.format.colorize(),
            winston.format.simple()
          ),
        }),
        // Add the OpenTelemetry transport
        new OpenTelemetryTransportV3(),
        new winston.transports.Console(),
        new winston.transports.File({ filename: 'logs/access.log' })
      ],
      format: winston.format.combine(
        winston.format.timestamp({ format: 'YYYY-MM-DD HH:mm:ss' }),
        winston.format.simple()
      ),
      meta: true,
      msg: 'HTTP {{req.method}} {{req.url}}',
      expressFormat: true,
      colorize: false
    });
  }

  info(message: string): void {
    this.logger.info(message);
  }

  warn(message: string): void {
    this.logger.warn(message);
  }

  debug(message: string): void {
    this.logger.debug(message);
  }

  error(message: string): void {
    this.logger.error(message);
  }
}

export default LoggerService;
