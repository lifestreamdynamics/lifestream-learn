import '@tests/unit/setup';
import type { PrismaClient } from '@prisma/client';
import {
  createCaptionService,
  CAPTION_MAX_BYTES,
  type CaptionService,
} from '@/services/caption.service';
import { ForbiddenError, NotFoundError, ValidationError } from '@/utils/errors';
import type { ObjectStore } from '@/services/object-store';

// ---------------------------------------------------------------------------
// Mock helpers
// ---------------------------------------------------------------------------

type MockPrisma = {
  video: {
    findUnique: jest.Mock;
    update: jest.Mock;
  };
  videoCaption: {
    upsert: jest.Mock;
    findMany: jest.Mock;
    findUnique: jest.Mock;
    delete: jest.Mock;
  };
  $transaction: jest.Mock;
};

function buildMockPrisma(): MockPrisma {
  return {
    video: {
      findUnique: jest.fn(),
      update: jest.fn(),
    },
    videoCaption: {
      upsert: jest.fn(),
      findMany: jest.fn(),
      findUnique: jest.fn(),
      delete: jest.fn(),
    },
    $transaction: jest.fn(),
  };
}

type MockObjectStore = {
  downloadToFile: jest.Mock;
  uploadFile: jest.Mock;
  uploadDirectory: jest.Mock;
  deleteObject: jest.Mock;
  putObject: jest.Mock;
  getObjectStream: jest.Mock;
};

function buildMockObjectStore(): MockObjectStore {
  return {
    downloadToFile: jest.fn().mockResolvedValue(undefined),
    uploadFile: jest.fn().mockResolvedValue(undefined),
    uploadDirectory: jest.fn().mockResolvedValue({ uploaded: 0 }),
    deleteObject: jest.fn().mockResolvedValue(undefined),
    putObject: jest.fn().mockResolvedValue(undefined),
    getObjectStream: jest.fn(),
  };
}

function buildSvc(prisma: MockPrisma, objectStore: MockObjectStore): CaptionService {
  return createCaptionService({
    prisma: prisma as unknown as PrismaClient,
    objectStore: objectStore as unknown as ObjectStore,
  });
}

// ---------------------------------------------------------------------------
// Fixtures
// ---------------------------------------------------------------------------

const VIDEO_ID = 'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb';
const USER_ID  = 'aaaaaaaa-aaaa-4aaa-aaaa-aaaaaaaaaaaa';
const OWNER_ID = 'cccccccc-cccc-4ccc-cccc-cccccccccccc';

// A minimal owner course context (caller IS the owner).
function ownerCourse() {
  return {
    ownerId: USER_ID,
    collaborators: [],
  };
}

// A learner enrolled in the course (READ only).
function enrolledLearnerCourse() {
  return {
    ownerId: OWNER_ID,
    collaborators: [],
    enrollments: [{ userId: USER_ID }],
  };
}

// A learner who is NOT enrolled (no READ).
function strangerCourse() {
  return {
    ownerId: OWNER_ID,
    collaborators: [],
    enrollments: [],
  };
}

const VALID_VTT = Buffer.from(
  'WEBVTT\n\n00:00:01.000 --> 00:00:04.000\nHello world\n',
  'utf8',
);

const VALID_SRT = Buffer.from(
  '1\n00:00:01,000 --> 00:00:04,000\nHello world\n',
  'utf8',
);

const INVALID_VTT = Buffer.from('NOT WEBVTT\n\nsome text\n', 'utf8');

const CAPTION_UPSERT_RESULT = {
  language: 'en',
  bytes: VALID_VTT.byteLength,
  uploadedAt: new Date('2026-04-21T00:00:00Z'),
};

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

