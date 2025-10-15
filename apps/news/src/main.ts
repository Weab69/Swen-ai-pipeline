import { NestFactory } from '@nestjs/core';
import { NewsModule } from './news.module';

async function bootstrap() {
  const app = await NestFactory.create(NewsModule);
  app.setGlobalPrefix('api/v1');
  await app.listen(3002);
}
bootstrap();
