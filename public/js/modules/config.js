export const APP_CONFIG = {
  appName: "Bolão Copa 2026",
  inviteUrl: window.location.origin + window.location.pathname,
  predictionLockMinutes: 30,
  pendingPredictionWarningHours: 2,
  maxUsers: 20,
  maxAvatarSizeMb: 2,
  apiSyncIntervalMs: 1000 * 60 * 10,
};

export const SUPABASE_CONFIG = {
  url: "https://zoktbengtliqczjlemdk.supabase.co",
  anonKey:
    "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inpva3RiZW5ndGxpcWN6amxlbWRrIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzgxNjIzODAsImV4cCI6MjA5MzczODM4MH0.sltr6vztakKxqeMjljCOMtlN3_eIl_jItY-xegxjeWE",
  storageBucket: "avatars",
  enabled: true,
};

export const SPORTS_API_CONFIG = {
  provider: "thesportsdb",
  enabled: false,
  leagueId: "4587",
  season: "2026",
  fallbackEnabled: true,
};
