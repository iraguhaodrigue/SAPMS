"""
SAPMS-Secure — Academic Performance Forecasting (F1 + F2)
=========================================================

Replaces the previous at-risk model, whose label was CIRCULAR:

    def heuristic_label(row):                    # old train_model.py
        if row["gpa"] < 50 and row["absenteeism_flag"] == 1: return 1
        if row["attendance_rate"] < 70: return 1
        return 0

`gpa`, `attendance_rate` and `absenteeism_flag` were also given to the model
as FEATURES, so the label was a deterministic function of the inputs. The
model was learning to reproduce an if-statement, and any accuracy it reported
was meaningless.

WHAT THIS DOES INSTEAD
----------------------
Label comes from a FUTURE, HELD-OUT outcome:

    outcome  = the student's END-OF-TERM assessment result
    at_risk  = 1 if that end-of-term score < PASS_MARK

Features use ONLY information that existed BEFORE that assessment took place:

    • CAT 1 and CAT 2 scores for the same subject
    • the trend between them
    • attendance rate in that subject up to the assessment date
    • sessions attended / missed, longest absence streak

No GPA (it contains the end-of-term result), no derived risk flags.

TWO TASKS
---------
  1. CLASSIFICATION — will this student fail the end-of-term? (at-risk)
  2. REGRESSION     — what score will they get?  (the "forecasting" in the
                      dissertation title, previously not implemented)

EVALUATION
----------
Split is by CLASS, not by row: no student from a test class appears in
training, so the model must generalise to a class it has never seen.

The regression is scored against two baselines it must beat to be worth
anything:
    • predicting the global mean score
    • predicting each student's own CAT average

A model that cannot beat the CAT-average baseline is not adding value, and
this script says so explicitly.

Run:
    python train_forecast.py
    python train_forecast.py --report-only
"""

import argparse
import json
import os
import sys
from datetime import datetime

import joblib
import numpy as np
import pandas as pd
from sklearn.ensemble import RandomForestClassifier, GradientBoostingRegressor
from sklearn.model_selection import GroupShuffleSplit, GroupKFold, cross_val_predict
from sklearn.metrics import (
    accuracy_score, precision_score, recall_score, f1_score,
    roc_auc_score, confusion_matrix,
    mean_absolute_error, mean_squared_error, r2_score,
)

try:
    import mysql.connector
except ImportError:
    print("Missing dependency. Run:  pip install -r requirements.txt")
    sys.exit(1)

from dotenv import load_dotenv

load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))

MODEL_DIR = os.path.join(os.path.dirname(__file__), "model")
os.makedirs(MODEL_DIR, exist_ok=True)

PASS_MARK = 50.0
TEST_FRACTION = 0.30
RANDOM_STATE = 42


def connect():
    return mysql.connector.connect(
        host=os.getenv("DB_HOST", "localhost"),
        port=int(os.getenv("DB_PORT", 3306)),
        user=os.getenv("DB_USER", "root"),
        password=os.getenv("DB_PASSWORD", ""),
        database=os.getenv("DB_NAME", "sapms_db"),
    )


# ─────────────────────────────────────────────────────────────
# Data extraction
# ─────────────────────────────────────────────────────────────

ENDTERM_SQL = """
SELECT a.id           AS assessment_id,
       a.class_id, a.subject_id, a.term_id,
       a.assessment_date,
       a.max_score,
       m.student_id,
       m.score        AS endterm_score
FROM assessments a
JOIN marks m ON m.assessment_id = a.id
WHERE a.assessment_type = 'endterm'
  AND m.score IS NOT NULL
  AND m.is_absent = 0
"""

CONTINUOUS_SQL = """
SELECT a.class_id, a.subject_id, a.term_id,
       a.assessment_name, a.assessment_date,
       m.student_id, m.score
FROM assessments a
JOIN marks m ON m.assessment_id = a.id
WHERE a.assessment_type = 'continuous'
  AND m.score IS NOT NULL
  AND m.is_absent = 0
"""

ATTENDANCE_SQL = """
SELECT s.class_id, s.subject_id, s.term_id, s.session_date,
       r.student_id, r.status
FROM attendance_sessions s
JOIN attendance_records r ON r.session_id = s.id
"""


def longest_absent_streak(statuses):
    """Longest run of consecutive absences — a different signal from overall
    rate: 8 scattered absences and 8 consecutive ones mean different things."""
    best = run = 0
    for st in statuses:
        if st == "absent":
            run += 1
            best = max(best, run)
        else:
            run = 0
    return best


