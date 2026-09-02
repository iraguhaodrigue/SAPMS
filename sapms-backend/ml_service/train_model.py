"""
SAPMS - Predictive Model Training Script
==========================================
Implements proposal Section 3.7.5: trains Logistic Regression, Decision
Tree, and Random Forest classifiers to flag at-risk students, evaluates
each with 5-fold cross-validation (accuracy / precision / recall / F1 /
AUC-ROC per Table 3.5), and exports the best performer (Random Forest,
per the proposal's stated result) via joblib for the Flask microservice
to load.

TWO MODES:
  1. --source db   Pulls real feature data from the SAPMS MySQL database
                    (attendance_records + marks, engineered the same way
                    as Table 3.3). Use this once a school has real data.
  2. --source demo Generates a synthetic dataset shaped like the 780-
                    student / 11-subject / 3-term historical dataset
                    described in Section 3.3, so the whole pipeline
                    (train -> export -> serve -> predict) can be tested
                    end-to-end before real school data exists.

Usage:
    python train_model.py --source demo
    python train_model.py --source db --db-host localhost --db-user root ...
"""

import argparse
import json
import os
import sys

import joblib
import numpy as np
from dotenv import load_dotenv

# DB credentials come from ../.env (same as train_forecast.py / train_anomaly.py),
# so `python train_model.py --source db` works without retyping passwords.
load_dotenv(os.path.join(os.path.dirname(__file__), "..", ".env"))
import pandas as pd
from imblearn.over_sampling import SMOTE
from sklearn.ensemble import RandomForestClassifier
from sklearn.linear_model import LogisticRegression
from sklearn.metrics import (accuracy_score, f1_score, precision_score,
                              recall_score, roc_auc_score)
from sklearn.model_selection import StratifiedKFold, train_test_split
from sklearn.preprocessing import StandardScaler
from sklearn.tree import DecisionTreeClassifier

MODEL_DIR = os.path.join(os.path.dirname(__file__), "model")
os.makedirs(MODEL_DIR, exist_ok=True)

FEATURE_COLUMNS = [
    "attendance_rate",
    "absenteeism_flag",
    "absenteeism_duration",
    "gpa",
    "performance_trend_numeric",
    "subject_weakness_count",
]


