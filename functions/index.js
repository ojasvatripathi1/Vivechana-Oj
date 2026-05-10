'use strict';

const { onCall, HttpsError } = require('firebase-functions/v2/https');
const { onDocumentCreated } = require('firebase-functions/v2/firestore');
const { setGlobalOptions } = require('firebase-functions/v2');
const admin = require('firebase-admin');

// ── Initialise Firebase Admin SDK (once) ────────────────────────────────────
admin.initializeApp();

// ── All functions run in Mumbai (asia-south1) for lowest India latency ───────
setGlobalOptions({ region: 'asia-south1' });

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION 1 — getHindiNews
// Proxies BBC Hindi + Bing News RSS on behalf of ALL clients.
// Uses a module-level in-memory cache (survives warm instance reuse).
// Result: 10,000 users → 1 BBC request per 10 min instead of 10,000.
// ═══════════════════════════════════════════════════════════════════════════════

// NOTE: node-fetch v2 is CommonJS-compatible; v3 is ESM only.
// Run: npm install node-fetch@2  inside ./functions/
const fetch = require('node-fetch');

/** In-memory RSS cache — survives warm Cloud Function instance restarts. */
const _rssCache = {};
/** Cache TTL: 10 minutes (600,000 ms). */
const RSS_CACHE_TTL_MS = 10 * 60 * 1000;

/** RSS feed URLs keyed by Hindi category name. */
const RSS_FEEDS = {
  'सभी':  'https://feeds.bbci.co.uk/hindi/rss.xml',
  'भारत': 'https://feeds.bbci.co.uk/hindi/india/rss.xml',
  'विश्व': 'https://feeds.bbci.co.uk/hindi/international/rss.xml',
};

/**
 * Returns a Bing News RSS URL for the given Hindi category or search query.
 * @param {string|null} category - Hindi category name
 * @param {string|null} query    - Free-text search query
 * @returns {string} Full Bing RSS URL
 */
function _bingUrl(category, query) {
  if (query) {
    return `https://www.bing.com/news/search?q=${encodeURIComponent(query)}&format=rss&mkt=hi-in`;
  }
  if (category && category !== 'सभी') {
    let q = category;
    if (category === 'विश्व')      q = 'अंतरराष्ट्रीय';
    else if (category === 'मनोरंजन') q = 'मनोरंजन बॉलीवुड';
    else if (category !== 'टेक्नोलॉजी') q += ' india';
    return `https://www.bing.com/news/search?q=${encodeURIComponent(q)}&format=rss&mkt=hi-in`;
  }
  return 'https://www.bing.com/news/search?q=india+news&format=rss&mkt=hi-in';
}

/**
 * Fetches a URL with a timeout. Throws on non-200 or network error.
 * @param {string} url       - URL to fetch
 * @param {number} timeoutMs - Timeout in milliseconds
 * @returns {Promise<string>} Response body text
 */
async function _fetchWithTimeout(url, timeoutMs = 8000) {
  const controller = new AbortController();
  const timer = setTimeout(() => controller.abort(), timeoutMs);
  try {
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        'User-Agent':
          'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 ' +
          '(KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36',
        Accept: 'application/rss+xml, application/xml, text/xml, */*',
      },
    });
    if (!res.ok) throw new Error(`HTTP ${res.status} for ${url}`);
    return await res.text();
  } finally {
    clearTimeout(timer);
  }
}

/**
 * Callable function: getHindiNews
 *
 * Client sends: { category?: string, query?: string }
 * Server returns: { xml: string, source: 'cache'|'bbc'|'bing', cachedAt: number }
 *
 * Cache key = category or query string, TTL = RSS_CACHE_TTL_MS.
 */
