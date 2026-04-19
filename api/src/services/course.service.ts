import type { Course, CourseCollaborator, PrismaClient, Role, Video } from '@prisma/client';
import { Prisma } from '@prisma/client';
import { prisma as defaultPrisma } from '@/config/prisma';
import {
  ConflictError,
  ForbiddenError,
  NotFoundError,
  ValidationError,
} from '@/utils/errors';
import { buildCourseSlug } from '@/utils/slugify';
import {
  decodeCourseCursor,
  encodeCourseCursor,
} from '@/validators/course.validators';

export interface CreateCourseInput {
  title: string;
  description: string;
  coverImageUrl?: string;
  slug?: string;
}

export interface UpdateCoursePatch {
  title?: string;
  description?: string;
  coverImageUrl?: string | null;
  slug?: string;
}

export interface ListCoursesOptions {
  cursor?: string;
  limit?: number;
  owned?: boolean;
  enrolled?: boolean;
  published?: boolean;
}

export interface ListCoursesResult {
  items: Course[];
  nextCursor: string | null;
  hasMore: boolean;
}

export interface CourseVideoSummary {
  id: string;
  title: string;
  orderIndex: number;
  status: Video['status'];
  durationMs: number | null;
}

export interface CourseWithVideos extends Course {
  videos: CourseVideoSummary[];
}

export interface CourseService {
  createCourse(
    userId: string,
    role: Role,
    input: CreateCourseInput,
  ): Promise<Course>;
  listCourses(
    userId: string | null,
    role: Role | null,
    opts: ListCoursesOptions,
  ): Promise<ListCoursesResult>;
  getCourseById(
    courseId: string,
    userId: string | null,
    role: Role | null,
  ): Promise<CourseWithVideos>;
  updateCourse(
    courseId: string,
    userId: string,
    role: Role,
    patch: UpdateCoursePatch,
  ): Promise<Course>;
  publishCourse(courseId: string, userId: string, role: Role): Promise<Course>;
  addCollaborator(
    courseId: string,
    userId: string,
    role: Role,
    targetUserId: string,
  ): Promise<{ collaborator: CourseCollaborator; created: boolean }>;
  removeCollaborator(
    courseId: string,
    userId: string,
    role: Role,
    targetUserId: string,
  ): Promise<void>;
}

// ----- auth helpers -----

function isDesignerOrAbove(role: Role): boolean {
  return role === 'ADMIN' || role === 'COURSE_DESIGNER';
}

async function loadCourseAuth(
  prisma: PrismaClient,
  courseId: string,
  userId: string,
): Promise<{
  id: string;
  ownerId: string;
  published: boolean;
  collaborators: { userId: string }[];
} | null> {
  return prisma.course.findUnique({
    where: { id: courseId },
    select: {
      id: true,
      ownerId: true,
      published: true,
      collaborators: { where: { userId }, select: { userId: true } },
    },
  });
}

// ----- slug collision retry -----

/**
 * On the astronomically unlikely event of a slug collision (~1 in 16M per
 * attempt for a 6-char hex suffix), retry up to 5 times before surfacing the
 * conflict. Keeps the caller API clean of implementation detail.
 */
async function createCourseWithUniqueSlug(
  prisma: PrismaClient,
  data: {
    title: string;
    description: string;
    ownerId: string;
    coverImageUrl?: string;
    slug?: string;
  },
): Promise<Course> {
  if (data.slug) {
    // Explicit slug from client — no auto-retry; a 409 on clash is legitimate
    // feedback to the caller so they can pick a different slug.
    try {
      return await prisma.course.create({
        data: {
          title: data.title,
          description: data.description,
          ownerId: data.ownerId,
          slug: data.slug,
          ...(data.coverImageUrl !== undefined ? { coverImageUrl: data.coverImageUrl } : {}),
        },
      });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        throw new ConflictError(`Slug "${data.slug}" is already taken`);
      }
      throw err;
    }
  }

  for (let attempt = 0; attempt < 5; attempt += 1) {
    const slug = buildCourseSlug(data.title);
    try {
      return await prisma.course.create({
        data: {
          title: data.title,
          description: data.description,
          ownerId: data.ownerId,
          slug,
          ...(data.coverImageUrl !== undefined ? { coverImageUrl: data.coverImageUrl } : {}),
        },
      });
    } catch (err) {
      if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
        // Regenerate a new suffix and retry.
        continue;
      }
      throw err;
    }
  }
  throw new ConflictError('Could not allocate a unique slug after multiple attempts');
}

