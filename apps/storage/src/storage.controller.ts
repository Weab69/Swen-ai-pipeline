import { Controller, Get } from '@nestjs/common';
import { StorageService } from './storage.service';
import { EventPattern, Payload } from '@nestjs/microservices';

@Controller()
export class StorageController {
  constructor(private readonly storageService: StorageService) {}

  @EventPattern('news_enriched')
  async handleNewsEnriched(@Payload() news: any) {
    await this.storageService.storeNews(news);
  }

  @Get('news')
  async getNews() {
    return await this.storageService.getNews();
  }
}
