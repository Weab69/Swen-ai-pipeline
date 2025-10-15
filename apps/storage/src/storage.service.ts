import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { NewsDto } from '../../../libs/shared/src/dto/news.dto';

@Injectable()
export class StorageService {
  private logger = new Logger(StorageService.name);
  private supabase: SupabaseClient;

  constructor(private readonly configService: ConfigService) {
    this.supabase = createClient(
      this.configService.get<string>('supabaseUrl')!,
      this.configService.get<string>('supabaseApiKey')!,
    );
  }

  async storeNews(news: NewsDto) {
    try {
      const { data, error } = await this.supabase.from('news').insert([news]);

      if (error) {
        console.error('Error storing news:', error);
        return error;
      }

      return data;
    } catch (error) {
      this.logger.error(error);
      throw error;
    }
  }

  async getNews(): Promise<any> {
    const { data, error } = await this.supabase.from('news').select('*');
    if (error) {
      console.error('Error getting news:', error);
      return error;
    }
    return data;
  }
}