# ─────────────────────────────────────────────────────────────────
# Data loading
# ─────────────────────────────────────────────────────────────────
def load_from_db(args) -> pd.DataFrame:
    """Builds a LEAKAGE-FREE training set from MySQL.

    The previous version labelled `at_risk` with heuristic_label(), a
    deterministic function of the very features fed to the model
    (gpa/attendance thresholds). The model was therefore re-deriving an
    if-statement and every accuracy figure was meaningless.

    Corrected design — label is a FUTURE, HELD-OUT outcome:

        label   : did the student fail their End-of-Term assessments?
                  (avg endterm score < 50, or missed every endterm)
        cutoff  : the student's class's earliest endterm date in that term
        features: computed ONLY from data dated BEFORE the cutoff —
                  attendance to date, continuous-assessment (CAT) marks,
                  trend across CATs, weak subjects among CATs.

    Nothing dated on/after the cutoff can reach a feature, so the task is
    genuine prediction of an unseen outcome rather than a tautology.
    """
    import mysql.connector

    conn = mysql.connector.connect(
        host=args.db_host, user=args.db_user, password=args.db_password,
        database=args.db_name, port=args.db_port,
    )

    # ── Outcome + per-student cutoff ──────────────────────────────
    endterm = pd.read_sql("""
        SELECT m.student_id, a.term_id, st.class_id,
               MIN(a.assessment_date) AS cutoff_date,
               AVG(CASE WHEN m.is_absent = 0 THEN m.score END) AS endterm_avg,
               SUM(m.is_absent = 0) AS endterm_sat
        FROM marks m
        JOIN assessments a ON a.id = m.assessment_id
        JOIN students st   ON st.id = m.student_id
        WHERE a.assessment_type = 'endterm'
        GROUP BY m.student_id, a.term_id, st.class_id
    """, conn)

    if endterm.empty:
        conn.close()
        raise SystemExit(
            "[train_model] No 'endterm' assessments found — cannot build an "
            "outcome-based label. Run the dataset generator, or wait until a "
            "real end-of-term assessment has been marked."
        )

    endterm["cutoff_date"] = pd.to_datetime(endterm["cutoff_date"])
    endterm["at_risk"] = (
        (endterm["endterm_sat"] == 0)
        | (pd.to_numeric(endterm["endterm_avg"], errors="coerce").fillna(0) < 50)
    ).astype(int)

    # ── Raw pre-cutoff inputs (filtered in pandas per-student) ────
    att = pd.read_sql("""
        SELECT ar.student_id, sess.term_id, sess.session_date, ar.status
        FROM attendance_records ar
        JOIN attendance_sessions sess ON sess.id = ar.session_id
        WHERE sess.is_closed = 1
    """, conn)
    att["session_date"] = pd.to_datetime(att["session_date"])

    cats = pd.read_sql("""
        SELECT m.student_id, a.term_id, a.subject_id, a.assessment_date,
               m.score, m.is_absent
        FROM marks m
        JOIN assessments a ON a.id = m.assessment_id
        WHERE a.assessment_type <> 'endterm'
    """, conn)
    conn.close()
    cats["assessment_date"] = pd.to_datetime(cats["assessment_date"])
    cats["score"] = pd.to_numeric(cats["score"], errors="coerce")

    cut = endterm.set_index(["student_id", "term_id"])["cutoff_date"]

    att = att.join(cut, on=["student_id", "term_id"], how="inner")
    att = att[att["session_date"] < att["cutoff_date"]]

    cats = cats.join(cut, on=["student_id", "term_id"], how="inner")
    cats = cats[(cats["assessment_date"] < cats["cutoff_date"]) & (cats["is_absent"] == 0)]

    # ── Feature engineering (identical column names to Table 3.3, so the
    #    serving path in app.py / mlService.js needs no change) ────
    grp = att.groupby(["student_id", "term_id"])
    feats = pd.DataFrame({
        "sessions": grp.size(),
        "present":  grp["status"].apply(lambda x: x.isin(["present", "late"]).sum()),
    })
    feats["attendance_rate"] = (feats["present"] / feats["sessions"] * 100).round(2)
    feats["absenteeism_flag"] = (feats["attendance_rate"] < 85).astype(int)

    # recent absences: last 30 days BEFORE the cutoff (not CURDATE — that
    # would leak "now" into a historical window)
    def _recent_abs(g):
        cutoff = g["cutoff_date"].iloc[0]
        recent = g[g["session_date"] >= cutoff - pd.Timedelta(days=30)]
        return (recent["status"] == "absent").sum()
    feats["absenteeism_duration"] = att.groupby(["student_id", "term_id"]).apply(
        _recent_abs, include_groups=False)

    cgrp = cats.groupby(["student_id", "term_id"])
    feats["gpa"] = cgrp["score"].mean().round(2)          # CA average to date

    def _trend(g):
        g = g.sort_values("assessment_date")
        if len(g) < 2:
            return 0
        mid = len(g) // 2
        delta = g["score"].iloc[mid:].mean() - g["score"].iloc[:mid].mean()
        return 1 if delta > 3 else (-1 if delta < -3 else 0)
    feats["performance_trend_numeric"] = cgrp.apply(_trend, include_groups=False)

    weak = (cats.groupby(["student_id", "term_id", "subject_id"])["score"]
                .mean().lt(50).groupby(["student_id", "term_id"]).sum())
    feats["subject_weakness_count"] = weak

    df = feats.reset_index().merge(
        endterm[["student_id", "term_id", "at_risk", "endterm_avg"]],
        on=["student_id", "term_id"], how="inner",
    )
    df["endterm_avg"] = pd.to_numeric(df["endterm_avg"], errors="coerce")
    df = df.dropna(subset=["gpa", "attendance_rate"])
    df["performance_trend_numeric"] = df["performance_trend_numeric"].fillna(0)
    df["subject_weakness_count"] = df["subject_weakness_count"].fillna(0).astype(int)
    df["absenteeism_duration"] = df["absenteeism_duration"].fillna(0).astype(int)

    if args.labels_csv:
        labels = pd.read_csv(args.labels_csv)  # columns: student_id, at_risk (0/1)
        df = df.drop(columns=["at_risk"]).merge(labels, on="student_id", how="inner")

    # endterm_avg rides along for train_forecast.py (regression target);
    # the classifier below simply never selects it.
    return df[["student_id", "term_id"] + FEATURE_COLUMNS + ["at_risk", "endterm_avg"]]


