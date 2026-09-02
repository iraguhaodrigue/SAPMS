"""
SAPMS-Secure — Live anomaly detection (serving side)
====================================================
Loads the models saved by train_anomaly.py and applies the same hybrid
rules + Isolation Forest logic to the CURRENT database state, returning a
list of flagged sessions and assessments with human-readable reasons.

Imported by app.py; no Flask code here so it stays testable on its own.
"""

import os
import joblib
import numpy as np
import pandas as pd

# Reuse the exact feature engineering used at training time — any drift
# between train and serve features would silently corrupt predictions.
from train_anomaly import (
    connect, build_session_features, build_assessment_features,
    SCHOOL_HOURS, MODEL_DIR,
)

SESSION_FEATS = ["scan_span_sec", "sec_per_scan", "median_gap_sec",
                 "present_rate", "activity_hour", "dow"]
ASSESS_FEATS = ["class_mean", "class_std", "pct_above_90",
                "dev_from_teacher", "z_vs_teacher"]

_cache = {}


def _load(name):
    if name not in _cache:
        path = os.path.join(MODEL_DIR, name)
        _cache[name] = joblib.load(path) if os.path.exists(path) else None
    return _cache[name]


def detect(limit=100):
    """Run hybrid detection over the whole DB. Returns a dict with a flat,
    UI-ready list of alerts, newest first."""
    conn = connect()
    try:
        sessions = build_session_features(conn)
        assessments = build_assessment_features(conn)

        # Pull display context (teacher/class names) in one go
        ctx = pd.read_sql(
            """SELECT u.id AS teacher_id, u.name AS teacher_name FROM users u""", conn)
        cls = pd.read_sql("""SELECT id AS class_id, name AS class_name FROM classes""", conn)
    finally:
        conn.close()

    alerts = []

    # ── Sessions: Layer A rules ──
    lo, hi = SCHOOL_HOURS
    sessions["rule_no_bio"] = (sessions["has_biometric"] == 0)
    sessions["rule_odd_hr"] = (sessions["activity_hour"] < lo) | (sessions["activity_hour"] > hi)
    rule_mask = sessions["rule_no_bio"] | sessions["rule_odd_hr"]

    # ── Sessions: Layer B ML on the remainder ──
    smodel, sscaler = _load("session_anomaly.pkl"), _load("session_scaler.pkl")
    sessions["ml_flag"] = False
    sessions["ml_score"] = 0.0
    remainder = sessions[~rule_mask]
    if smodel is not None and sscaler is not None and len(remainder):
        Xs = sscaler.transform(remainder[SESSION_FEATS].values)
        sessions.loc[remainder.index, "ml_flag"] = (smodel.predict(Xs) == -1)
        sessions.loc[remainder.index, "ml_score"] = -smodel.score_samples(Xs)

    sess_flagged = sessions[rule_mask | sessions["ml_flag"]].copy()
    sess_flagged = sess_flagged.merge(ctx, on="teacher_id", how="left") \
                               .merge(cls, on="class_id", how="left")

    for _, r in sess_flagged.iterrows():
        if r["rule_no_bio"]:
            reason, severity, src = "Session opened without biometric verification", "high", "rule"
        elif r["rule_odd_hr"]:
            reason, severity, src = (
                f"Activity at {int(r['activity_hour']):02d}:00 — outside school hours", "high", "rule")
        else:
            # ML flag — pick the most telling detail for the reason string
            if r["sec_per_scan"] <= 2 and r["present_count"] and r["present_count"] > 5:
                reason = (f"Entire class ({int(r['present_count'])} students) scanned in "
                          f"{int(r['scan_span_sec'])}s — possible bulk marking")
            elif r["scan_span_sec"] > 3600:
                reason = "Scan timestamps spread over an implausible interval"
            else:
                reason = "Unusual scanning pattern for this session"
            severity, src = "medium", "ml"

        alerts.append({
            "entity_type": "attendance_session",
            "entity_id": r["session_id"],
            "date": str(r["session_date"]),
            "class_name": r.get("class_name") or "",
            "teacher_name": r.get("teacher_name") or "",
            "reason": reason,
            "severity": severity,
            "detected_by": src,
            "score": round(float(r["ml_score"]), 3),
        })

    # ── Assessments: ML only ──
    amodel, ascaler = _load("assessment_anomaly.pkl"), _load("assessment_scaler.pkl")
    if amodel is not None and ascaler is not None and len(assessments):
        Xa = ascaler.transform(assessments[ASSESS_FEATS].values)
        assessments["ml_flag"] = (amodel.predict(Xa) == -1)
        assessments["ml_score"] = -amodel.score_samples(Xa)

        aflag = assessments[assessments["ml_flag"]].merge(ctx, on="teacher_id", how="left") \
                                                   .merge(cls, on="class_id", how="left")
        for _, r in aflag.iterrows():
            alerts.append({
                "entity_type": "assessment",
                "entity_id": r["assessment_id"],
                "date": "",
                "class_name": r.get("class_name") or "",
                "teacher_name": r.get("teacher_name") or "",
                "reason": (f"Class mean {r['class_mean']:.0f} is {r['dev_from_teacher']:+.0f} "
                           f"points vs this teacher's own average — possible grade inflation"),
                "severity": "medium",
                "detected_by": "ml",
                "score": round(float(r["ml_score"]), 3),
            })

    # High severity first, then by score
    sev_rank = {"high": 0, "medium": 1, "low": 2}
    alerts.sort(key=lambda a: (sev_rank.get(a["severity"], 3), -a["score"]))

    return {
        "total_sessions_checked": int(len(sessions)),
        "total_assessments_checked": int(len(assessments)),
        "alerts": alerts[:limit],
        "alert_count": len(alerts),
        "models_loaded": smodel is not None and amodel is not None,
    }
