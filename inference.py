import os

import torch
import numpy as np
from PIL import Image
from transformers import AutoModel, AutoImageProcessor, ViTImageProcessor, AutoConfig
from torchvision import transforms
from sklearn.metrics.pairwise import cosine_similarity

class FaceAnalysis:
    def __init__(self, model_name=None):
        # Default model - try the original, fallback to a working alternative
        self.model_name = model_name or "biometric-ai-lab/Face_Recognition"
        self.device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
        
        # Alternative models that are known to work
        alternative_models = [
            "google/vit-base-patch16-224",  # ViT model that can be fine-tuned for face recognition
            "microsoft/swin-base-patch4-window7-224",  # Swin Transformer
        ]
        
        # Try to load image processor, fallback to ViTImageProcessor if not available
        processor_loaded = False
        try:
            self.processor = AutoImageProcessor.from_pretrained(self.model_name)
            self.use_processor = True
            processor_loaded = True
        except (OSError, ValueError) as e:
            print(f"⚠️  Warning: Could not load image processor for {self.model_name}: {e}")
            print("   Trying ViTImageProcessor as fallback...")
            try:
                # Try ViTImageProcessor as fallback
                self.processor = ViTImageProcessor.from_pretrained(self.model_name)
                self.use_processor = True
                processor_loaded = True
            except Exception:
                # If that also fails, use manual preprocessing
                print("   Using manual image preprocessing...")
                self.processor = None
                self.use_processor = False
                processor_loaded = True  # Manual preprocessing is ready
                # Standard ImageNet normalization for most vision models
                self.transform = transforms.Compose([
                    transforms.Resize((224, 224)),
                    transforms.ToTensor(),
                    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
                ])
        
        # Load model - try with trust_remote_code for custom architectures
        model_loaded = False
        try:
            # First try loading config with trust_remote_code
            config = AutoConfig.from_pretrained(self.model_name, trust_remote_code=True)
            self.model = AutoModel.from_pretrained(self.model_name, config=config, trust_remote_code=True)
            model_loaded = True
        except Exception as e:
            print(f"⚠️  Warning: Could not load model '{self.model_name}' with trust_remote_code")
            print(f"   Error: {str(e)[:200]}...")
            
            # Try without trust_remote_code
            try:
                self.model = AutoModel.from_pretrained(self.model_name)
                model_loaded = True
            except Exception as e2:
                print(f"⚠️  Could not load model without trust_remote_code either")
                print(f"   Trying alternative models...")
                
                # Try alternative models
                for alt_model in alternative_models:
                    try:
                        print(f"   Trying {alt_model}...")
                        self.model_name = alt_model
                        # Set up processor for alternative model
                        if not processor_loaded:
                            try:
                                self.processor = AutoImageProcessor.from_pretrained(alt_model)
                                self.use_processor = True
                            except:
                                self.processor = ViTImageProcessor.from_pretrained(alt_model)
                                self.use_processor = True
                        
                        self.model = AutoModel.from_pretrained(alt_model)
                        model_loaded = True
                        print(f"✅ Successfully loaded alternative model: {alt_model}")
                        print(f"   Note: This model may need fine-tuning for optimal face recognition performance.")
                        break
                    except Exception as alt_e:
                        continue
                
                if not model_loaded:
                    raise ValueError(
                        f"Could not load model '{self.model_name}' or any alternatives.\n"
                        f"Original error: {str(e2)[:300]}\n\n"
                        f"Possible solutions:\n"
                        f"1. Check if the model name is correct: https://huggingface.co/{self.model_name}\n"
                        f"2. The model may require custom code files that aren't available\n"
                        f"3. Try using a different face recognition model"
                    ) from e2
        
        self.model.to(self.device)
        self.model.eval()
        print(f"✅ Model loaded successfully: {self.model_name}")

    def _get_embedding(self, image_path):
        if not os.path.exists(image_path):
            raise FileNotFoundError(f"Image not found: {image_path}")

        try:
            image = Image.open(image_path).convert("RGB")
        except Exception as exc:
            raise ValueError(f"Could not load image {image_path}: {exc}") from exc

        # Process image based on available processor
        if self.use_processor:
            inputs = self.processor(images=image, return_tensors="pt")
            inputs = {k: v.to(self.device) for k, v in inputs.items()}
        else:
            # Manual preprocessing
            image_tensor = self.transform(image).unsqueeze(0)
            inputs = {"pixel_values": image_tensor.to(self.device)}

        with torch.no_grad():
            outputs = self.model(**inputs)

        # Extract embedding
        embedding = getattr(outputs, "pooler_output", None)
        if embedding is None:
            # Try to get embeddings from last_hidden_state
            if hasattr(outputs, "last_hidden_state"):
                embedding = outputs.last_hidden_state.mean(dim=1)
            elif hasattr(outputs, "embeddings"):
                embedding = outputs.embeddings
            else:
                # Fallback: use the first output if it's a tensor
                outputs_dict = outputs.to_tuple() if hasattr(outputs, "to_tuple") else {}
                if outputs_dict and isinstance(outputs_dict[0], torch.Tensor):
                    embedding = outputs_dict[0].mean(dim=1) if len(outputs_dict[0].shape) > 2 else outputs_dict[0]
                else:
                    raise ValueError("Could not extract embeddings from model output")

        embedding = torch.nn.functional.normalize(embedding, p=2, dim=1)
        return embedding.detach().cpu().numpy()

    def compare(self, img1_path, img2_path, threshold=0.75):
        emb1 = self._get_embedding(img1_path)
        emb2 = self._get_embedding(img2_path)

        similarity = cosine_similarity(emb1, emb2)[0][0]
        is_same = similarity > threshold

        return similarity, is_same