def load_demo_data(n_students: int = 780, seed: int = 42) -> pd.DataFrame:
    """Synthetic dataset shaped like the thesis's 780-student historical
    dataset (Section 3.3), for testing the pipeline before real data
    exists. Distributions are loosely calibrated to the attendance/dropout
    figures cited in Chapter 1 (Nyamasheke ~18.7% dropout-adjacent risk)."""
    rng = np.random.default_rng(seed)
    n = n_students

    attendance_rate = np.clip(rng.normal(82, 14, n), 20, 100)
    absenteeism_flag = (attendance_rate < 85).astype(int)
    absenteeism_duration = np.clip(
        (100 - attendance_rate) / 100 * 30 + rng.normal(0, 3, n), 0, 30
    ).astype(int)
    gpa = np.clip(rng.normal(58, 18, n) - absenteeism_flag * rng.uniform(2, 10, n), 0, 100)
    trend_numeric = rng.choice([-1, 0, 1], size=n, p=[0.3, 0.4, 0.3])
    subject_weakness_count = np.clip(
        rng.poisson(1.2, n) + (gpa < 50).astype(int) * rng.integers(0, 3, n), 0, 11
    )

    df = pd.DataFrame({
        "student_id": [f"demo-{i:04d}" for i in range(n)],
        "term_id": "demo-term",
        "attendance_rate": attendance_rate.round(2),
        "absenteeism_flag": absenteeism_flag,
        "absenteeism_duration": absenteeism_duration,
        "gpa": gpa.round(2),
        "performance_trend_numeric": trend_numeric,
        "subject_weakness_count": subject_weakness_count,
    })
    # Simulate a FUTURE end-of-term outcome from a latent risk that the
    # features only partially reveal (adds irreducible noise), instead of a
    # deterministic function of the features — mirrors the corrected DB path.
    latent = (
        0.05 * (85 - attendance_rate)
        + 0.06 * (55 - gpa)
        + 0.35 * subject_weakness_count
        - 0.4 * trend_numeric
        + rng.normal(0, 1.6, n)          # unobserved factors
    )
    df["at_risk"] = (latent > np.quantile(latent, 0.80)).astype(int)
    return df


