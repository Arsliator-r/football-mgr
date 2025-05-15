from flask import Flask, request, jsonify
import firebase_admin
from firebase_admin import auth, credentials
import sys

# Load Firebase Admin SDK with Service Account Key
cred = credentials.Certificate(r"C:\Users\Arsalan\Desktop\flutter_projects\football_mgr\serviceAccountKey.json")  # Replace with your actual path
firebase_admin.initialize_app(cred)

app = Flask(__name__)

@app.route('/delete_user', methods=['POST'])
def delete_user():
    data = request.json
    email = data.get('email')

    if not email:
        return jsonify({"error": "Email is required"}), 400
    
    try:
        user = auth.get_user_by_email(email)  # Find user by email
        auth.delete_user(user.uid)  # Delete from Firebase Auth
        return jsonify({"message": f"✅ User {email} deleted successfully!"}), 200
    except firebase_admin.auth.UserNotFoundError:
        return jsonify({"error": f"❌ Error: User {email} not found."}), 404
    except Exception as e:
        return jsonify({"error": f"❌ Error: {e}"}), 500

if __name__ == "__main__":
    print("🔥 Firebase User Deletion API Running")
    app.run(host='0.0.0.0', port=5000)  # Run on localhost:5000