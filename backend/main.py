from fastapi import FastAPI, UploadFile, File, Form, HTTPException
from fastapi.middleware.cors import CORSMiddleware
import tempfile, shutil, os
import traceback
from backend.inference import FaceAnalysis

app = FastAPI()

# Add CORS middleware to allow requests from Flutter app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # In production, specify your Flutter app's origin
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

model = FaceAnalysis()

@app.post("/compare")
async def compare_faces(
    img1: UploadFile = File(...),
    img2: UploadFile = File(...),
    threshold: float = Form(0.6)
):
    img1_path = None
    img2_path = None
    
    try:
        print(f"Received request: img1={img1.filename}, img2={img2.filename}, threshold={threshold}")
        
        # Save first image
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpeg") as f1:
            shutil.copyfileobj(img1.file, f1)
            img1_path = f1.name
            print(f"Saved image1 to: {img1_path}")

        # Save second image
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpeg") as f2:
            shutil.copyfileobj(img2.file, f2)
            img2_path = f2.name
            print(f"Saved image2 to: {img2_path}")

        # Compare faces
        print("Starting face comparison...")
        similarity, is_same = model.compare(img1_path, img2_path, threshold)
        print(f"Comparison result: similarity={similarity}, is_same={is_same}")

        result = {
            "similarity": float(similarity),
            "is_same": bool(is_same)
        }
        
        return result
        
    except ValueError as e:
        error_msg = str(e)
        print(f"ValueError: {error_msg}")
        print(traceback.format_exc())
        raise HTTPException(status_code=400, detail=error_msg)
    except Exception as e:
        error_msg = f"Internal server error: {str(e)}"
        print(f"Exception: {error_msg}")
        print(traceback.format_exc())
        raise HTTPException(status_code=500, detail=error_msg)
    finally:
        # Clean up temp files
        
        if img1_path and os.path.exists(img1_path):
            try:
                os.remove(img1_path)
            except:
                pass
        if img2_path and os.path.exists(img2_path):
            try:
                os.remove(img2_path)
            except:
                pass

@app.get("/health")
async def health_check():
    return {"status": "ok", "message": "Backend is running"}
