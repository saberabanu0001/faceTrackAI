import os

import torch
import numpy as np
from PIL import Image
from transformers import AutoModel, AutoImageProcessor
from sklearn.metrics.pairwise import cosine_similarity

class FaceAnalysis:
    def __init__(self):
        self.model_name = "biometric-ai-lab/Face_Recognition"
        self.processor = AutoImageProcessor.from_pretrained(self.model_name)
        self.model = AutoModel.from_pretrained(self.model_name)
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        self.model.to(self.device)
        self.model.eval()

    def _get_embedding(self, image_path):
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found: {image_path}")

        try:
            image = Image.open(image_path).convert("RGB")
        except Exception as exc:
            raise ValueError(f"Could not load image {image_path}: {exc}") from exc

        inputs = self.processor(images=image, return_tensors="pt")
        inputs = {k: v.to(self.device) for k, v in inputs.items()}

        with torch.no_grad():
            outputs = self.model(**inputs)

        embedding = getattr(outputs, "pooler_output", None)
        if embedding is None:
            embedding = outputs.last_hidden_state.mean(dim=1)

        embedding = torch.nn.functional.normalize(embedding, p=2, dim=1)
        return embedding.detach().cpu().numpy()

    def compare(self, img1_path, img2_path, threshold=0.75):
        emb1 = self._get_embedding(img1_path)
        emb2 = self._get_embedding(img2_path)

        similarity = cosine_similarity(emb1, emb2)[0][0]
        is_same = similarity > threshold

        return similarity, is_same
