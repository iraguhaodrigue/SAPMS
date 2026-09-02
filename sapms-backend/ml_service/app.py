"""
SAPMS - ML Prediction Microservice
====================================
Loads the trained Random Forest (or best-performing) model and scaler
from ./model/ and serves risk predictions over HTTP for the Node.js
backend (see sapms-backend/src/services/mlService.js).

Run:
    python train_model.py --source demo   # first, to produce a model
    python app.py

Endpoints:
    GET  /health   -> {"status": "ok", "model_loaded": true, "model_version": "1.0"}
    POST /predict  -> body: {attendance_rate, absenteeism_flag, absenteeism_duration,
                              gpa, performance_trend_numeric, subject_weakness_count}
                       returns: {risk_level, risk_score, model_version}
"""

import json
import os

import joblib
import numpy as np
from flask import Flask, jsonify, request

MODEL_DIR = os.path.join(os.path.dirname(__file__), "model")
MODEL_PATH = os.path.join(MODEL_DIR, "risk_model.pkl")
SCALER_PATH = os.path.join(MODEL_DIR, "scaler.pkl")
METADATA_PATH = os.path.join(MODEL_DIR, "metadata.json")

app = Flask(__name__)

model = None
scaler = None
metadata = {}


def load_artifacts():
    global model, scaler, metadata
    if os.path.exists(MODEL_PATH) and os.path.exists(SCALER_PATH):
        model = joblib.load(MODEL_PATH)
        scaler = joblib.load(SCALER_PATH)
        with open(METADATA_PATH) as f:
            metadata = json.load(f)
        print(f"[ml_service] Loaded model '{metadata.get('model_name')}' "
              f"v{metadata.get('model_version')} (AUC-ROC={metadata['metrics']['auc_roc']})")
    else:
        print("[ml_service] WARNING: no trained model found in ./model/. "
              "Run `python train_model.py --source demo` first. "
              "Node.js backend will fall back to rule-based scoring until then.")


load_artifacts()


@app.route("/health", methods=["GET"])
def health():
    return jsonify({
        "status": "ok",
        "model_loaded": model is not None,
        "model_name": metadata.get("model_name"),
        "model_version": metadata.get("model_version"),
    })


@app.route("/predict", methods=["POST"])
def predict():
    if model is None or scaler is None:
        return jsonify({"error": "Model not loaded. Run train_model.py first."}), 503

    body = request.get_json(force=True) or {}
    feature_columns = metadata["feature_columns"]

    try:
        row = [float(body.get(col, 0)) for col in feature_columns]
    except (TypeError, ValueError) as e:
        return jsonify({"error": f"Invalid feature values: {e}"}), 400

    X = scaler.transform(np.array([row]))
    proba = model.predict_proba(X)[0]
    # proba[1] = probability of class 1 (at-risk)
    risk_score = float(proba[1] if len(proba) > 1 else proba[0])

    if risk_score >= 0.7:
        risk_level = "high"
    elif risk_score >= 0.4:
        risk_level = "moderate"
    else:
        risk_level = "low"

    return jsonify({
        "risk_level": risk_level,
        "risk_score": round(risk_score, 4),
        "model_version": metadata.get("model_version", "unknown"),
        "model_name": metadata.get("model_name"),
    })


@app.route("/model-info", methods=["GET"])
def model_info():
    """Exposes the full evaluation report (Table 3.5 metrics) for the
    thesis Chapter 4 results section."""
    if not metadata:
        return jsonify({"error": "No model trained yet"}), 404
    return jsonify(metadata)


@app.route("/detect-anomalies", methods=["GET"])
def detect_anomalies():
    """Layer 3 of SAPMS-Secure: runs hybrid rule + Isolation Forest
    detection over current DB state. Heavy import is done lazily so the
    risk-prediction endpoints stay fast even if anomaly models are absent."""
    try:
        from detect import detect
        limit = int(request.args.get("limit", 100))
        return jsonify(detect(limit=limit))
    except FileNotFoundError:
        return jsonify({"error": "Anomaly models not trained. Run train_anomaly.py"}), 503
    except Exception as e:
        return jsonify({"error": str(e)}), 500


if __name__ == "__main__":
    port = int(os.environ.get("ML_SERVICE_PORT", 8001))
    app.run(host="0.0.0.0", port=port, debug=False)
