// ============================================================
// SAPMS - ML Service Client
// Calls the Python/scikit-learn microservice (ml_service/app.py)
// for Random Forest risk predictions (proposal Section 3.7.5).
// Falls back to the existing rule-based logic if the microservice
// is unreachable — so the system degrades gracefully rather than
// failing, matching the "offline-first / low-infrastructure" spirit
// of the whole project.
// ============================================================

const ML_SERVICE_URL = process.env.ML_SERVICE_URL || 'http://localhost:8001';
const ML_TIMEOUT_MS = 2000;

// Node 18+ has global fetch; fall back to node-fetch if older runtime.
const fetchFn = global.fetch || require('node-fetch');

/**
 * Calls the ML microservice /predict endpoint.
 * @param {object} features - matches Table 3.3 feature engineering spec
 * @returns {Promise<{riskLevel, riskScore, source, modelVersion}|null>} null if unavailable
 */
async function predictRisk(features) {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), ML_TIMEOUT_MS);

  try {
    const res = await fetchFn(`${ML_SERVICE_URL}/predict`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(features),
      signal: controller.signal,
    });
    clearTimeout(timeout);

    if (!res.ok) {
      console.warn('[mlService] Non-200 from ML microservice:', res.status);
      return null;
    }

    const data = await res.json();
    // Expected shape: { risk_level: 'low'|'moderate'|'high', risk_score: 0.0-1.0, model_version: '1.0' }
    return {
      riskLevel: data.risk_level,
      riskScore: data.risk_score,
      source: 'ml_model',
      modelVersion: data.model_version,
    };
  } catch (err) {
    clearTimeout(timeout);
    console.warn('[mlService] ML microservice unreachable, will fall back to rule-based:', err.message);
    return null;
  }
}

/** Health check used at server boot to log whether ML is live. */
async function checkHealth() {
  try {
    const res = await fetchFn(`${ML_SERVICE_URL}/health`, { signal: AbortSignal.timeout(1500) });
    return res.ok;
  } catch {
    return false;
  }
}

module.exports = { predictRisk, checkHealth };