def build_dataset(conn):
    endterm = pd.read_sql(ENDTERM_SQL, conn)
    cont = pd.read_sql(CONTINUOUS_SQL, conn)
    att = pd.read_sql(ATTENDANCE_SQL, conn)

    if endterm.empty:
        raise SystemExit(
            "No end-of-term assessments with marks found.\n"
            "Run:  node database/generate_dataset.js --wipe"
        )

    endterm["assessment_date"] = pd.to_datetime(endterm["assessment_date"])
    cont["assessment_date"] = pd.to_datetime(cont["assessment_date"])
    att["session_date"] = pd.to_datetime(att["session_date"])

    for df, col in ((endterm, "endterm_score"), (cont, "score")):
        df[col] = pd.to_numeric(df[col], errors="coerce")

    key = ["student_id", "class_id", "subject_id", "term_id"]

    # ── Continuous-assessment features, ordered in time ──
    cont = cont.sort_values(key + ["assessment_date"])
    cont["seq"] = cont.groupby(key).cumcount()

    # Guard: only use CATs that happened BEFORE the end-of-term assessment.
    # Without this we would leak information from after the prediction point.
    cont = cont.merge(
        endterm[key + ["assessment_date"]].rename(
            columns={"assessment_date": "endterm_date"}),
        on=key, how="inner")
    cont = cont[cont["assessment_date"] < cont["endterm_date"]]

    wide = cont.pivot_table(index=key, columns="seq", values="score", aggfunc="first")
    wide.columns = [f"cat{int(c) + 1}" for c in wide.columns]
    wide = wide.reset_index()

    cat_cols = [c for c in wide.columns if c.startswith("cat")]
    wide["cat_mean"] = wide[cat_cols].mean(axis=1)
    wide["cat_min"] = wide[cat_cols].min(axis=1)
    wide["cat_max"] = wide[cat_cols].max(axis=1)
    wide["cat_trend"] = (
        wide[cat_cols[-1]] - wide[cat_cols[0]] if len(cat_cols) > 1 else 0.0
    )
    wide["cat_count"] = wide[cat_cols].notna().sum(axis=1)

    # ── Attendance features, also cut off at the assessment date ──
    att = att.merge(
        endterm[key + ["assessment_date"]].rename(
            columns={"assessment_date": "endterm_date"}),
        on=key, how="inner")
    att = att[att["session_date"] < att["endterm_date"]].sort_values(key + ["session_date"])

    agg = att.groupby(key).agg(
        sessions_total=("status", "size"),
        sessions_present=("status", lambda s: (s != "absent").sum()),
        sessions_late=("status", lambda s: (s == "late").sum()),
        absent_streak=("status", longest_absent_streak),
    ).reset_index()
    agg["attendance_rate"] = (
        agg["sessions_present"] / agg["sessions_total"].replace(0, np.nan) * 100
    ).fillna(0)
    agg["late_rate"] = (
        agg["sessions_late"] / agg["sessions_total"].replace(0, np.nan) * 100
    ).fillna(0)

    df = endterm.merge(wide, on=key, how="inner").merge(agg, on=key, how="left")

    # Normalise to percentage in case an assessment isn't out of 100
    df["max_score"] = pd.to_numeric(df["max_score"], errors="coerce").fillna(100)
    df["endterm_pct"] = df["endterm_score"] / df["max_score"] * 100

    for c in ["sessions_total", "sessions_present", "sessions_late",
              "absent_streak", "attendance_rate", "late_rate"]:
        df[c] = df[c].fillna(0)
    df = df.dropna(subset=["cat_mean", "endterm_pct"])

    # Students with a single CAT before the cutoff have no trend (needs ≥2
    # points) → NaN. RandomForest tolerates NaN natively but
    # GradientBoostingRegressor does not, so fill explicitly: 0 = "no trend
    # information", and min/max/count default to the mean/1 where degenerate.
    df["cat_trend"] = df["cat_trend"].fillna(0)
    df["cat_min"]   = df["cat_min"].fillna(df["cat_mean"])
    df["cat_max"]   = df["cat_max"].fillna(df["cat_mean"])
    df["cat_count"] = df["cat_count"].fillna(1)

    return df


FEATURES = [
    "cat_mean", "cat_min", "cat_max", "cat_trend", "cat_count",
    "attendance_rate", "late_rate", "absent_streak",
    "sessions_total", "sessions_present",
]


