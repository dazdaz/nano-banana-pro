#!/usr/bin/env python3
"""
nano-banana-pro - Generate images with Nano Banana Pro
Requires: API key saved via 01-apikey.sh

Usage:
    ./02-nanopro.py --generate "A cyberpunk banana wearing sunglasses, 4K"
    ./02-nanopro.py --edit photo.png "Add a crown"
    ./02-nanopro.py --list                 # Show recent generations
"""

import argparse
import base64
import io
import os
import sys
import warnings
from datetime import datetime
from pathlib import Path

# Suppress Python version warnings from google.api_core
warnings.filterwarnings('ignore', category=FutureWarning, module='google.api_core._python_version_support')

try:
    import google.generativeai as genai
except ImportError:
    print("\033[0;31mError: google-generativeai not installed\033[0m")
    print("Install with: pip install google-generativeai")
    sys.exit(1)

try:
    from PIL import Image
except ImportError:
    print("\033[0;31mError: Pillow not installed\033[0m")
    print("Install with: pip install Pillow")
    sys.exit(1)


class NanoBananoPro:
    """Nano Banana Pro image generator using Google's Generative AI."""
    
    def __init__(self):
        self.key_file = Path.home() / ".nano_banana_pro_key"
        self.output_dir = Path.cwd()  # Use current working directory
        self.model_name = "gemini-3-pro-image-preview"
        
        # Pricing estimates (USD) - subject to change, check Google AI pricing
        self.cost_per_image = 0.04  # Estimated cost per image generation
        
        # Load and configure API key
        self._load_api_key()
    
    def _load_api_key(self):
        """Load API key from file and configure the API."""
        if not self.key_file.exists():
            print("\033[0;31mNo API key found!\033[0m")
            print("Run: ./01-apikey.sh setup   (or)   ./01-apikey.sh add \"your-key\"")
            sys.exit(1)
        
        with open(self.key_file, 'r') as f:
            api_key = f.read().strip()
        
        if not api_key:
            print("\033[0;31mAPI key file is empty!\033[0m")
            sys.exit(1)
        
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel(self.model_name)
    
    def generate(self, prompt: str, output_filename: str = None) -> Path:
        """
        Generate an image from a text prompt.
        
        Args:
            prompt: Text description of the image to generate
            output_filename: Optional custom filename for the output
            
        Returns:
            Path to the saved image file
        """
        if output_filename:
            output_path = self.output_dir / output_filename
            # Ensure .png extension
            if not output_path.suffix:
                output_path = output_path.with_suffix('.png')
        else:
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            output_path = self.output_dir / f"nano_{timestamp}.png"
        
        print("\033[1;33mGenerating with Nano Banana Pro...\033[0m")
        print(f"Prompt: \033[0;32m{prompt}\033[0m\n")
        
        try:
            response = self.model.generate_content(prompt)
            
            # Check if generation was blocked
            if not response.candidates:
                print("\033[0;31mError: Generation blocked\033[0m")
                print(f"Reason: {response.prompt_feedback}")
                sys.exit(1)
            
            # Extract image data
            img_data = response.candidates[0].content.parts[0].inline_data.data
            
            # Save image in the appropriate format
            self._save_image(img_data, output_path)
            
            print(f"\n\033[0;32mSaved → {output_path}\033[0m")
            print(f"\033[0;36mEstimated cost: ${self.cost_per_image:.4f} USD\033[0m")
            self._suggest_preview(output_path)
            
            return output_path
            
        except Exception as e:
            print(f"\033[0;31mError generating image: {e}\033[0m")
            sys.exit(1)
    
    def edit_image(self, prompt: str, image_path: str, output_filename: str = None) -> Path:
        """
        Edit an existing image using a text prompt.
        
        Args:
            prompt: Text description of the edit to make
            image_path: Path to the image file to edit
            output_filename: Optional custom filename for the output
            
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
        print(f"Prompt: \033[0;32m{prompt}\033[0m\n")
        
        try:
            # Read image file
            with open(image_file, 'rb') as f:
                image_bytes = f.read()
            
            # Determine MIME type based on file extension
            mime_types = {
                '.png': 'image/png',
                '.jpg': 'image/jpeg',
                '.jpeg': 'image/jpeg',
                '.webp': 'image/webp',
                '.gif': 'image/gif'
            }
            
            mime_type = mime_types.get(image_file.suffix.lower(), 'image/png')
            
            # Create image part using the types module
            from google.generativeai.types import Part
            image_part = Part.from_bytes(data=image_bytes, mime_type=mime_type)
            
            # Generate edited image
            response = self.model.generate_content([image_part, prompt])
            
            # Check if generation was blocked
            if not response.candidates:
                print("\033[0;31mError: Generation blocked\033[0m")
                print(f"Reason: {response.prompt_feedback}")
                sys.exit(1)
            
            # Extract image data
            img_data = response.candidates[0].content.parts[0].inline_data.data
            
            # Save edited image in the appropriate format
            self._save_image(img_data, output_path)
            
            print(f"\n\033[0;32mEdited → {output_path}\033[0m")
            print(f"\033[0;36mEstimated cost: ${self.cost_per_image:.4f} USD\033[0m")
            self._suggest_preview(output_path)
            
            return output_path
            
        except Exception as e:
            print(f"\033[0;31mError editing image: {e}\033[0m")
            sys.exit(1)
    
    def list_recent(self, limit: int = 20):
        """
        List recent image generations.
        
        Args:
            limit: Maximum number of files to display
        """
        print("\033[1;34mRecent Nano Banana Pro generations:\033[0m\n")
        
        # Get all image files sorted by modification time
        image_files = sorted(
            self.output_dir.glob("nano_*.png"),
            key=lambda p: p.stat().st_mtime,
            reverse=True
        )
        
        if not image_files:
            print("No generations found.")
            return
        
        # Display up to 'limit' files
        for i, file_path in enumerate(image_files[:limit], 1):
            stat = file_path.stat()
            size_kb = stat.st_size / 1024
            mtime = datetime.fromtimestamp(stat.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
            
            print(f"{i:2d}. {file_path.name:<40} {size_kb:>8.1f} KB  {mtime}")
        
        total = len(image_files)
        if total > limit:
            print(f"\n... and {total - limit} more files")
        
        # Calculate estimated total cost
        total_cost = total * self.cost_per_image
        
        print(f"\nOutput directory: {self.output_dir}")
        print(f"Total images: {total}")
        print(f"\033[0;36mEstimated total cost: ${total_cost:.2f} USD (${self.cost_per_image:.4f} per image)\033[0m")
    
    def _save_image(self, img_data_base64: str, output_path: Path):
        """
        Save image data to file in the appropriate format.
        
        Args:
            img_data_base64: Base64-encoded image data
            output_path: Path where to save the image
        """
        # Decode the base64 image data
        img_bytes = base64.b64decode(img_data_base64)
        
        # Load image with PIL
        img = Image.open(io.BytesIO(img_bytes))
        
        # Determine output format based on extension
        output_ext = output_path.suffix.lower()
        
        if output_ext in ['.jpg', '.jpeg']:
            # Convert RGBA to RGB for JPEG
            if img.mode in ('RGBA', 'LA', 'P'):
                # Create white background
                background = Image.new('RGB', img.size, (255, 255, 255))
                if img.mode == 'P':
                    img = img.convert('RGBA')
                if img.mode in ('RGBA', 'LA'):
                    background.paste(img, mask=img.split()[-1])  # Use alpha channel as mask
                img = background
            img.save(output_path, 'JPEG', quality=95)
        elif output_ext == '.png':
            img.save(output_path, 'PNG')
        else:
            # Default to PNG for unknown extensions
            img.save(output_path, 'PNG')
    
    def _suggest_preview(self, file_path: Path):
        """Suggest commands to preview the generated image."""
        print(f"Preview (macOS): open \"{file_path}\"")
        print(f"Preview (Linux): xdg-open \"{file_path}\"")


def main():
    """Main entry point for the CLI."""
    parser = argparse.ArgumentParser(
        description="Generate images with Nano Banana Pro",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  %(prog)s --generate "A cyberpunk banana wearing sunglasses, 4K"
  %(prog)s --edit photo.png "Add a crown"
  %(prog)s --list
        """
    )
    
    parser.add_argument(
        '-g', '--generate',
        metavar='PROMPT',
        help='Generate an image from a text prompt'
    )
    
    parser.add_argument(
        '-e', '--edit',
        nargs=2,
        metavar=('IMAGE', 'PROMPT'),
        help='Edit an existing image (provide image path and prompt)'
    )
    
    parser.add_argument(
        '-l', '--list',
        action='store_true',
        help='List recent image generations'
    )
    
    parser.add_argument(
        '-n', '--limit',
        type=int,
        default=20,
        help='Number of recent files to show (default: 20)'
    )
    
    parser.add_argument(
        '-o', '--output',
        metavar='FILENAME',
        help='Optional output filename (default: auto-generated with timestamp)'
    )
    
    args = parser.parse_args()
    
    # Initialize the generator
    nano = NanoBananoPro()
    
    # Handle different operations
    if args.list:
        nano.list_recent(args.limit)
    
    elif args.generate:
        # Generate from prompt
        nano.generate(args.generate, args.output)
    
    elif args.edit:
        # Edit image: args.edit is a list [image_path, prompt]
        image_path, prompt = args.edit
        nano.edit_image(prompt, image_path, args.output)
    
    else:
        parser.print_help()
        print("\n\033[1;33mTip:\033[0m Use --generate to create an image or --edit to modify one")
        sys.exit(1)


if __name__ == '__main__':
    main()
