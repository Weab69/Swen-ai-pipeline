import { HttpService } from '@nestjs/axios';
import { Inject, Injectable, OnModuleInit } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ClientProxy } from '@nestjs/microservices';
import { firstValueFrom } from 'rxjs';
import { NewsDto } from '../../../libs/shared/src/dto/news.dto';
import { TNewsIngestion } from '@app/shared/types/ingestion.types';

@Injectable()
export class IngestionService implements OnModuleInit {
  constructor(
    private readonly httpService: HttpService,
    private readonly configService: ConfigService,
    @Inject('AI_SERVICE') private readonly aiClient: ClientProxy,
  ) {}

  async onModuleInit() {
    await this.fetchAndProcessNews();
  }

  async fetchAndProcessNews() {
    const apiKey = this.configService.get<string>('newsApiKey');
    const url = `https://newsapi.org/v2/everything?q=africa&apiKey=${apiKey}`;

    try {
      const response = await firstValueFrom(this.httpService.get<{articles: TNewsIngestion[]}>(url));
      const articles = response.data.articles.slice(0, 5);

      const processedNews = articles
        .map((article) => ({
          title: article.title,
          body: article.content,
          source_url: article.url,
          publisher: article.source.name,
          published_at: article.publishedAt,
        }))
        .filter((news) => news.body && news.body.length >= 200);

      processedNews.forEach((news) => {
        this.aiClient.emit('news_created', news);
      });
    } catch (error) {
      console.error('Fetch error:', error);
    }
  }
}