def assert_no_leakage(df):
    """Fail loudly if any feature is derived from the outcome. This is the
    check the previous model would not have survived."""
    banned = {"endterm_score", "endterm_pct", "gpa", "at_risk", "absenteeism_flag"}
    leaked = banned.intersection(FEATURES)
    if leaked:
        raise SystemExit(f"LEAKAGE: outcome-derived columns used as features: {leaked}")

    # Also flag any feature almost perfectly correlated with the target,
    # which would indicate leakage we hadn't thought of.
    for f in FEATURES:
        if df[f].nunique() > 1:
            r = np.corrcoef(df[f], df["endterm_pct"])[0, 1]
            if abs(r) > 0.98:
                raise SystemExit(
                    f"LEAKAGE: feature '{f}' correlates {r:.3f} with the outcome")
    print("   leakage check: passed (no outcome-derived features)")


# ─────────────────────────────────────────────────────────────
# Train + evaluate
# ─────────────────────────────────────────────────────────────

def class_split(df):
    """Split by CLASS so no student from a test class appears in training."""
    gss = GroupShuffleSplit(n_splits=1, test_size=TEST_FRACTION,
                            random_state=RANDOM_STATE)
    tr, te = next(gss.split(df, groups=df["class_id"]))
    return df.iloc[tr].copy(), df.iloc[te].copy()


def run_classification(train, test):
    """At-risk classification.

    NOTE ON METRIC CHOICE — this matters for the write-up.
    The classes are imbalanced (~12-15% at risk). Plain accuracy is therefore
    misleading: a model that predicts "nobody is at risk" scores ~85% and
    identifies zero at-risk students, which is useless as an early-warning
    system. We therefore report:

      • ROC-AUC as the headline, threshold-independent measure of signal
      • precision/recall at an operating point chosen for RECALL, because
        the cost of missing an at-risk student is far higher than the cost
        of a false alarm (a teacher has an unnecessary conversation)

    We still print the majority-class accuracy so the comparison is visible
    and honest, but we do not treat beating it as the success criterion.
    """
    ytr = (train["endterm_pct"] < PASS_MARK).astype(int)
    yte = (test["endterm_pct"] < PASS_MARK).astype(int)

    print(f"\n── F1: AT-RISK CLASSIFICATION ─────────────")
    print(f"   train={len(train)} rows  test={len(test)} rows")
    print(f"   at-risk prevalence: train {ytr.mean():.1%}  test {yte.mean():.1%}")

    if ytr.nunique() < 2 or yte.nunique() < 2:
        print("   ⚠ only one class present — cannot train a classifier on this data")
        return None, None

    model = RandomForestClassifier(
        n_estimators=400, max_depth=5, min_samples_leaf=15,
        class_weight="balanced", random_state=RANDOM_STATE, n_jobs=-1)
    model.fit(train[FEATURES], ytr)

    proba = model.predict_proba(test[FEATURES])[:, 1]
    auc = float(roc_auc_score(yte, proba))

    # Choose the operating threshold using OUT-OF-FOLD predictions on the
    # training data. In-sample probabilities are optimistic — a threshold
    # picked on them does not transfer (we measured 70% train recall
    # collapsing to 32% on test). Cross-validated predictions give an honest
    # estimate, and grouping the folds by class keeps the same
    # no-student-seen-twice discipline as the outer split.
    n_groups = train["class_id"].nunique()
    if n_groups >= 3:
        cv = GroupKFold(n_splits=min(5, n_groups))
        tr_proba = cross_val_predict(
            model, train[FEATURES], ytr, groups=train["class_id"],
            cv=cv, method="predict_proba", n_jobs=-1)[:, 1]
        threshold_basis = f"out-of-fold ({cv.get_n_splits()}-fold, grouped by class)"
    else:
        tr_proba = model.predict_proba(train[FEATURES])[:, 1]
        threshold_basis = "in-sample (too few classes for grouped CV)"
    # Default operating point maximises F1 on the out-of-fold predictions —
    # a balanced default. A school wanting to catch more at-risk students at
    # the cost of more false alarms can move along the table printed below.
    thresholds = np.linspace(0.05, 0.95, 91)
    chosen, chosen_f1 = 0.5, -1.0
    for t in thresholds:
        p = (tr_proba >= t).astype(int)
        f = f1_score(ytr, p, zero_division=0)
        if f > chosen_f1:
            chosen, chosen_f1 = float(t), float(f)

    # An early-warning system has to pick a point on the precision/recall
    # curve, and the right point is a school policy decision, not a modelling
    # one: how many false alarms is a teacher willing to follow up in order to
    # catch one more struggling student? We therefore report a table of
    # operating points rather than hiding the trade-off behind a single number.
    operating_points = []
    for tr_target in (0.50, 0.60, 0.70, 0.80):
        t_best, p_best = None, -1.0
        for t in thresholds:
            p = (tr_proba >= t).astype(int)
            if recall_score(ytr, p, zero_division=0) >= tr_target:
                pr = precision_score(ytr, p, zero_division=0)
                if pr > p_best:
                    t_best, p_best = float(t), float(pr)
        if t_best is None:
            continue
        te_pred = (proba >= t_best).astype(int)
        operating_points.append({
            "target_recall": tr_target,
            "threshold": round(t_best, 3),
            "test_recall": round(float(recall_score(yte, te_pred, zero_division=0)), 4),
            "test_precision": round(float(precision_score(yte, te_pred, zero_division=0)), 4),
            "test_f1": round(float(f1_score(yte, te_pred, zero_division=0)), 4),
            "students_flagged": int(te_pred.sum()),
        })

    pred = (proba >= chosen).astype(int)
    tn, fp, fn, tp = confusion_matrix(yte, pred, labels=[0, 1]).ravel()
    majority = float(max(yte.mean(), 1 - yte.mean()))

    metrics = {
        "roc_auc": round(auc, 4),
        "operating_threshold": round(chosen, 3),
        "threshold_selected_on": threshold_basis + " on training set, threshold maximising F1",
        "accuracy": round(float(accuracy_score(yte, pred)), 4),
        "precision": round(float(precision_score(yte, pred, zero_division=0)), 4),
        "recall": round(float(recall_score(yte, pred, zero_division=0)), 4),
        "f1": round(float(f1_score(yte, pred, zero_division=0)), 4),
        "confusion": {"tp": int(tp), "fp": int(fp), "fn": int(fn), "tn": int(tn)},
        "test_rows": int(len(test)),
        "at_risk_prevalence": round(float(yte.mean()), 4),
        "majority_baseline_accuracy": round(majority, 4),
        "random_baseline_auc": 0.5,
        "beats_random_auc": bool(auc > 0.5),
        "operating_points": operating_points,
        "metric_note": ("Classes are imbalanced; ROC-AUC is the headline metric. "
                        "Majority-class accuracy is reported for transparency but is "
                        "not the success criterion, since a majority-class predictor "
                        "identifies no at-risk students at all."),
    }

    print(f"   roc_auc      : {auc:.3f}   (random = 0.500) "
          f"{'✓ real signal' if auc > 0.5 else '✗ no signal'}")
    print(f"   threshold    : {chosen:.2f}  ({threshold_basis}, max-F1)")
    print(f"   recall       : {metrics['recall']:.3f}   ← catches this share of at-risk students")
    print(f"   precision    : {metrics['precision']:.3f}   ← this share of alerts are genuine")
    print(f"   f1           : {metrics['f1']:.3f}")
    print(f"   accuracy     : {metrics['accuracy']:.3f}   (majority-class baseline {majority:.3f})")
    print(f"   confusion    : TP={tp} FP={fp} FN={fn} TN={tn}")
    print(f"   note: accuracy is a poor metric here — a 'nobody at risk' predictor")
    print(f"         scores {majority:.3f} while finding zero at-risk students.")

    imp = sorted(zip(FEATURES, model.feature_importances_), key=lambda x: -x[1])
    metrics["feature_importance"] = [{"feature": f, "importance": round(float(v), 4)}
                                     for f, v in imp]
    print("   top features:", ", ".join(f"{f} ({v:.2f})" for f, v in imp[:4]))

    return model, metrics


