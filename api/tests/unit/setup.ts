process.env.NODE_ENV = 'test';
process.env.DATABASE_URL = 'postgresql://user:pass@localhost:5432/learn_api_test';
process.env.REDIS_URL = 'redis://localhost:6379';
process.env.REDIS_KEY_PREFIX = 'learn_test:';
process.env.JWT_ACCESS_SECRET = 'a'.repeat(48);
process.env.JWT_REFRESH_SECRET = 'b'.repeat(48);
process.env.JWT_ACCESS_TTL = '15m';
process.env.JWT_REFRESH_TTL = '30d';
// Slice P6 — IP hash salt for sha256(ip + ":" + salt) on Session rows.
process.env.IP_HASH_SALT = 'c'.repeat(48);
process.env.S3_ENDPOINT = 'http://localhost:8333';
process.env.S3_ACCESS_KEY = 'test';
process.env.S3_SECRET_KEY = 'test';
process.env.TUSD_PUBLIC_URL = 'http://localhost:1080/files';
process.env.HLS_BASE_URL = 'http://localhost:8080/hls';
process.env.HLS_SIGNING_SECRET = 'a'.repeat(32);
process.env.CORS_ALLOWED_ORIGINS = 'http://localhost:3000';
process.env.TUSD_HOOK_SECRET = 'test_tusd_hook_secret_abcdef';
// Slice P7a — 32-byte AES-256-GCM key (base64). 0x00 * 32 keeps the
// expected length/entropy shape without introducing anything resembling
// a real secret.
process.env.MFA_ENCRYPTION_KEY = Buffer.alloc(32, 1).toString('base64');
process.env.MFA_TOTP_ISSUER = 'Lifestream Learn Test';