export function createCourseService(
  prisma: PrismaClient = defaultPrisma,
): CourseService {
  return {
    async createCourse(userId, role, input) {
      if (!isDesignerOrAbove(role)) {
        throw new ForbiddenError('Only course designers or admins may create courses');
      }
      return createCourseWithUniqueSlug(prisma, {
        title: input.title,
        description: input.description,
        ownerId: userId,
        ...(input.coverImageUrl !== undefined ? { coverImageUrl: input.coverImageUrl } : {}),
        ...(input.slug !== undefined ? { slug: input.slug } : {}),
      });
    },

    async listCourses(userId, role, opts) {
      const limit = Math.min(opts.limit ?? 20, 50);

      // Unauthenticated callers: force published=true and disallow the
      // owned/enrolled filters — they can't meaningfully apply without a user.
      const authed = userId !== null && role !== null;
      if (!authed && (opts.owned || opts.enrolled)) {
        throw new ForbiddenError('Authentication required for owned/enrolled filters');
      }
      const publishedFilter = authed ? opts.published : true;

      const where: Prisma.CourseWhereInput = {};
      if (publishedFilter !== undefined) where.published = publishedFilter;
      if (authed && opts.owned) where.ownerId = userId;
      if (authed && opts.enrolled) {
        where.enrollments = { some: { userId } };
      }

      // Cursor filter: we order by (createdAt desc, id desc). A row R belongs
      // on a later page iff (R.createdAt, R.id) < (cursor.createdAt, cursor.id)
      // in lexicographic order. Prisma has no composite < operator, so we
      // express it as (createdAt < C) OR (createdAt = C AND id < I).
      if (opts.cursor) {
        const decoded = decodeCourseCursor(opts.cursor);
        if (!decoded) {
          throw new ValidationError('Invalid cursor');
        }
        const prev: Prisma.CourseWhereInput[] = where.AND
          ? Array.isArray(where.AND)
            ? where.AND
            : [where.AND]
          : [];
        where.AND = [
          ...prev,
          {
            OR: [
              { createdAt: { lt: decoded.createdAt } },
              { createdAt: decoded.createdAt, id: { lt: decoded.id } },
            ],
          },
        ];
      }

      const rows = await prisma.course.findMany({
        where,
        orderBy: [{ createdAt: 'desc' }, { id: 'desc' }],
        take: limit + 1,
      });

      const hasMore = rows.length > limit;
      const items = hasMore ? rows.slice(0, limit) : rows;
      const last = items[items.length - 1];
      const nextCursor = hasMore && last
        ? encodeCourseCursor({ createdAt: last.createdAt, id: last.id })
        : null;

      return { items, nextCursor, hasMore };
    },

    async getCourseById(courseId, userId, role) {
      const course = await prisma.course.findUnique({
        where: { id: courseId },
        include: {
          videos: {
            select: {
              id: true,
              title: true,
              orderIndex: true,
              status: true,
              durationMs: true,
            },
            orderBy: [{ orderIndex: 'asc' }],
          },
          collaborators: userId
            ? { where: { userId }, select: { userId: true } }
            : false,
        },
      });
      if (!course) throw new NotFoundError('Course not found');

      const isAdmin = role === 'ADMIN';
      const isOwner = userId !== null && course.ownerId === userId;
      const isCollab = (course.collaborators ?? []).length > 0;

      if (!course.published && !isAdmin && !isOwner && !isCollab) {
        // Hide existence from non-privileged callers to avoid leaking draft
        // courses. Owners/collaborators/admins see unpublished; everyone else
        // sees a clean 404.
        throw new NotFoundError('Course not found');
      }

      // Strip the collaborators[] helper field from the response shape — it's
      // only there to answer "is this user a collaborator".
      const { collaborators: _c, ...rest } = course as Course & {
        collaborators?: { userId: string }[];
        videos: CourseVideoSummary[];
      };
      void _c;
      return rest as CourseWithVideos;
    },

    async updateCourse(courseId, userId, role, patch) {
      const course = await loadCourseAuth(prisma, courseId, userId);
      if (!course) throw new NotFoundError('Course not found');
      const isAdmin = role === 'ADMIN';
      const isOwner = course.ownerId === userId;
      if (!isAdmin && !isOwner) {
        throw new ForbiddenError('Only the owner or an admin may update this course');
      }

      const data: Prisma.CourseUpdateInput = {};
      if (patch.title !== undefined) data.title = patch.title;
      if (patch.description !== undefined) data.description = patch.description;
      if (patch.coverImageUrl !== undefined) {
        data.coverImageUrl = patch.coverImageUrl ?? null;
      }
      if (patch.slug !== undefined) data.slug = patch.slug;

      try {
        return await prisma.course.update({ where: { id: courseId }, data });
      } catch (err) {
        if (err instanceof Prisma.PrismaClientKnownRequestError && err.code === 'P2002') {
          throw new ConflictError(`Slug "${patch.slug ?? ''}" is already taken`);
        }
        throw err;
      }
    },

    async publishCourse(courseId, userId, role) {
      const course = await loadCourseAuth(prisma, courseId, userId);
      if (!course) throw new NotFoundError('Course not found');
      const isAdmin = role === 'ADMIN';
      const isOwner = course.ownerId === userId;
      if (!isAdmin && !isOwner) {
        throw new ForbiddenError('Only the owner or an admin may publish this course');
      }

      // Publish-gate: at least one READY video must exist. Without this we
      // could ship an empty shell to learners and the first playback call
      // would 409 — better to refuse the publish.
      const readyVideoCount = await prisma.video.count({
        where: { courseId, status: 'READY' },
      });
      if (readyVideoCount < 1) {
        throw new ConflictError(
          'Cannot publish: course must have at least one READY video',
        );
      }

      // Idempotent: if already published, this is a no-op update returning
      // the current row.
      return prisma.course.update({
        where: { id: courseId },
        data: { published: true },
      });
    },

    async addCollaborator(courseId, userId, role, targetUserId) {
      const course = await loadCourseAuth(prisma, courseId, userId);
      if (!course) throw new NotFoundError('Course not found');
      const isAdmin = role === 'ADMIN';
      const isOwner = course.ownerId === userId;
      if (!isAdmin && !isOwner) {
        throw new ForbiddenError(
          'Only the owner or an admin may add collaborators',
        );
      }

      const target = await prisma.user.findUnique({
        where: { id: targetUserId },
        select: { id: true, role: true },
      });
      if (!target) {
        // 400 over 404 per spec — the caller supplied an invalid userId in
        // the request body, which is a validation concern from the caller's
        // POV.
        throw new ValidationError('user is not a course designer');
      }
      if (target.role !== 'COURSE_DESIGNER' && target.role !== 'ADMIN') {
        throw new ValidationError('user is not a course designer');
      }

      const existing = await prisma.courseCollaborator.findUnique({
        where: { courseId_userId: { courseId, userId: targetUserId } },
      });
      if (existing) {
        return { collaborator: existing, created: false };
      }
      const collaborator = await prisma.courseCollaborator.create({
        data: { courseId, userId: targetUserId },
      });
      return { collaborator, created: true };
    },

    async removeCollaborator(courseId, userId, role, targetUserId) {
      const course = await loadCourseAuth(prisma, courseId, userId);
      if (!course) throw new NotFoundError('Course not found');
      const isAdmin = role === 'ADMIN';
      const isOwner = course.ownerId === userId;
      if (!isAdmin && !isOwner) {
        throw new ForbiddenError(
          'Only the owner or an admin may remove collaborators',
        );
      }
      // Idempotent: deleteMany returns count=0 without throwing if the row
      // is already gone.
      await prisma.courseCollaborator.deleteMany({
        where: { courseId, userId: targetUserId },
      });
    },
  };
}

export const courseService = createCourseService();