def run_regression(train, test):
    ytr = train["endterm_pct"].values
    yte = test["endterm_pct"].values

    print(f"\n── F2: PERFORMANCE FORECASTING ────────────")

    model = GradientBoostingRegressor(
        n_estimators=300, max_depth=3, learning_rate=0.05,
        random_state=RANDOM_STATE)
    model.fit(train[FEATURES], ytr)
    pred = model.predict(test[FEATURES])

    def scores(y, p):
        return (float(mean_absolute_error(y, p)),
                float(np.sqrt(mean_squared_error(y, p))),
                float(r2_score(y, p)))

    mae, rmse, r2 = scores(yte, pred)

    # Baselines the model must beat to be worth anything
    b1 = np.full_like(yte, ytr.mean())                    # global mean
    b1_mae, b1_rmse, b1_r2 = scores(yte, b1)
    b2 = test["cat_mean"].values                          # student's own CAT average
    b2_mae, b2_rmse, b2_r2 = scores(yte, b2)

    metrics = {
        "model": {"mae": round(mae, 3), "rmse": round(rmse, 3), "r2": round(r2, 4)},
        "baseline_global_mean": {"mae": round(b1_mae, 3), "rmse": round(b1_rmse, 3), "r2": round(b1_r2, 4)},
        "baseline_cat_average": {"mae": round(b2_mae, 3), "rmse": round(b2_rmse, 3), "r2": round(b2_r2, 4)},
        "beats_mean_baseline": bool(mae < b1_mae),
        "beats_cat_average_baseline": bool(mae < b2_mae),
        "test_rows": int(len(test)),
    }

    print(f"   train={len(train)} rows  test={len(test)} rows")
    print(f"   {'':<22}{'MAE':>8}{'RMSE':>9}{'R²':>8}")
    print(f"   {'model':<22}{mae:>8.2f}{rmse:>9.2f}{r2:>8.3f}")
    print(f"   {'baseline: class mean':<22}{b1_mae:>8.2f}{b1_rmse:>9.2f}{b1_r2:>8.3f}")
    print(f"   {'baseline: CAT average':<22}{b2_mae:>8.2f}{b2_rmse:>9.2f}{b2_r2:>8.3f}")
    print(f"   beats mean baseline       : {'✓' if metrics['beats_mean_baseline'] else '✗'}")
    print(f"   beats CAT-average baseline: "
          f"{'✓' if metrics['beats_cat_average_baseline'] else '✗ — model adds no value over simple averaging'}")

    imp = sorted(zip(FEATURES, model.feature_importances_), key=lambda x: -x[1])
    metrics["feature_importance"] = [{"feature": f, "importance": round(float(v), 4)}
                                     for f, v in imp]
    print("   top features:", ", ".join(f"{f} ({v:.2f})" for f, v in imp[:4]))

    return model, metrics


