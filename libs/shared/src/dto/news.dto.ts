export class GeoDto {
  lat: number;
  lng: number;
  map_url: string;
}
export class MediaDto {
  featured_image_url: string;
  related_video_url: string;
  media_justification: string;
}

export class ContextDto {
  wikipedia_snippet: string;
  social_sentiment: string;
  search_trend: string;
  geo: GeoDto;
}

export class NewsDto {
  id?: string;
  title: string;
  body: string;
  summary?: string;
  tags?: string[];
  relevance_score?: number;
  source_url: string;
  publisher: string;
  published_at: string;
  ingested_at?: string;
  media?: MediaDto;
  context?: ContextDto;
}
