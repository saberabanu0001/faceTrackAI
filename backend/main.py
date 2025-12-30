from fastapi import FastAPI, UploadFile, File, Form
import tempfile, shutil, os
from backend.inference import FaceAnalysis

app = FastAPI()
model = FaceAnalysis()

@app.post("/compare")
async def compare_faces(
    img1: UploadFile = File(...),
    img2: UploadFile = File(...),
    threshold: float = Form(0.6)
):
    # Save first image
    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f1:
        shutil.copyfileobj(img1.file, f1)
        img1_path = f1.name

    # Save second image
    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f2:
        shutil.copyfileobj(img2.file, f2)
        img2_path = f2.name

    # Compare faces
    similarity, is_same = model.compare(img1_path, img2_path, threshold)

    # Clean up temp files
    os.remove(img1_path)
    os.remove(img2_path)

    return {
        "similarity": float(similarity),
        "is_same": bool(is_same)
    }
