# Flutter feed — reference notes for Slice D

Ref repo: `FlutterWiz/flutter_video_feed` (MIT). Cloned to `/tmp/flutter_video_feed-ref` during Slice C prep; **not copied into `app/`**. These notes capture the two load-bearing patterns Slice D will re-implement cleanly.

## 1. Preload pattern (±N around current page)

Entry point: `lib/features/video_feed/presentation/bloc/video_feed_cubit.dart` (class `VideoFeedCubit`).

Key idea: the cubit maintains **two in-memory data structures** alongside its emitted state:
- `Queue<String> _preloadQueue` — videos currently being fetched (de-dupes fire-and-forget work).
- `Map<String, File> _preloadedFiles` — already-downloaded `File` handles, keyed by URL.

On `onPageChanged(newIndex)`:
1. Emit new `currentIndex`.
2. Call `preloadNextVideos()` — looks at `state.videos.skip(currentIndex + 1).take(2)`, filters out anything already in `_preloadedFiles`, and for each URL not already in `_preloadQueue`, enqueues and awaits `_preloadVideo(url)`.
3. `_preloadVideo` uses `flutter_cache_manager` (`DefaultCacheManager().getSingleFile(url)` → `File`) — so the HTTP fetch happens once per URL and is cache-manager-deduplicated even across cubit restarts.
4. On completion, it updates `state.preloadedVideoUrls: Set<String>` so the view knows when the next player can be constructed against a local file path.

**Smart pagination trigger** is in the same method: `if (!_isPreloadingMore && state.hasMoreVideos && newIndex >= state.videos.length - 2)` → fire `loadMoreVideos()` under a single-flight flag. Upstream uses 2-video page size; ours should be tunable.

**What upstream does NOT do** (and we should): there's no LRU eviction — `_preloadedFiles` grows unboundedly. Over a long feed session this leaks. Slice D should cap it (e.g. last 5 files), evicting oldest by seen-at timestamp. Also note `flutter_cache_manager` manages *disk* cache eviction, but the map of `File` handles in memory isn't bounded.

**What upstream does NOT do but we need**: pre-initialize `VideoPlayerController`s for the ±1 neighbours. Upstream downloads *files* ahead but still constructs the controller lazily in the item widget. For our HLS use case (fMP4 CMAF via `video_player` + ExoPlayer), preloading a `File` isn't enough — HLS is fetched via URL, not as a single file. Our preload pattern is therefore:
- Pre-construct `VideoPlayerController.networkUrl(signedMasterPlaylistUrl)` for current±1 pages.
- Call `.initialize()` eagerly; keep controllers in an LRU keyed by `videoId`.
- On page change, pause the previous page's controller and play the current.

## 2. Video player widget — controller swap hygiene

Entry point: `lib/features/video_feed/presentation/view/widgets/video_feed_view_optimized_video_player.dart`.

The load-bearing details worth copying:
- Track `_oldController` and `_currentVideoId` in State. In `didUpdateWidget`, compare against `widget.controller` / `widget.videoId`. If either changed, `removeListener` on the old, add on the new, and mint a new `Key _playerKey = UniqueKey()` so Flutter tears down the underlying `VideoPlayer` render object (otherwise you get a flash of the previous video's last frame on the new page).
- All `setState` calls that derive from `controller.value` changes are deferred via `WidgetsBinding.instance.addPostFrameCallback` — because `VideoPlayerValue` listeners fire mid-build on some Android devices and a naive `setState` inside that callback throws.
- Buffering indicator logic has a subtlety: `controller.value.isBuffering` stays true after the video has already advanced past zero on Android, so upstream additionally checks `(isPlaying && position > Duration.zero)` to hide the spinner.

## 3. What Slice D gets from Slice C

- `Dio` instance with auth interceptor — feed fetch hits `GET /api/feed/page` via the same client.
- `AuthBloc.state.user` for `displayName` / role rendering on the placeholder `HomeShell`. Slice D replaces `HomeShell` with a `BottomNavigationBar` whose tabs are gated by role (learner/designer/admin).
- Router redirect already knows how to gate `/feed`, `/designer`, `/admin`; Slice D just fills the bodies.

## 4. Seams Slice C leaves for Slice D

- `FeedRepository` not yet created — add at `lib/data/repositories/feed_repository.dart` and wire to `Dio`.
- No `video_player` / `fvp` deps yet — add in Slice D; `fvp.registerWith()` goes in `main.dart` behind `if (!kIsWeb)`.
- No `flutter_cache_manager` dep yet — add if we keep the file-preload pattern; for HLS-only we may not need it.
- `HomeShell` is a placeholder widget; Slice D replaces it wholesale.

## 5. TL;DR for Slice D implementation order

1. Add deps: `video_player`, `fvp`, possibly `flutter_cache_manager` (evaluate HLS need).
2. Call `fvp.registerWith()` in `main.dart` before `runApp`.
3. `FeedRepository` → `GET /api/feed/page` → `List<VideoSummary>`.
4. `FeedCubit` with LRU of pre-initialized controllers, ±1 preload, smart pagination.
5. `FeedView` = `PageView.builder(scrollDirection: Axis.vertical)`; each page is a `VideoFeedItem(controller, videoSummary)`.
6. Controller-swap hygiene per §2 above.
7. Backpressure: if three `initialize()` calls are outstanding, skip preloading the fourth until one finishes.
