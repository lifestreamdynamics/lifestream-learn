export interface TranscodeJobData {
  videoId: string;
  sourceKey: string;
}

export interface TranscodeJobResult {
  hlsPrefix: string;
  durationMs: number;
  rungCount: number;
}

export interface LadderRung {
  name: string;
  width: number;
  height: number;
  videoBitrateKbps: number;
}

export interface ProbeResult {
  durationMs: number;
  width: number;
  height: number;
  audioSampleRate: number | null;
  hasAudio: boolean;
}
