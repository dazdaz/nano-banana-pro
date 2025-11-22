#!/usr/bin/env python3
"""
nano-banana-pro - Generate images with Vertex AI Imagen

Usage:
    ./02-nanopro.py --prompt "A cyberpunk banana wearing sunglasses, 4K"
    ./02-nanopro.py --prompt "sunset" --aspect-ratio 16:9 --num-images 4
    ./02-nanopro.py --prompt "cat" --negative-prompt "dog" --seed 12345
    ./02-nanopro.py --edit photo.png "Add a crown"
"""

import argparse
import sys
import time
import warnings
from datetime import datetime
from pathlib import Path

# Suppress Python version warnings from google.api_core
warnings.filterwarnings('ignore', category=FutureWarning, module='google.api_core._python_version_support')
# Suppress deprecation warnings from Vertex AI
warnings.filterwarnings('ignore', category=UserWarning, module='vertexai._model_garden._model_garden_models')

try:
    from vertexai.preview.vision_models import ImageGenerationModel
    import vertexai
except ImportError:
    print("\033[0;31mError: google-cloud-aiplatform not installed\033[0m")
    print("Install with: pip install google-cloud-aiplatform")
    sys.exit(1)


class NanoBananoPro:
    """Nano Banana Pro image generator using Google's Vertex AI Imagen."""
    
    def __init__(self):
        self.key_file = Path.home() / ".nano_banana_pro_key"
        self.project_file = Path.home() / ".nano_banana_pro_project"
        self.output_dir = Path.cwd()  # Use current working directory
        
        # Pricing estimates (USD) - subject to change, check Google AI pricing
        self.cost_per_image = 0.04  # Estimated cost per image generation
        
        # Load project and initialize Vertex AI
        self._load_config()
    
    def _load_config(self):
        """Load project configuration and initialize Vertex AI."""
        if not self.project_file.exists():
            print("\033[0;31mNo project configuration found!\033[0m")
            print("Run: ./01-apikey.sh setup")
            sys.exit(1)
        
        with open(self.project_file, 'r') as f:
            project_id = f.read().strip()
        
        if not project_id:
            print("\033[0;31mProject file is empty!\033[0m")
            sys.exit(1)
        
        # Initialize Vertex AI
        vertexai.init(project=project_id, location="us-central1")
        self.model = ImageGenerationModel.from_pretrained("imagegeneration@006")
    
    def generate(self, prompt: str, output_filename: str = None, aspect_ratio: str = "1:1",
                 num_images: int = 1, negative_prompt: str = None, seed: int = None,
                 guidance_scale: float = None) -> list:
        """
        Generate images from a text prompt.
        
        Args:
            prompt: Text description of the image to generate
            output_filename: Optional custom filename for the output
            aspect_ratio: Image aspect ratio (1:1, 9:16, 16:9, 4:3, 3:4)
            num_images: Number of images to generate (1-8)
            negative_prompt: Text describing what to avoid in the image
            seed: Random seed for reproducible generation
            guidance_scale: Guidance scale for prompt adherence
            
        Returns:
            List of paths to the saved image files
        """
        print("\033[1;33mGenerating image(s) with Nano Banana Pro...\033[0m")
        print(f"Prompt: \033[0;32m{prompt}\033[0m")
        if negative_prompt:
            print(f"Negative prompt: \033[0;31m{negative_prompt}\033[0m")
        print(f"Aspect ratio: {aspect_ratio} | Images: {num_images}")
        if seed is not None:
            print(f"Seed: {seed}")
        print()
        
        try:
            # Start timing
            start_time = time.time()
            
            # Prepare generation parameters
            gen_params = {
                'prompt': prompt,
                'number_of_images': num_images,
                'language': 'en',
                'aspect_ratio': aspect_ratio,
            }
            
            if negative_prompt:
                gen_params['negative_prompt'] = negative_prompt
            if seed is not None:
                gen_params['seed'] = seed
            if guidance_scale is not None:
                gen_params['guidance_scale'] = guidance_scale
            
            # Generate images using Vertex AI Imagen
            images = self.model.generate_images(**gen_params)
            
            # Save all generated images
            saved_paths = []
            for i, image in enumerate(images):
                if output_filename and num_images == 1:
                    output_path = self.output_dir / output_filename
                    if not output_path.suffix:
                        output_path = output_path.with_suffix('.jpg')
                else:
                    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
                    suffix = f"_{i+1}" if num_images > 1 else ""
                    output_path = self.output_dir / f"nano_{timestamp}{suffix}.jpg"
                
                image.save(location=str(output_path), include_generation_parameters=False)
                saved_paths.append(output_path)
            
            # End timing
            end_time = time.time()
            elapsed_time = end_time - start_time
            
            # Display results
            print(f"\n\033[0;32m{'✓' if num_images == 1 else '✓ All images saved'}\033[0m")
            for path in saved_paths:
                print(f"  → {path}")
            print(f"\033[0;35mGeneration time: {elapsed_time:.2f} seconds ({elapsed_time/num_images:.2f}s per image)\033[0m")
            
            total_cost = self.cost_per_image * num_images
            print(f"\033[0;36mEstimated cost: ${total_cost:.4f} USD\033[0m")
            
            if num_images == 1:
                self._suggest_preview(saved_paths[0])
            
            return saved_paths
            
        except Exception as e:
            print(f"\033[0;31mError generating image: {e}\033[0m")
            import traceback
            traceback.print_exc()
            sys.exit(1)
    
    def edit_image(self, prompt: str, image_path: str, output_filename: str = None,
                   negative_prompt: str = None, seed: int = None) -> Path:
        """
        Edit an existing image using a text prompt.
        
        Args:
            prompt: Text description of the edit to make
            image_path: Path to the image file to edit
            output_filename: Optional custom filename for the output
            negative_prompt: Text describing what to avoid in the edit
            seed: Random seed for reproducible generation
            
        Returns:
            Path to the saved edited image
        """
        image_file = Path(image_path)
        
        if not image_file.exists():
            print(f"\033[0;31mImage not found: {image_path}\033[0m")
            sys.exit(1)
        
        if output_filename:
            output_path = self.output_dir / output_filename
            # Ensure .png extension
            if not output_path.suffix:
                output_path = output_path.with_suffix('.png')
        else:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = self.output_dir / f"nano_edited_{timestamp}.png"
        
        print("\033[1;33mEditing image with Nano Banana Pro...\033[0m")
        print(f"Image: \033[0;36m{image_path}\033[0m")
        print(f"Prompt: \033[0;32m{prompt}\033[0m")
        if negative_prompt:
            print(f"Negative prompt: \033[0;31m{negative_prompt}\033[0m")
        if seed is not None:
            print(f"Seed: {seed}")
        print()
        
        try:
            # Start timing
            start_time = time.time()
            
            # Read image file
            with open(image_file, 'rb') as f:
                image_bytes = f.read()
            
            # Create Vertex AI Image object
            from vertexai.preview.vision_models import Image as VertexImage
            vertex_image = VertexImage(image_bytes=image_bytes)
            
            # Prepare edit parameters
            edit_params = {
                'prompt': prompt,
                'base_image': vertex_image,
                'number_of_images': 1,
            }
            
            if negative_prompt:
                edit_params['negative_prompt'] = negative_prompt
            if seed is not None:
                edit_params['seed'] = seed
            
            # Edit image using Vertex AI Imagen
            edited_images = self.model.edit_image(**edit_params)
            
            # Save the edited image
            edited_images[0].save(location=str(output_path), include_generation_parameters=False)
            
            # End timing
            end_time = time.time()
            elapsed_time = end_time - start_time
            
            print(f"\n\033[0;32m✓ Edited → {output_path}\033[0m")
            print(f"\033[0;35mGeneration time: {elapsed_time:.2f} seconds\033[0m")
            print(f"\033[0;36mEstimated cost: ${self.cost_per_image:.4f} USD\033[0m")
            self._suggest_preview(output_path)
            
            return output_path
            
        except Exception as e:
            print(f"\033[0;31mError editing image: {e}\033[0m")
            sys.exit(1)
    
    def _suggest_preview(self, file_path: Path):
        """Suggest commands to preview the generated image."""
        print(f"Preview (macOS): open \"{file_path}\"")
        print(f"Preview (Linux): xdg-open \"{file_path}\"")


