from fastapi import FastAPI, UploadFile, File, Form
import tempfile
from inference import FaceAnalysis

app = FastAPI()
model = FaceAnalysis()

@app.post("/compare")
async def compare_faces(
    img1: UploadFile = File(...),
    img2: UploadFile = File(...),
    threshold: float = Form(0.6)
):
    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f1:
        f1.write(await img1.read())
        img1_path = f1.name

    with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f2:
        f2.write(await img2.read())
        img2_path = f2.name

    similarity, is_same = model.compare(img1_path, img2_path, threshold)

    return {
        "similarity": similarity,
        "is_same": is_same
    }