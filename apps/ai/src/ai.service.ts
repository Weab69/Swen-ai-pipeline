import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import OpenAI from 'openai';
import { MediaDto, NewsDto } from '../../../libs/shared/src/dto/news.dto';
import axios from 'axios';

interface WikipediaPage {
  pageid: number;
  ns: number;
  title: string;
  extract: string;
}

interface WikipediaQuery {
  pages: Record<string, WikipediaPage>;
}

interface WikipediaResponse {
  batchcomplete: string;
  query: WikipediaQuery;
  error?: {
    code: string;
    info: string;
  };
}

interface NominatimResponse {
  lat: string;
  lon: string;
  display_name: string;
}

@Injectable()
export class AiService {
  private readonly logger = new Logger(AiService.name);
  private openai: OpenAI;
  private pexelsApiKey: string;
  private youtubeApiKey: string;
  private serperApiKey: string;
  private xBearerToken: string;

  constructor(private readonly configService: ConfigService) {
    this.openai = new OpenAI({
      baseURL: 'https://openrouter.ai/api/v1',
      apiKey: this.configService.get<string>('qwenApiKey'),
      defaultHeaders: {
        'HTTP-Referer': process.env.SITE_URL || 'https://swen.ai',
        'X-Title': process.env.SITE_NAME || 'SWEN',
      },
    });
    this.pexelsApiKey = this.configService.get<string>('pexelsApiKey')!;
    this.youtubeApiKey = this.configService.get<string>('youtubeApiKey')!;
    this.serperApiKey = this.configService.get<string>('serperApiKey')!;
    this.xBearerToken = this.configService.get<string>('xBearerToken')!;
  }

  async getSearchTrend(query: string): Promise<string | null> {
    try {
      // 1️⃣ Fetch this week’s data
      const currentWeek = await this.fetchSearchVolume(query, 'qdr:w');
      // 2️⃣ Fetch last week’s data
      const lastWeek = await this.fetchSearchVolume(query, 'qdr:2w');

      // 3️⃣ Compute growth percentage
      const diff = lastWeek > 0 ? ((currentWeek - lastWeek) / lastWeek) * 100 : 0;
      const rounded = Math.round(diff);

      // 4️⃣ Format trend message
      if (rounded > 0) return `'${query}' +${rounded}% this week`;
      if (rounded < 0) return `'${query}' ${rounded}% this week`;
      return `'${query}' stable this week`;
    } catch (err) {
      this.logger.warn(`Trend lookup failed: ${err.message}`);
      return `'${query}' trend unavailable.`;
    }
  }

  private async fetchSearchVolume(query: string, tbs: string): Promise<number> {
    try {
      const { data } = await axios.post(
        'https://google.serper.dev/search',
        { q: query, tbs, gl: 'us', hl: 'en', page: 1 },
        {
          headers: {
            'X-API-KEY': this.serperApiKey,
            'Content-Type': 'application/json',
          },
        },
      );

      // Estimate “search volume” from organic + related results
      const organicCount = data?.organic?.length || 0;
      const relatedCount = data?.relatedSearches?.length || 0;
      const combined = organicCount * 10 + relatedCount * 5; // weighted heuristic
      return combined;
    } catch (err) {
      this.logger.warn(`Fetch search volume failed for ${query}: ${err.message}`);
      return 0;
    }
  }

  private async getWikipediaSnippet(title: string): Promise<string | null> {
    const searchUrl = 'https://en.wikipedia.org/w/api.php';

    try {
      const response = await axios.get<WikipediaResponse>(searchUrl, {
        params: {
          action: 'query',
          format: 'json',
          titles: title,
          prop: 'extracts',
          exintro: true,
          explaintext: true,
          exchars: 500,
          redirects: true,
        },
      });

      const data = response.data;

      if (data.error) {
        console.error(
          `Wikipedia API Error for "${title}": ${data.error.info}`,
        );
        return null;
      }

      const pages = data.query?.pages;

      if (!pages) {
        return null;
      }

      const pageId = Object.keys(pages)[0];
      const page = pages[pageId];

      if (pageId === '-1' || !page.extract) {
        return null;
      }

      return page.extract.trim().replace(/\s\s+/g, ' ');
    } catch (error) {
      console.error(
        `An error occurred while fetching the Wikipedia snippet for "${title}":`,
        error.message,
      );
      return null;
    }
  }