def main():
    """Main entry point for the CLI."""
    parser = argparse.ArgumentParser(
        description="Generate images with Vertex AI Imagen",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  Basic generation:
    %(prog)s --prompt "A cyberpunk banana wearing sunglasses, 4K"
  
  With aspect ratio and multiple images:
    %(prog)s --prompt "sunset over mountains" --aspect-ratio 16:9 --num-images 4
  
  With negative prompt and seed:
    %(prog)s --prompt "cat playing" --negative-prompt "dog" --seed 12345
  
  Edit an image:
    %(prog)s --edit photo.png "Add a crown"
  
  Save to specific directory:
    %(prog)s --prompt "ocean waves" --output-dir ./images
        """
    )
    
    parser.add_argument(
        '-p', '--prompt',
        metavar='TEXT',
        help='Generate an image from a text prompt'
    )
    
    parser.add_argument(
        '-e', '--edit',
        nargs=2,
        metavar=('IMAGE', 'PROMPT'),
        help='Edit an existing image (provide image path and prompt)'
    )
    
    parser.add_argument(
        '-o', '--output',
        metavar='FILENAME',
        help='Optional output filename (default: auto-generated with timestamp)'
    )
    
    parser.add_argument(
        '-ar', '--aspect-ratio',
        choices=['1:1', '9:16', '16:9', '4:3', '3:4'],
        default='1:1',
        help='Aspect ratio for generated images (default: 1:1)'
    )
    
    parser.add_argument(
        '-n', '--num-images',
        type=int,
        default=1,
        choices=range(1, 9),
        metavar='N',
        help='Number of images to generate (1-8, default: 1)'
    )
    
    parser.add_argument(
        '-np', '--negative-prompt',
        metavar='TEXT',
        help='Negative prompt - specify what to avoid in the image'
    )
    
    parser.add_argument(
        '-s', '--seed',
        type=int,
        metavar='SEED',
        help='Random seed for reproducible generation'
    )
    
    parser.add_argument(
        '-g', '--guidance',
        type=float,
        metavar='SCALE',
        help='Guidance scale for prompt adherence (higher = stricter, default: auto)'
    )
    
    parser.add_argument(
        '--output-dir',
        metavar='DIR',
        help='Output directory for generated images (default: current directory)'
    )
    
    args = parser.parse_args()
    
    # Initialize the generator
    nano = NanoBananoPro()
    
    # Set output directory if specified
    if args.output_dir:
        output_dir = Path(args.output_dir)
        output_dir.mkdir(parents=True, exist_ok=True)
        nano.output_dir = output_dir
    
    # Handle different operations
    if args.prompt:
        # Generate from prompt
        nano.generate(
            prompt=args.prompt,
            output_filename=args.output,
            aspect_ratio=args.aspect_ratio,
            num_images=args.num_images,
            negative_prompt=args.negative_prompt,
            seed=args.seed,
            guidance_scale=args.guidance
        )
    
    elif args.edit:
        # Edit image: args.edit is a list [image_path, prompt]
        image_path, prompt = args.edit
        nano.edit_image(
            prompt=prompt,
            image_path=image_path,
            output_filename=args.output,
            negative_prompt=args.negative_prompt,
            seed=args.seed
        )
    
    else:
        parser.print_help()
        print("\n\033[1;33mTip:\033[0m Use --prompt to create an image or --edit to modify one")
        sys.exit(1)


if __name__ == '__main__':
    main()