# ─────────────────────────────────────────────────────────────────
# Training
# ─────────────────────────────────────────────────────────────────
def evaluate(model, X_test, y_test) -> dict:
    y_pred = model.predict(X_test)
    y_prob = model.predict_proba(X_test)[:, 1]
    return {
        "accuracy": round(accuracy_score(y_test, y_pred), 4),
        "precision": round(precision_score(y_test, y_pred, zero_division=0), 4),
        "recall": round(recall_score(y_test, y_pred, zero_division=0), 4),
        "f1": round(f1_score(y_test, y_pred, zero_division=0), 4),
        "auc_roc": round(roc_auc_score(y_test, y_prob), 4),
    }


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", choices=["db", "demo"], default="demo")
    parser.add_argument("--db-host", default=os.environ.get("DB_HOST", "localhost"))
    parser.add_argument("--db-user", default=os.environ.get("DB_USER", "root"))
    parser.add_argument("--db-password", default=os.environ.get("DB_PASSWORD", ""))
    parser.add_argument("--db-name", default=os.environ.get("DB_NAME", "sapms_db"))
    parser.add_argument("--db-port", type=int, default=int(os.environ.get("DB_PORT", 3306)))
    parser.add_argument("--labels-csv", default=None,
                         help="Optional CSV with columns student_id,at_risk for verified outcomes")
    args = parser.parse_args()

    print(f"[train_model] Loading data (source={args.source}) ...")
    df = load_from_db(args) if args.source == "db" else load_demo_data()
    print(f"[train_model] {len(df)} student-term rows loaded. "
          f"At-risk rate: {df['at_risk'].mean():.1%}")

    if len(df) < 30:
        print("ERROR: not enough data to train reliably (need at least ~30 rows). "
              "Run with --source demo to test the pipeline, or collect more real data.")
        sys.exit(1)

    X = df[FEATURE_COLUMNS].fillna(0).values
    y = df["at_risk"].values

    scaler = StandardScaler()
    X_scaled = scaler.fit_transform(X)

    X_train, X_test, y_train, y_test = train_test_split(
        X_scaled, y, test_size=0.15, stratify=y, random_state=42
    )
    # Further split train into train/validation (70/15/15 overall, per Section 3.7.5)
    X_train, X_val, y_train, y_val = train_test_split(
        X_train, y_train, test_size=0.1765, stratify=y_train, random_state=42
    )  # 0.1765 * 0.85 ≈ 0.15 of original

    # SMOTE class balancing on the training set only
    if len(np.unique(y_train)) > 1 and min(np.bincount(y_train)) >= 2:
        sm = SMOTE(random_state=42)
        X_train, y_train = sm.fit_resample(X_train, y_train)
        print(f"[train_model] After SMOTE: {len(X_train)} training rows "
              f"({y_train.mean():.1%} at-risk)")

    models = {
        "logistic_regression": LogisticRegression(max_iter=1000, random_state=42),
        "decision_tree": DecisionTreeClassifier(max_depth=6, random_state=42),
        "random_forest": RandomForestClassifier(n_estimators=200, max_depth=10, random_state=42),
    }

    skf = StratifiedKFold(n_splits=5, shuffle=True, random_state=42)
    results = {}
    for name, model in models.items():
        cv_scores = []
        for train_idx, val_idx in skf.split(X_train, y_train):
            m = model.__class__(**model.get_params())
            m.fit(X_train[train_idx], y_train[train_idx])
            cv_scores.append(evaluate(m, X_train[val_idx], y_train[val_idx])["f1"])

        model.fit(X_train, y_train)
        test_metrics = evaluate(model, X_test, y_test)
        results[name] = {**test_metrics, "cv_f1_mean": round(float(np.mean(cv_scores)), 4)}
        print(f"[train_model] {name}: {results[name]}")

    # Rank by AUC-ROC; on ties, prefer Random Forest (it's the most robust
    # of the three to overfitting on small datasets — the proposal's
    # stated outcome, Section 3.7.5) then Decision Tree then Logistic Regression.
    tie_break_order = {"random_forest": 0, "decision_tree": 1, "logistic_regression": 2}
    best_name = max(
        results,
        key=lambda k: (results[k]["auc_roc"], -tie_break_order.get(k, 9))
    )
    best_model = models[best_name]
    print(f"\n[train_model] Best model: {best_name} -> {results[best_name]}")
    if len(set(round(r["auc_roc"], 4) for r in results.values())) == 1:
        print("[train_model] NOTE: All models scored identically — this happens with the "
              "synthetic --source demo data because labels are generated by the same rule "
              "used as a feature signal. With real --source db data (independent, "
              "human-verified outcomes), expect the more realistic separation described "
              "in the proposal (Random Forest edging out the others).")

    joblib.dump(best_model, os.path.join(MODEL_DIR, "risk_model.pkl"))
    joblib.dump(scaler, os.path.join(MODEL_DIR, "scaler.pkl"))
    with open(os.path.join(MODEL_DIR, "metadata.json"), "w") as f:
        json.dump({
            "model_name": best_name,
            "model_version": "1.0",
            "feature_columns": FEATURE_COLUMNS,
            "metrics": results[best_name],
            "all_model_metrics": results,
            "trained_on_rows": len(df),
            "source": args.source,
        }, f, indent=2)

    print(f"\n[train_model] Saved model, scaler, and metadata to {MODEL_DIR}/")
    print("[train_model] Start the microservice with: python app.py")


if __name__ == "__main__":
    main()