  private async getGeoFromLocation(
    location: string,
  ): Promise<{ lat: number; lng: number } | null> {
    const url = 'https://nominatim.openstreetmap.org/search';
    try {
      const response = await axios.get<NominatimResponse[]>(url, {
        params: {
          q: location,
          format: 'json',
          addressdetails: 1,
          limit: 1,
        },
        headers: {
          'User-Agent': 'SWEN/1.0 (dev@swen.ai)',
        },
      });

      if (response.data.length > 0) {
        const { lat, lon } = response.data[0];
        return { lat: parseFloat(lat), lng: parseFloat(lon) };
      }
      return null;
    } catch (error) {
      console.error(
        `An error occurred while fetching geo data for "${location}":`,
        error.message,
      );
      return null;
    }
  }

  private createGoogleMapUrl(lat: number, lon: number, zoom = 15): string {
    return `https://www.google.com/maps/search/?api=1&query=${lat},${lon}&zoom=${zoom}`;
  }

  private async getImageFromSerper(query: string): Promise<string | null> {
    try {
      const response = await axios.post(
        'https://google.serper.dev/images',
        {
          q: query,
        },
        {
          headers: {
            'X-API-KEY': this.serperApiKey,
            'Content-Type': 'application/json',
          },
        },
      );
      return response.data.images.length > 0
        ? response.data.images[0].imageUrl
        : null;
    } catch (error) {
      console.error(`Error fetching image from Serper: ${error.message}`);
      return null;
    }
  }

  private async getVideoFromYouTube(query: string): Promise<string | null> {
    try {
      const response = await axios.get(
        'https://www.googleapis.com/youtube/v3/search',
        {
          params: {
            part: 'snippet',
            q: query,
            type: 'video',
            key: this.youtubeApiKey,
          },
        },
      );

      if (response.data.items.length > 0) {
        const videoId = response.data.items[0].id.videoId;
        return `https://www.youtube.com/watch?v=${videoId}`;
      }

      return null;
    } catch (error) {
      console.error(`Error fetching video from YouTube: ${error.message}`);
      return null;
    }
  }

  private async getMedia(
    query: string,
    media_justification: string,
  ): Promise<MediaDto | null> {
    const featured_image_url = await this.getImageFromSerper(query);
    const related_video_url = await this.getVideoFromYouTube(query);

    if (featured_image_url || related_video_url) {
      return {
        featured_image_url: featured_image_url ?? '',
        related_video_url: related_video_url ?? '',
        media_justification,
      };
    }

    return null;
  }

  private delay(ms: number): Promise<void> {
    return new Promise(resolve => setTimeout(resolve, ms));
  }

  async getSocialSentiment(topic: string): Promise<string> {
    try {
      // 1️⃣ Fetch recent tweets
      const twResp = await axios.get(
        'https://api.x.com/2/tweets/search/recent',
        {
          params: { query: topic, max_results: 20, 'tweet.fields': 'lang' },
          headers: { Authorization: `Bearer ${this.xBearerToken}` },
        },
      );

      const tweets: string[] =
        twResp.data.data
          ?.filter((t: any) => t.lang === 'en')
          .map((t: any) => t.text) ?? [];

      if (!tweets.length) return `No recent mentions of ${topic} on X`;

      // 2️⃣ Analyze sentiment with Qwen
      const completion = await this.openai.chat.completions.create({
        model: 'qwen/qwen2.5-vl-72b-instruct:free',
        messages: [
          {
            role: 'system',
            content:
              'You are a sentiment analysis model. You will receive a list of tweets and you need to classify the sentiment of each tweet as POSITIVE, NEGATIVE, or NEUTRAL. Respond with a JSON object containing the percentage of positive tweets. The JSON object should have a single key "positive_percentage".',
          },
          {
            role: 'user',
            content: JSON.stringify(tweets),
          },
        ],
        temperature: 0.0,
        response_format: { type: 'json_object' },
      });

      const content = completion.choices[0].message.content;
      const sentimentData = JSON.parse(content || '{}');
      const percent = Math.round(sentimentData.positive_percentage || 0);

      return `${percent}% positive mentions on X in last 24h`;
    } catch (err) {
      this.logger.warn('X sentiment failed: ' + err.message);
      return 'Social sentiment data unavailable.';
    }
  }

