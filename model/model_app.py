from flask import Flask, request, jsonify
import pandas as pd
import joblib

# Initialize Flask app
app = Flask(__name__)

# Load models
model = joblib.load(r"C:\Users\Arsalan\Desktop\flutter_projects\football_mgr\model\best_model_stacking.pkl")
scaler = joblib.load(r"C:\Users\Arsalan\Desktop\flutter_projects\football_mgr\model\scaler.pkl")
label_encoder = joblib.load(r"C:\Users\Arsalan\Desktop\flutter_projects\football_mgr\model\label_encoder.pkl")

@app.route("/predict", methods=["POST"])
def predict_position():
    try:
        data = request.get_json()

        # Extract and prepare features
        player = {
            "Weak Foot": data["weak_foot"],
            "Pace": data["pace"],
            "Shooting": data["shooting"],
            "Passing": data["passing"],
            "Dribbling": data["dribbling"],
            "Defending": data["defending"],
            "Physicality": data["physicality"],
            "Height_cm": data["height_cm"]
        }

        # Add derived features
        player["Attacking"] = (player["Shooting"] + player["Passing"] + player["Dribbling"]) / 3
        player["Defensive"] = (player["Defending"] + player["Physicality"]) / 2

        # Convert to DataFrame
        df = pd.DataFrame([player])

        # Scale
        df_scaled = scaler.transform(df)

        # Predict
        pred_encoded = model.predict(df_scaled)
        pred_label = label_encoder.inverse_transform(pred_encoded)

        return jsonify({"position": pred_label[0]})

    except Exception as e:
        return jsonify({"error": str(e)}), 500

# Run the app
if __name__ == "__main__":
    app.run(host='0.0.0.0', port=5001, debug=True)