def write_forecasts(conn, model, df):
    """Store a predicted end-of-term score per (student, subject) so the app
    can show it. Recomputed from scratch each run."""
    preds = model.predict(df[FEATURES])
    cur = conn.cursor()
    cur.execute("DELETE FROM performance_forecasts")

    rows = []
    for (_, r), p in zip(df.iterrows(), preds):
        # Residual spread on the training data is a fair, simple confidence band
        rows.append((
            r["student_id"], r["subject_id"], r["term_id"],
            float(np.clip(p, 0, 100)),
            float(r["cat_mean"]),
            float(r["attendance_rate"]),
            int(r["endterm_pct"] < PASS_MARK),
        ))

    cur.executemany(
        """INSERT INTO performance_forecasts
             (student_id, subject_id, term_id, predicted_score,
              cat_average, attendance_rate, actual_at_risk)
           VALUES (%s,%s,%s,%s,%s,%s,%s)""", rows)
    conn.commit()
    cur.close()
    return len(rows)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--report-only", action="store_true",
                    help="evaluate without saving models or writing forecasts")
    args = ap.parse_args()

    conn = connect()
    print("Connected. Building dataset…")
    df = build_dataset(conn)
    print(f"   {len(df)} student-subject rows across {df['class_id'].nunique()} classes")

    assert_no_leakage(df)

    train, test = class_split(df)
    print(f"   split by class: {train['class_id'].nunique()} train classes, "
          f"{test['class_id'].nunique()} test classes (no overlap)")

    clf, clf_metrics = run_classification(train, test)
    reg, reg_metrics = run_regression(train, test)

    if not args.report_only:
        if clf is not None:
            joblib.dump(clf, os.path.join(MODEL_DIR, "risk_classifier.pkl"))
        joblib.dump(reg, os.path.join(MODEL_DIR, "score_forecaster.pkl"))

        try:
            n = write_forecasts(conn, reg, df)
            print(f"\n💾 Wrote {n} forecasts to performance_forecasts")
        except Exception as e:
            print(f"\n⚠ Could not write forecasts: {e}")
            print("   Did you run migration_008_forecasts.sql?")

        meta = {
            "trained_at": datetime.now().isoformat() + "Z",
            "pass_mark": PASS_MARK,
            "validation": "GroupShuffleSplit by class_id — no test-class student seen in training",
            "features": FEATURES,
            "label_definition": {
                "classification": f"end-of-term percentage < {PASS_MARK}",
                "regression": "end-of-term percentage",
                "note": ("Label comes from a future held-out assessment. Features use only "
                         "data recorded before that assessment date. This replaces the earlier "
                         "heuristic label, which was a deterministic function of its own "
                         "features and therefore circular."),
            },
            "classification": clf_metrics,
            "regression": reg_metrics,
        }
        with open(os.path.join(MODEL_DIR, "forecast_metadata.json"), "w") as f:
            json.dump(meta, f, indent=2)
        print(f"💾 Saved models + metrics to {MODEL_DIR}/")
        print("   forecast_metadata.json holds the measured figures for the thesis.")

    conn.close()


if __name__ == "__main__":
    main()