  async processNews(news: NewsDto): Promise<NewsDto | null> {
    try {
        const { title, body } = news;

    const completion = await this.openai.chat.completions.create({
      model: 'qwen/qwen2.5-vl-72b-instruct:free',
      messages: [
        {
          role: 'system',
          content:
            'You are an AI content enrichment model for African news. Respond in strict JSON format. All property names and string values must be enclosed in double quotes. The fields are: summary, tags (3-5 hashtags), relevance_score (0.0-1.0, African audience relevance), media_justification (string), wikipedia_search_term (a short, 1-3 word keyword/phrase from the text for a Wikipedia search), location (a location name from the text), search_trend_query (a short, 1-3 word keyword/phrase from the text for a Google search trend analysis), social_sentiment_query (a short, 1-3 word keyword/phrase from the text for a social sentiment analysis on X)',
        },
        {
          role: 'user',
          content: `Title: ${title}\nBody: ${body}`,
        },
      ],
      temperature: 0.4,
    });

    const content = completion.choices[0].message.content;
    let enrichedData: Partial<NewsDto & { wikipedia_search_term: string; location: string; media_justification: string; search_trend_query: string; social_sentiment_query: string; }> = {};
    try {
      enrichedData = JSON.parse(content || '{}');
    } catch (error) {
      console.error('Error parsing JSON from Qwen:', error.message);
      // Ask the AI to fix the JSON
      const fixerCompletion = await this.openai.chat.completions.create({
        model: 'qwen/qwen2.5-vl-72b-instruct:free',
        messages: [
          {
            role: 'system',
            content: 'You are a JSON fixer. You will receive a string that is not valid JSON and you need to fix it. Respond only with the corrected JSON.',
          },
          {
            role: 'user',
            content: `Fix this JSON string: ${content}`,
          },
        ],
        temperature: 0.0,
      });
      const fixedContent = fixerCompletion.choices[0].message.content;
      try {
        enrichedData = JSON.parse(fixedContent || '{}');
      } catch (error) {
        console.error('Error parsing fixed JSON from Qwen:', error.message);
        console.error('Problematic string:', content);
        console.error('Fixed string:', fixedContent);
      }
    }

    const {
      wikipedia_search_term,
      location,
      media_justification,
      search_trend_query,
      social_sentiment_query,
      ...restOfEnrichedData
    } = enrichedData;

    const updatedNews: NewsDto = { ...news, ...restOfEnrichedData };

    if (media_justification) {
      const media = await this.getMedia(title, media_justification);
      if (media) {
        updatedNews.media = media;
      }
    }

    if (wikipedia_search_term) {
      const wikipediaSnippet = await this.getWikipediaSnippet(
        wikipedia_search_term,
      );
      if (wikipediaSnippet) {
        if (!updatedNews.context) {
          updatedNews.context = {} as any;
        }
        updatedNews.context!.wikipedia_snippet = wikipediaSnippet;
      }
    }

    if (location) {
      await this.delay(1000); // Delay to respect Nominatim rate limit
      const geo = await this.getGeoFromLocation(location);
      if (geo) {
        if (!updatedNews.context) {
          updatedNews.context = {} as any;
        }
        updatedNews.context!.geo = {
          ...geo,
          map_url: this.createGoogleMapUrl(geo.lat, geo.lng),
        };
      }
    }

    if (search_trend_query) {
      const searchTrend = await this.getSearchTrend(search_trend_query);
      if (searchTrend) {
        if (!updatedNews.context) {
          updatedNews.context = {} as any;
        }
        updatedNews.context!.search_trend = searchTrend;
      }
    }

    if (social_sentiment_query) {
      const socialSentiment = await this.getSocialSentiment(social_sentiment_query);
      if (socialSentiment) { 
        if (!updatedNews.context) {
          updatedNews.context = {} as any;
        }
        updatedNews.context!.social_sentiment = socialSentiment;
      }
    }

    return updatedNews;
    } catch (error) {
        this.logger.error(`Error processing news: ${error.message}`);
        return null;
    }
  }
}