exports.getHindiNews = onCall(
  {
    // Keep 1 warm instance to eliminate cold starts for news fetches.
    minInstances: 1,
    maxInstances: 50,
    timeoutSeconds: 30,
    memory: '256MiB',
  },
  async (request) => {
    const category = (request.data.category || 'सभी').trim();
    const query    = (request.data.query    || '').trim();

    const cacheKey = query ? `query::${query}` : `cat::${category}`;
    const now      = Date.now();

    // ── 1. Serve from cache if still fresh ──────────────────────────────────
    const cached = _rssCache[cacheKey];
    if (cached && (now - cached.ts) < RSS_CACHE_TTL_MS) {
      console.log(`[getHindiNews] Cache HIT for "${cacheKey}"`);
      return { xml: cached.xml, source: 'cache', cachedAt: cached.ts };
    }

    // ── 2. Try primary BBC RSS (only for known categories, not search) ───────
    if (!query && RSS_FEEDS[category]) {
      try {
        const xml = await _fetchWithTimeout(RSS_FEEDS[category]);
        _rssCache[cacheKey] = { xml, ts: now };
        console.log(`[getHindiNews] BBC fetch OK for "${category}"`);
        return { xml, source: 'bbc', cachedAt: now };
      } catch (err) {
        console.warn(`[getHindiNews] BBC fetch failed for "${category}": ${err.message}`);
      }
    }

    // ── 3. Fallback: Bing News RSS ───────────────────────────────────────────
    try {
      const xml = await _fetchWithTimeout(_bingUrl(category, query || null));
      _rssCache[cacheKey] = { xml, ts: now };
      console.log(`[getHindiNews] Bing fetch OK for "${cacheKey}"`);
      return { xml, source: 'bing', cachedAt: now };
    } catch (err) {
      console.error(`[getHindiNews] Bing fetch FAILED for "${cacheKey}": ${err.message}`);
      // Return empty XML so client can show cached/stale data gracefully.
      return { xml: '<rss/>', source: 'error', cachedAt: now };
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION 2 — broadcastAnnouncement
// Triggered whenever a new document is created in /announcements/{docId}.
// Sends an FCM push to topic "all_users" — no Firestore listener needed on client.
// Result: 1 Cloud Function invocation instead of N Firestore reads (N = users).
// ═══════════════════════════════════════════════════════════════════════════════

exports.broadcastAnnouncement = onDocumentCreated(
  {
    document: 'announcements/{docId}',
    // No minInstances needed — Firestore triggers are rare.
    timeoutSeconds: 30,
    memory: '128MiB',
  },
  async (event) => {
    const data = event.data?.data();
    if (!data) {
      console.warn('[broadcastAnnouncement] Empty document — skipping.');
      return;
    }

    const title = data.title || 'नई सूचना';
    const body  = data.body  || '';
    const docId = event.params.docId;

    const message = {
      topic: 'all_users',
      notification: {
        title,
        body,
      },
      android: {
        // High priority ensures delivery even when device is in Doze mode.
        priority: 'high',
        notification: {
          channelId:    'announcements_channel',
          clickAction:  'FLUTTER_NOTIFICATION_CLICK',
          icon:         'launcher_icon',
          // Sound + vibration handled by the channel on the device.
        },
      },
      apns: {
        payload: {
          aps: {
            alert: { title, body },
            sound: 'default',
            badge: 1,
          },
        },
      },
      // Custom data payload — Flutter app can read this in onMessage / onBackgroundMessage
      data: {
        type:  'announcement',
        docId,
        title,
        body,
        click_action: 'FLUTTER_NOTIFICATION_CLICK',
      },
    };

    try {
      const response = await admin.messaging().send(message);
      console.log(`[broadcastAnnouncement] FCM sent successfully: ${response}`);
    } catch (err) {
      console.error(`[broadcastAnnouncement] FCM send failed: ${err.message}`);
      // Do not rethrow — a failed push must never crash the function and
      // cause Firestore to retry the trigger indefinitely.
    }
  }
);

// ═══════════════════════════════════════════════════════════════════════════════
// FUNCTION 3 — setAdminClaim
// One-time / as-needed callable to grant the 'admin: true' custom claim.
// Only existing admins (or direct Firebase Console invocation) should call this.
// ═══════════════════════════════════════════════════════════════════════════════

exports.setAdminClaim = onCall(
  {
    timeoutSeconds: 30,
    memory: '128MiB',
  },
  async (request) => {
    // Guard: caller must already be an admin to promote another user.
    const callerClaims = request.auth?.token;
    if (!callerClaims?.admin) {
      throw new HttpsError(
        'permission-denied',
        'Only existing admins can grant admin rights.'
      );
    }

    const targetUid   = request.data.uid;
    const shouldGrant = request.data.grant !== false; // default: grant = true

    if (!targetUid || typeof targetUid !== 'string') {
      throw new HttpsError('invalid-argument', 'uid must be a non-empty string.');
    }

    try {
      await admin.auth().setCustomUserClaims(targetUid, {
        admin: shouldGrant,
      });
      console.log(
        `[setAdminClaim] ${shouldGrant ? 'Granted' : 'Revoked'} admin claim for UID: ${targetUid}`
      );
      return {
        success: true,
        uid: targetUid,
        admin: shouldGrant,
      };
    } catch (err) {
      console.error(`[setAdminClaim] Failed: ${err.message}`);
      throw new HttpsError('internal', `Failed to set claim: ${err.message}`);
    }
  }
);
