import { Injectable, InternalServerErrorException, Logger, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createClient, SupabaseClient } from '@supabase/supabase-js';
import { TNews } from '../../../libs/shared/src/types/news.types';

@Injectable()
export class NewsService {
  private logger = new Logger(NewsService.name)
  private supabase: SupabaseClient;

  constructor(private readonly configService: ConfigService) {
    const supabaseUrl = this.configService.get<string>('supabaseUrl');
    const supabaseKey = this.configService.get<string>('supabaseApiKey');
    this.supabase = createClient(supabaseUrl!, supabaseKey!);
  }

  async getNews() {
    try {
      const { data, error } = await this.supabase
        .from('news')
        .select('*')
        .overrideTypes<TNews[]>();

      if (error) {
        this.logger.error('Error getting news:', error);
        throw new InternalServerErrorException(`Unexpected error occurred`);
      }

      return data;
    } catch (error) {
      this.logger.error(error);
      throw error;
    }
  }

  async getNewsById(id: string) {
    try {
      const { data, error } = await this.supabase
        .from('news')
        .select('*')
        .eq('id', id)
        .maybeSingle()
        .overrideTypes<TNews | null>();

      if (error) {
        this.logger.error('Error getting news by id:', error);
        throw new InternalServerErrorException(`Unexpected error occurred`);
      }

      if (!data) {
        this.logger.warn('News not found');
        throw new NotFoundException(`News not found`);
      }

      if (data instanceof Error || 'message' in data && data.message) {
        this.logger.error('Error getting news by id:', data);
        throw new InternalServerErrorException(`Unexpected error occurred`);
      }

      return data;
    } catch (error) {
      this.logger.error(error);
      throw error;
    }
  }
}
