import { NestFactory } from '@nestjs/core';
import { AiModule } from './ai.module';
import { Transport, MicroserviceOptions } from '@nestjs/microservices';
import { ConfigService } from '@nestjs/config';
async function bootstrap() {
  const appContext = await NestFactory.createApplicationContext(AiModule);
  const configService = appContext.get(ConfigService);

  const app = await NestFactory.createMicroservice<MicroserviceOptions>(
    AiModule,
    {
      transport: Transport.REDIS,
      options: {
        host: configService.get<string>('REDIS_HOST'),
        port: configService.get<number>('REDIS_PORT'),
        username: configService.get<string>('REDIS_USERNAME'),
        password: configService.get<string>('REDIS_PASSWORD'),
        retryAttempts: 5,
        retryDelay: 3000,
      },
    },
  );
  await app.listen();
  console.log('Ai service is running via Redis');
}
bootstrap();
