# Face Recognition System

A Python-based face recognition system that compares two face images and determines if they belong to the same person. The system uses the `face_recognition` library (dlib-based) for accurate and fast face comparison.

## 🎯 Features

- **Face Comparison**: Compare two face images and determine if they belong to the same person
- **Similarity Scoring**: Get a similarity score (0.0-1.0) indicating how similar two faces are
- **Configurable Threshold**: Adjustable similarity threshold for customizing match sensitivity
- **Multiple Interfaces**: 
  - Command-line interface (CLI) for quick comparisons
  - Streamlit web application for interactive use
- **Robust Error Handling**: Clear error messages for missing faces or invalid images
- **Fast & Accurate**: Uses dlib's optimized face recognition model

## 📋 Requirements

- Python 3.9+
- face-recognition library
- dlib
- Pillow
- numpy
- streamlit (for web app)

## 🚀 Installation

### 1. Clone or navigate to the project directory

```bash
cd classification-face-rec
```

### 2. Create a virtual environment (recommended)

```bash
python -m venv face
source face/bin/activate  # On Windows: face\Scripts\activate
```

### 3. Install dependencies

```bash
pip install face-recognition streamlit pillow numpy
```

**Note**: The `face-recognition` library requires `dlib`, which may need additional system dependencies. On macOS, you may need:
```bash
brew install cmake
```

## 💻 Usage

### Command-Line Interface (CLI)

#### Basic Usage

Compare two face images with default settings:

```bash
python run_face_recognition.py --img1 face1.jpeg --img2 face2.jpeg
```

#### With Custom Threshold

Adjust the similarity threshold (higher = stricter matching):

```bash
python run_face_recognition.py --img1 face1.jpeg --img2 face2.jpeg --threshold 0.7
```

#### Command-Line Options

```
--img1       Path to first image (default: face1.jpeg)
--img2       Path to second image (default: face2.jpeg)
--threshold  Similarity threshold (0.0-1.0, default: 0.6)
             Higher values = stricter matching
```

#### Example Output

```
⏳ Initializing models...
✅ Using face_recognition library (dlib-based)
   Model will be loaded on first use.
🔍 Comparing face1.jpeg vs face2.jpeg...
------------------------------
🔹 Similarity Score: 0.3537
------------------------------
❌ RESULT: DIFFERENT PERSON
```

### Web Application (Streamlit)

Launch the interactive web interface:

```bash
streamlit run app.py
```

The web app provides:
- Image upload interface
- Real-time similarity threshold adjustment
- Visual comparison of uploaded images
- Instant results display

## 🧠 How It Works

### 1. Face Detection
The system first detects faces in both input images using dlib's face detection model.

### 2. Face Encoding
Each detected face is converted into a 128-dimensional vector (face embedding) that uniquely represents the facial features.

### 3. Distance Calculation
The Euclidean distance between the two face embeddings is calculated. Lower distance = more similar faces.

### 4. Similarity Conversion
Distance is converted to a similarity score:
```
similarity = 1.0 - distance
```

### 5. Comparison Decision
The similarity score is compared against the threshold:
```
is_same_person = similarity >= threshold
```

For more detailed explanations, see:
- [EMBEDDING.md](EMBEDDING.md) - How face embeddings work
- [THRESHOLD.md](THRESHOLD.md) - Understanding similarity thresholds

## 📊 Understanding Similarity Scores

| Similarity Score | Interpretation |
|-----------------|----------------|
| 0.8 - 1.0 | Very similar / Same person |
| 0.6 - 0.8 | Similar / Likely same person |
| 0.4 - 0.6 | Somewhat similar / Possibly same person |
| 0.0 - 0.4 | Different / Different people |

## 🎚️ Choosing the Right Threshold

The threshold determines how strict the matching should be:

| Threshold | Behavior | Use Case |
|-----------|----------|----------|
| 0.7 - 0.9 | Very strict | Security applications, high accuracy needed |
| 0.6 - 0.7 | Balanced (recommended) | General purpose, good trade-off |
| 0.5 - 0.6 | Lenient | When you want to catch all possible matches |

**Default threshold: 0.6** - Provides a good balance between accuracy and false positives.

## 📁 Project Structure

