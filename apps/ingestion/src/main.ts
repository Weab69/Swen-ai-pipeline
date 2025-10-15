import { NestFactory } from '@nestjs/core';
import { IngestionModule } from './ingestion.module';

async function bootstrap() {
  const app = await NestFactory.create(IngestionModule);
  await app.listen(3003);
  console.log('Ingestion service is running on port 3000');
}
bootstrap();
