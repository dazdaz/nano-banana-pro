#!/usr/bin/env python3
"""
nano-banana-pro - Generate images with Nano Banana Pro
Requires: API key saved via 01-apikey.sh

Usage:
    ./02-nanopro.py "A cyberpunk banana wearing sunglasses, 4K"
    ./02-nanopro.py "Turn this photo into a Studio Ghibli scene" image.jpg
    ./02-nanopro.py --edit "Add a crown" photo.png
    ./02-nanopro.py --list                 # Show recent generations
"""

import argparse
import base64
import os
import sys
from datetime import datetime
from pathlib import Path

try:
    import google.generativeai as genai
except ImportError:
    print("\033[0;31mError: google-generativeai not installed\033[0m")
    print("Install with: pip install google-generativeai")
    sys.exit(1)


class NanoBananaPro:
    """Nano Banana Pro image generator using Google's Generative AI."""
    
    def __init__(self):
        self.key_file = Path.home() / ".nano_banana_pro_key"
        self.output_dir = Path.home() / "nano_banana_pro_outputs"
        self.model_name = "gemini-3-pro-image-preview"
        
        # Create output directory if it doesn't exist
        self.output_dir.mkdir(exist_ok=True)
        
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
    
    def generate(self, prompt: str) -> Path:
        """
        Generate an image from a text prompt.
        
        Args:
            prompt: Text description of the image to generate
            
        Returns:
            Path to the saved image file
        """
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
            
            # Extract and decode image data
            img_data = response.candidates[0].content.parts[0].inline_data.data
            
            # Save image
            with open(output_path, 'wb') as f:
                f.write(base64.b64decode(img_data))
            
            print(f"\n\033[0;32mSaved → {output_path}\033[0m")
            self._suggest_preview(output_path)
            
            return output_path
            
        except Exception as e:
            print(f"\033[0;31mError generating image: {e}\033[0m")
            sys.exit(1)
    
    def edit_image(self, prompt: str, image_path: str) -> Path:
        """
        Edit an existing image using a text prompt.
        
        Args:
            prompt: Text description of the edit to make
            image_path: Path to the image file to edit
            
        Returns:
            Path to the saved edited image
        """
        image_file = Path(image_path)
        
        if not image_file.exists():
            print(f"\033[0;31mImage not found: {image_path}\033[0m")
            sys.exit(1)
        
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
            
            # Extract and decode image data
            img_data = response.candidates[0].content.parts[0].inline_data.data
            
            # Save edited image
            with open(output_path, 'wb') as f:
                f.write(base64.b64decode(img_data))
            
            print(f"\n\033[0;32mEdited → {output_path}\033[0m")
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
        
        print(f"\nOutput directory: {self.output_dir}")
    
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
  %(prog)s "A cyberpunk banana wearing sunglasses, 4K"
  %(prog)s --edit "Add a crown" photo.png
  %(prog)s --list
        """
    )
    
    parser.add_argument(
        'prompt',
        nargs='*',
        help='Text prompt for image generation'
    )
    
    parser.add_argument(
        '-e', '--edit',
        metavar='IMAGE',
        help='Edit an existing image (provide prompt and image path)'
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
    
    args = parser.parse_args()
    
    # Initialize the generator
    nano = NanoBananoPro()
    
    # Handle different operations
    if args.list:
        nano.list_recent(args.limit)
    
    elif args.edit:
        if len(args.prompt) < 1:
            print("\033[0;31mError: Edit mode requires a prompt and image path\033[0m")
            print(f"Usage: {sys.argv[0]} --edit IMAGE \"prompt\"")
            sys.exit(1)
        
        # First argument is the prompt, edit flag has the image path
        prompt = ' '.join(args.prompt)
        nano.edit_image(prompt, args.edit)
    
    elif args.prompt:
        # Generate from prompt
        prompt = ' '.join(args.prompt)
        nano.generate(prompt)
    
    else:
        parser.print_help()
        print("\n\033[1;33mTip:\033[0m Provide a prompt to generate an image")
        sys.exit(1)


if __name__ == '__main__':
    main()
