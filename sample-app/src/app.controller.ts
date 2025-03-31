import { Controller, Get, Redirect } from '@nestjs/common';
import { AppService } from './app.service';

@Controller()
export class AppController {
  constructor(private readonly appService: AppService) {}

  @Get()
  getHello(): string {
    return this.appService.getHello();
  }

  @Get('/ping')
  getPing(): string {
    return this.appService.getPing();
  }

  @Get('/docs')
  @Redirect('https://docs.nestjs.com', 301)
  getDocs() {
    return {
      url: 'https://docs.nestjs.com/v5/'
    }
  }

  @Get('/cpu')
  heavyComputation(): string {
    const iterations = 100; // Number of times to repeat the computation
    let result = 0;
    let test = 0;
  
    for (let i = 0; i < 2000; i++) {
      test = test + i;
    }

    for (let i = 0; i < iterations; i++) {
      result += this.calculateFibonacci(2000); // Increase the Fibonacci number for higher CPU usage
    }
  
    return `Fibonacci result after ${iterations} iterations: ${result}`;
  }
  
  private calculateFibonacci(n: number): number {
    if (n <= 1) return n;
    return this.calculateFibonacci(n - 1) + this.calculateFibonacci(n - 2);
  }
}