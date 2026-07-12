import firebase_admin
from firebase_admin import credentials, firestore

cred = credentials.Certificate("serviceAccountKey.json")
firebase_admin.initialize_app(cred)

db = firestore.client()

db.collection("test_import").document("test_001").set({
    "message": "Koneksi Firebase dari Python berhasil",
    "source": "firebase_import_python",
})

print("Berhasil konek dan insert test ke Firebase.")
