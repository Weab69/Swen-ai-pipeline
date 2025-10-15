import { Controller, Inject } from '@nestjs/common';
import { AiService } from './ai.service';
import { ClientProxy, EventPattern, Payload } from '@nestjs/microservices';
import { NewsDto } from '../../../libs/shared/src/dto/news.dto';

@Controller()
export class AiController {
  constructor(
    private readonly aiService: AiService,
    @Inject('STORAGE_SERVICE') private readonly storageClient: ClientProxy,
  ) {}

  @EventPattern('news_created')
  async handleNewsCreated(@Payload() news: NewsDto) {
    const enrichedNews = await this.aiService.processNews(news);
    if (enrichedNews) {
      this.storageClient.emit('news_enriched', enrichedNews);
    }
  }
}