```
classification-face-rec/
├── inference.py              # Core FaceAnalysis class
├── run_face_recognition.py   # CLI script
├── app.py                    # Streamlit web application
├── README.md                 # This file
├── EMBEDDING.md              # Face embeddings explanation
├── THRESHOLD.md              # Threshold guide
├── face1.jpeg                # Sample image 1
├── face2.jpeg                # Sample image 2
├── face3.jpeg                # Sample image 3
└── face/                     # Virtual environment
```

## 🔧 API Usage

You can also use the `FaceAnalysis` class directly in your Python code:

```python
from inference import FaceAnalysis

# Initialize the face analysis system
app = FaceAnalysis()

# Compare two images
similarity, is_same = app.compare(
    img1_path="path/to/image1.jpg",
    img2_path="path/to/image2.jpg",
    threshold=0.6
)

print(f"Similarity: {similarity:.4f}")
print(f"Same person: {is_same}")
```

### FaceAnalysis Class

#### `__init__()`
Initializes the face recognition system. The model is loaded on first use.

#### `compare(img1_path, img2_path, threshold=0.6)`
Compares two face images.

**Parameters:**
- `img1_path` (str): Path to first image
- `img2_path` (str): Path to second image
- `threshold` (float): Similarity threshold (0.0-1.0, default: 0.6)

**Returns:**
- `tuple`: (similarity_score, is_same_person)
  - `similarity_score` (float): 0.0-1.0, where 1.0 = identical
  - `is_same_person` (bool): True if faces match, False otherwise

**Raises:**
- `FileNotFoundError`: If image files don't exist
- `ValueError`: If no face is detected in an image or other errors occur

## ⚠️ Important Notes

1. **Face Detection**: The system requires clear, front-facing faces. Side profiles or heavily obscured faces may not be detected.

2. **Image Quality**: Better image quality (resolution, lighting, clarity) leads to more accurate results.

3. **Multiple Faces**: If an image contains multiple faces, only the first detected face is used for comparison.

4. **Model Loading**: The face recognition model is loaded on first use, which may take a few seconds.

5. **Privacy**: All processing is done locally. No images are sent to external servers.

## 🐛 Troubleshooting

### "No face detected" Error

**Problem**: The system cannot detect a face in one or both images.

**Solutions**:
- Ensure images contain clear, front-facing faces
- Check image quality and lighting
- Try different images with better face visibility
- Ensure faces are not heavily obscured or at extreme angles

### Installation Issues

**Problem**: `dlib` installation fails.

**Solutions**:
- Install CMake: `brew install cmake` (macOS) or `apt-get install cmake` (Linux)
- Install system dependencies for dlib compilation
- Consider using pre-built wheels if available for your platform

### Low Similarity Scores

**Problem**: Similar faces are getting low similarity scores.

**Solutions**:
- Lower the threshold (e.g., from 0.6 to 0.5)
- Ensure both images have similar lighting and angles
- Check image quality and resolution

## 📝 Examples

### Example 1: Compare Two Images

```bash
python run_face_recognition.py --img1 person1.jpg --img2 person2.jpg
```

### Example 2: Strict Matching

```bash
python run_face_recognition.py --img1 person1.jpg --img2 person2.jpg --threshold 0.8
```

### Example 3: Lenient Matching

```bash
python run_face_recognition.py --img1 person1.jpg --img2 person2.jpg --threshold 0.5
```

## 🔬 Technical Details

- **Face Recognition Library**: `face_recognition` (v1.3.0+)
- **Backend Model**: dlib's face recognition model
- **Encoding Dimension**: 128-dimensional vectors
- **Distance Metric**: Euclidean distance
- **Face Detection**: HOG (Histogram of Oriented Gradients) based detector

## 📚 Additional Resources

- [face_recognition Library Documentation](https://github.com/ageitgey/face_recognition)
- [dlib Face Recognition](http://dlib.net/face_recognition.py.html)
- [Face Embeddings Explained](EMBEDDING.md)
- [Threshold Guide](THRESHOLD.md)

## 🤝 Contributing

Feel free to submit issues, fork the repository, and create pull requests for any improvements.

## 📄 License

This project is open source and available for educational and personal use.

## 🙏 Acknowledgments

- Built using the excellent [face_recognition](https://github.com/ageitgey/face_recognition) library
- Powered by [dlib](http://dlib.net/) machine learning library
- Web interface built with [Streamlit](https://streamlit.io/)

---

**Made with ❤️ for face recognition applications**