describe('caption.service', () => {
  describe('uploadCaption', () => {
    it('happy path (VTT input): uploads with correct key and content-type, upserts DB row', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({ id: VIDEO_ID, course: ownerCourse() });
      prisma.videoCaption.upsert.mockResolvedValueOnce(CAPTION_UPSERT_RESULT);

      const svc = buildSvc(prisma, store);
      const result = await svc.uploadCaption({
        videoId: VIDEO_ID,
        language: 'en',
        bytes: VALID_VTT,
        contentType: 'text/vtt',
        userId: USER_ID,
        role: 'COURSE_DESIGNER',
      });

      expect(result).toEqual(CAPTION_UPSERT_RESULT);

      // putObject is the fast path that uploadBytes detects.
      expect(store.putObject).toHaveBeenCalledTimes(1);
      const [bucket, key, , contentType] = store.putObject.mock.calls[0] as [string, string, Buffer, string];
      expect(bucket).toBe('learn-vod');
      expect(key).toBe(`vod/${VIDEO_ID}/captions/en.vtt`);
      expect(contentType).toBe('text/vtt; charset=utf-8');

      expect(prisma.videoCaption.upsert).toHaveBeenCalledTimes(1);
      const upsertCall = prisma.videoCaption.upsert.mock.calls[0][0] as {
        where: { videoId_language: { videoId: string; language: string } };
        create: { videoId: string; language: string; vttKey: string };
      };
      expect(upsertCall.where.videoId_language).toEqual({ videoId: VIDEO_ID, language: 'en' });
      expect(upsertCall.create.vttKey).toBe(`vod/${VIDEO_ID}/captions/en.vtt`);
      expect(upsertCall.create.videoId).toBe(VIDEO_ID);
      expect(upsertCall.create.language).toBe('en');
    });

    it('happy path (SRT input): converts to VTT before upload; body starts with WEBVTT', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({ id: VIDEO_ID, course: ownerCourse() });
      prisma.videoCaption.upsert.mockResolvedValueOnce({
        language: 'fr',
        bytes: 50,
        uploadedAt: new Date(),
      });

      const svc = buildSvc(prisma, store);
      await svc.uploadCaption({
        videoId: VIDEO_ID,
        language: 'fr',
        bytes: VALID_SRT,
        contentType: 'application/x-subrip',
        userId: USER_ID,
        role: 'COURSE_DESIGNER',
      });

      const uploadedBody = store.putObject.mock.calls[0][2] as Buffer;
      expect(uploadedBody.toString('utf8')).toMatch(/^WEBVTT\n/);
    });

    it('setDefault: true — runs upsert and Video.update inside a $transaction', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({ id: VIDEO_ID, course: ownerCourse() });
      // $transaction receives an array of pending queries and resolves them.
      prisma.$transaction.mockImplementation(async (ops: unknown[]) => {
        // Resolve each pending prisma operation in order.
        return Promise.all(ops as Promise<unknown>[]);
      });
      prisma.videoCaption.upsert.mockResolvedValueOnce(CAPTION_UPSERT_RESULT);
      prisma.video.update.mockResolvedValueOnce({ id: VIDEO_ID, defaultCaptionLanguage: 'en' });

      const svc = buildSvc(prisma, store);
      const result = await svc.uploadCaption({
        videoId: VIDEO_ID,
        language: 'en',
        bytes: VALID_VTT,
        contentType: 'text/vtt',
        userId: USER_ID,
        role: 'COURSE_DESIGNER',
        setDefault: true,
      });

      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
      expect(result.language).toBe('en');
    });

    it('rejects empty body with ValidationError', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      const svc = buildSvc(prisma, store);

      await expect(
        svc.uploadCaption({
          videoId: VIDEO_ID,
          language: 'en',
          bytes: Buffer.alloc(0),
          contentType: 'text/vtt',
          userId: USER_ID,
          role: 'COURSE_DESIGNER',
        }),
      ).rejects.toBeInstanceOf(ValidationError);

      expect(prisma.video.findUnique).not.toHaveBeenCalled();
      expect(store.putObject).not.toHaveBeenCalled();
    });

    it('rejects oversized body with ValidationError', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      const svc = buildSvc(prisma, store);

      await expect(
        svc.uploadCaption({
          videoId: VIDEO_ID,
          language: 'en',
          bytes: Buffer.alloc(CAPTION_MAX_BYTES + 1),
          contentType: 'text/vtt',
          userId: USER_ID,
          role: 'COURSE_DESIGNER',
        }),
      ).rejects.toBeInstanceOf(ValidationError);

      expect(store.putObject).not.toHaveBeenCalled();
    });

    it('throws ForbiddenError when caller is an enrolled learner (no WRITE)', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      // Course shows USER_ID as enrolled but not as owner/collaborator.
      prisma.video.findUnique.mockResolvedValueOnce({
        id: VIDEO_ID,
        course: enrolledLearnerCourse(),
      });
      const svc = buildSvc(prisma, store);

      await expect(
        svc.uploadCaption({
          videoId: VIDEO_ID,
          language: 'en',
          bytes: VALID_VTT,
          contentType: 'text/vtt',
          userId: USER_ID,
          role: 'LEARNER',
        }),
      ).rejects.toBeInstanceOf(ForbiddenError);

      expect(store.putObject).not.toHaveBeenCalled();
    });

    it('throws NotFoundError when video does not exist', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce(null);
      const svc = buildSvc(prisma, store);

      await expect(
        svc.uploadCaption({
          videoId: VIDEO_ID,
          language: 'en',
          bytes: VALID_VTT,
          contentType: 'text/vtt',
          userId: USER_ID,
          role: 'COURSE_DESIGNER',
        }),
      ).rejects.toBeInstanceOf(NotFoundError);
    });

    it('throws ValidationError for invalid VTT content', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({ id: VIDEO_ID, course: ownerCourse() });
      const svc = buildSvc(prisma, store);

      await expect(
        svc.uploadCaption({
          videoId: VIDEO_ID,
          language: 'en',
          bytes: INVALID_VTT,
          contentType: 'text/vtt',
          userId: USER_ID,
          role: 'COURSE_DESIGNER',
        }),
      ).rejects.toBeInstanceOf(ValidationError);

      expect(store.putObject).not.toHaveBeenCalled();
    });
  });

  // -------------------------------------------------------------------------
  describe('listCaptions', () => {
    it('returns sorted caption summaries for a course owner', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({ id: VIDEO_ID, course: ownerCourse() });
      const rows = [
        { language: 'en', bytes: 100, uploadedAt: new Date('2026-01-01') },
        { language: 'fr', bytes: 200, uploadedAt: new Date('2026-01-02') },
      ];
      prisma.videoCaption.findMany.mockResolvedValueOnce(rows);
      const svc = buildSvc(prisma, store);

      const result = await svc.listCaptions(VIDEO_ID, USER_ID, 'COURSE_DESIGNER');
      expect(result).toEqual(rows);
      expect(prisma.videoCaption.findMany).toHaveBeenCalledWith(
        expect.objectContaining({
          where: { videoId: VIDEO_ID },
          orderBy: { language: 'asc' },
        }),
      );
    });

    it('returns captions for an enrolled learner (READ access)', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({
        id: VIDEO_ID,
        course: enrolledLearnerCourse(),
      });
      prisma.videoCaption.findMany.mockResolvedValueOnce([]);
      const svc = buildSvc(prisma, store);

      // Should not throw — enrolled learners have READ access.
      const result = await svc.listCaptions(VIDEO_ID, USER_ID, 'LEARNER');
      expect(result).toEqual([]);
    });

    it('throws ForbiddenError for a stranger with no access', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({
        id: VIDEO_ID,
        course: strangerCourse(),
      });
      const svc = buildSvc(prisma, store);

      await expect(
        svc.listCaptions(VIDEO_ID, USER_ID, 'LEARNER'),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });

    it('throws NotFoundError when video does not exist', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce(null);
      const svc = buildSvc(prisma, store);

      await expect(
        svc.listCaptions(VIDEO_ID, USER_ID, 'COURSE_DESIGNER'),
      ).rejects.toBeInstanceOf(NotFoundError);
    });
  });

  // -------------------------------------------------------------------------
  describe('deleteCaption', () => {
    it('happy path: deletes object and DB row; returns void', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({
        id: VIDEO_ID,
        course: ownerCourse(),
        defaultCaptionLanguage: 'fr',   // 'en' is being deleted — default is different
      });
      prisma.videoCaption.findUnique.mockResolvedValueOnce({
        vttKey: `vod/${VIDEO_ID}/captions/en.vtt`,
      });
      prisma.videoCaption.delete.mockResolvedValueOnce({});

      const svc = buildSvc(prisma, store);
      await svc.deleteCaption(VIDEO_ID, 'en', USER_ID, 'COURSE_DESIGNER');

      expect(store.deleteObject).toHaveBeenCalledWith(
        'learn-vod',
        `vod/${VIDEO_ID}/captions/en.vtt`,
      );
      expect(prisma.videoCaption.delete).toHaveBeenCalledWith({
        where: { videoId_language: { videoId: VIDEO_ID, language: 'en' } },
      });
      // Default was 'fr', not 'en' — no $transaction needed.
      expect(prisma.$transaction).not.toHaveBeenCalled();
    });

    it('clears Video.defaultCaptionLanguage inside a transaction when language matches', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({
        id: VIDEO_ID,
        course: ownerCourse(),
        defaultCaptionLanguage: 'en',   // Matches the language being deleted.
      });
      prisma.videoCaption.findUnique.mockResolvedValueOnce({
        vttKey: `vod/${VIDEO_ID}/captions/en.vtt`,
      });
      prisma.$transaction.mockImplementation(async (ops: unknown[]) =>
        Promise.all(ops as Promise<unknown>[]),
      );
      prisma.videoCaption.delete.mockResolvedValueOnce({});
      prisma.video.update.mockResolvedValueOnce({ id: VIDEO_ID, defaultCaptionLanguage: null });

      const svc = buildSvc(prisma, store);
      await svc.deleteCaption(VIDEO_ID, 'en', USER_ID, 'COURSE_DESIGNER');

      expect(prisma.$transaction).toHaveBeenCalledTimes(1);
    });

    it('S3 delete failure does not abort — DB delete still runs', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      store.deleteObject.mockRejectedValueOnce(new Error('S3 unreachable'));
      prisma.video.findUnique.mockResolvedValueOnce({
        id: VIDEO_ID,
        course: ownerCourse(),
        defaultCaptionLanguage: null,
      });
      prisma.videoCaption.findUnique.mockResolvedValueOnce({
        vttKey: `vod/${VIDEO_ID}/captions/en.vtt`,
      });
      prisma.videoCaption.delete.mockResolvedValueOnce({});

      const svc = buildSvc(prisma, store);
      // Should resolve normally despite the S3 error.
      await expect(
        svc.deleteCaption(VIDEO_ID, 'en', USER_ID, 'COURSE_DESIGNER'),
      ).resolves.toBeUndefined();

      expect(prisma.videoCaption.delete).toHaveBeenCalledTimes(1);
    });

    it('throws NotFoundError when caption row does not exist', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({
        id: VIDEO_ID,
        course: ownerCourse(),
        defaultCaptionLanguage: null,
      });
      prisma.videoCaption.findUnique.mockResolvedValueOnce(null);
      const svc = buildSvc(prisma, store);

      await expect(
        svc.deleteCaption(VIDEO_ID, 'en', USER_ID, 'COURSE_DESIGNER'),
      ).rejects.toBeInstanceOf(NotFoundError);

      expect(store.deleteObject).not.toHaveBeenCalled();
    });

    it('throws ForbiddenError when caller has no WRITE access', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({
        id: VIDEO_ID,
        course: enrolledLearnerCourse(),
        defaultCaptionLanguage: null,
      });
      const svc = buildSvc(prisma, store);

      await expect(
        svc.deleteCaption(VIDEO_ID, 'en', USER_ID, 'LEARNER'),
      ).rejects.toBeInstanceOf(ForbiddenError);
    });
  });

  // -------------------------------------------------------------------------
  describe('getCaptionsForPlayback', () => {
    it('returns signed URLs for all caption rows with defaultCaptionLanguage preserved', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({ defaultCaptionLanguage: 'en' });
      prisma.videoCaption.findMany.mockResolvedValueOnce([
        { language: 'en' },
        { language: 'fr' },
      ]);

      const svc = buildSvc(prisma, store);
      const result = await svc.getCaptionsForPlayback(VIDEO_ID);

      expect(result.defaultCaptionLanguage).toBe('en');
      expect(result.captions).toHaveLength(2);
      expect(result.captions[0].language).toBe('en');
      expect(result.captions[1].language).toBe('fr');
      // URLs must be signed paths.
      expect(result.captions[0].url).toMatch(/\/hls\/[^/]+\/\d+\/.+\/captions\/en\.vtt/);
      expect(result.captions[1].url).toMatch(/\/hls\/[^/]+\/\d+\/.+\/captions\/fr\.vtt/);
      // expiresAt must be a future Date.
      expect(result.captions[0].expiresAt).toBeInstanceOf(Date);
      expect(result.captions[0].expiresAt.getTime()).toBeGreaterThan(Date.now());
    });

    it('returns empty captions array and null default when video has no captions', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce({ defaultCaptionLanguage: null });
      prisma.videoCaption.findMany.mockResolvedValueOnce([]);

      const svc = buildSvc(prisma, store);
      const result = await svc.getCaptionsForPlayback(VIDEO_ID);

      expect(result.captions).toEqual([]);
      expect(result.defaultCaptionLanguage).toBeNull();
    });

    it('returns empty bundle defensively when video row is missing', async () => {
      const prisma = buildMockPrisma();
      const store = buildMockObjectStore();
      prisma.video.findUnique.mockResolvedValueOnce(null);

      const svc = buildSvc(prisma, store);
      const result = await svc.getCaptionsForPlayback(VIDEO_ID);

      expect(result.captions).toEqual([]);
      expect(result.defaultCaptionLanguage).toBeNull();
      // findMany should not be called when video doesn't exist.
      expect(prisma.videoCaption.findMany).not.toHaveBeenCalled();
    });
  });
});
