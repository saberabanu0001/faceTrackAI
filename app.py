import streamlit as st
import tempfile
from inference import FaceAnalysis
from PIL import Image

st.set_page_config(page_title="Face Recognition", layout="centered")

st.title("Face recognition system ):")
st.write("Upload two face images to check whether they are same or not....")

@st.cache_resource
def load_model():
    return FaceAnalysis()

app = load_model()

col1, col2 = st.columns(2)

with col1:
    img1_file = st.file_uploader("Upload first image", type=["jpg", "jpeg", "png"])
with col2:
    img2_file = st.file_uploader("Upload second image",  type=["jpg", "jpeg", "png"])

threshold = st.slider(
    "Similarity Threshold (higher = stricter)",
    min_value = 0.3,
    max_value = 0.9,
    value = 0.6,
    step = 0.01
)
##compare button
if st.button("Compare faces 🔍"):
    if img1_file is None or img2_file is None:
        st.warning("Please upload both iamges")
    else:
        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f1:
            f1.write(img1_file.read())
            img1_path = f1.name

        with tempfile.NamedTemporaryFile(delete=False, suffix=".jpg") as f2:
            f2.write(img2_file.read())
            img2_path = f2.name
