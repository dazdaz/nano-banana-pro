# Nano Banana Pro

A command-line toolkit for **Google's Nano Banana Pro** - an advanced image generation and manipulation model powered by Vertex AI Imagen.

This toolkit provides an easy-to-use interface for leveraging Google's state-of-the-art AI image generation capabilities through simple command-line tools.

## What is Nano Banana Pro?

Nano Banana Pro is Google's advanced image generation model available through Vertex AI and other platforms. It offers:
- **Text-to-Image Generation** - Create images from text descriptions
- **Image Editing** - Modify existing images with AI-powered edits
- **Multiple Aspect Ratios** - Generate images in various formats (1:1, 16:9, 9:16, 4:3, 3:4)
- **Batch Generation** - Create multiple image variations at once
- **Reproducible Results** - Use seeds for consistent outputs
- **Negative Prompts** - Specify what to avoid in generations

<img width="2016" height="1134" alt="nano_20251122_210014_3" src="https://github.com/user-attachments/assets/500a34f0-84e4-4d4a-9bca-b3cc7bf95a70" />

## Features

- **Project Setup** (`01-apikey.sh`) - Configure Google Cloud project with Vertex AI access
- **Image Generation** (`02-nanopro.py`) - Full-featured CLI for Google's Nano Banana Pro model with advanced controls

## Prerequisites

- Google Cloud account with billing enabled
- `gcloud` CLI installed and configured
- Python 3.10+ (for image generation)
- `google-cloud-aiplatform` Python package

## Installation

1. **Install gcloud CLI** (if not already installed):
   ```bash
   # macOS
   brew install google-cloud-sdk
   
   # Linux - see https://cloud.google.com/sdk/docs/install
   ```

2. **Install Python dependencies**:
   ```bash
   pip install google-cloud-aiplatform Pillow
   ```

3. **Clone or download this repository**:
   ```bash
   git clone https://github.com/yourusername/nano-banana-pro.git
   cd nano-banana-pro
   ```

4. **Make scripts executable**:
   ```bash
   chmod +x 01-apikey.sh 02-nanopro.py
   ```

## Usage

### 1. Project Setup (`01-apikey.sh`)

#### setup - Configure Google Cloud project

```bash
./01-apikey.sh setup [PROJECT_ID]
```

This will:
- Let you select a Google Cloud project (or use the optional PROJECT_ID argument)
- Check and enable billing if needed
- Enable required APIs (Vertex AI)
- Save project configuration to `~/.nano_banana_pro_project`

#### status - View current configuration

```bash
./01-apikey.sh status
```

Shows:
- Project file path and ID
- Current configuration status

#### project - Show current project ID

```bash
./01-apikey.sh project
```

Displays the currently configured Google Cloud project ID.

### 2. Image Generation (`02-nanopro.py`)

#### Basic Commands

**Generate an image from text:**
```bash
./02-nanopro.py --prompt "A cyberpunk banana wearing sunglasses, 4K"
```

**Edit an existing image:**
```bash
./02-nanopro.py --edit photo.png "Add a crown to the subject"
```

**Get help:**
```bash
./02-nanopro.py --help
```

#### Advanced Options

**`-s, --seed` - Random Seed (Reproducibility)**

The seed option allows you to generate the **exact same image** multiple times. This is crucial for:
- **A/B Testing**: Compare different prompts with the same random seed to see only the effect of your prompt changes
- **Consistency**: Generate variations of the same base image by keeping the seed constant
- **Debugging**: Reproduce exact results when testing or troubleshooting
- **Version Control**: Document and recreate specific images later

Example use cases:
```bash
# Generate an image with a specific seed
./02-nanopro.py --prompt "mountain landscape" --seed 12345

# Generate again with the same seed = identical image
./02-nanopro.py --prompt "mountain landscape" --seed 12345

# Change only the prompt to see the effect
./02-nanopro.py --prompt "mountain landscape at sunset" --seed 12345

# Same seed, different aspect ratio = consistent style
./02-nanopro.py --prompt "mountain landscape" --seed 12345 --aspect-ratio 16:9
```

**`-g, --guidance` - Guidance Scale (Prompt Adherence)**

Controls how strictly the AI follows your prompt. Higher values = more literal interpretation.

- **Low values (1-50)**: More creative freedom, artistic interpretation
- **Medium values (50-100)**: Balanced between creativity and accuracy
- **High values (100-200)**: Very strict adherence to prompt, less creative variation

Examples:
```bash
# Low guidance - creative, artistic interpretation
./02-nanopro.py --prompt "futuristic city" --guidance 30

# Medium guidance - balanced (similar to default)
./02-nanopro.py --prompt "futuristic city" --guidance 75

# High guidance - very literal interpretation
./02-nanopro.py --prompt "futuristic city" --guidance 150

# Combine with seed to compare guidance levels
./02-nanopro.py --prompt "sunset" --seed 999 --guidance 50
./02-nanopro.py --prompt "sunset" --seed 999 --guidance 150
```

## File Locations

- **Project ID**: `~/.nano_banana_pro_project`
- **Generated Images**: Current working directory (where you run the script)

## Security

- Project configuration is stored in your home directory with `600` permissions (read/write for owner only)
- Uses Google Cloud's Application Default Credentials (ADC) for authentication
- The `.gitignore` file prevents accidental commits of sensitive files
- Vertex AI uses your Google Cloud project's IAM permissions for access control

## Examples

### Complete workflow

```bash
# 1. Create a Google Cloud API Key
./01-apikey.sh setup

# 2. Verify Key setup
./01-apikey.sh status

# 3. Generate an image
./02-nanopro.py --prompt "A serene mountain landscape at sunset, photorealistic"

# 4. Edit the generated image
./02-nanopro.py --edit nano_20251122_201500.jpg "Add a cabin in the foreground"
```

### Generate various images

```bash
# Art styles
./02-nanopro.py --prompt "A cat in the style of Van Gogh's Starry Night"
./02-nanopro.py --prompt "Futuristic cityscape, cyberpunk aesthetic, neon lights"

# Photo editing
./02-nanopro.py --edit photo.jpg "Make it look like a Studio Ghibli scene"
./02-nanopro.py --edit portrait.png "Add dramatic lighting and remove background"

# Creative concepts
./02-nanopro.py --prompt "A steampunk robot playing chess, Victorian era, detailed mechanical parts"
```

## Troubleshooting

### "No project configuration found"
Run `./01-apikey.sh setup` to configure your Google Cloud project.

### "Billing not enabled"
The setup script will attempt to link your project to a billing account automatically. If this fails, visit the [Google Cloud Console](https://console.cloud.google.com/billing) to enable billing manually.

### "google-cloud-aiplatform not installed"
Install the required Python package:
```bash
pip install google-cloud-aiplatform Pillow
```

### "Generation blocked"
The AI service may block certain prompts due to content policies. Try rephrasing your prompt to be more appropriate.

### Permission errors
Ensure scripts are executable:
```bash
chmod +x 01-apikey.sh 02-nanopro.py
```

## Architecture

### Project Setup (`01-apikey.sh`)
- Written in Bash for easy integration with `gcloud` CLI
- Handles project selection, billing checks, and API enablement
- Configures Vertex AI access for the project
- Stores project configuration securely in home directory

### Image Generator (`02-nanopro.py`)
- Written in Python for robust error handling and type safety
- Uses Google's Vertex AI SDK (`google-cloud-aiplatform`)
- Leverages Vertex AI Imagen for enterprise-grade image generation
- Object-oriented design for maintainability
- Supports both text-to-image and image editing operations
- Displays generation time for performance tracking

## API Usage and Costs

- Images are generated using Google's **Vertex AI Imagen** models
- This is an enterprise AI platform with usage-based billing
- Charges apply based on your Google Cloud billing account
- Monitor usage in the [Google Cloud Console](https://console.cloud.google.com)
- See [Vertex AI pricing](https://cloud.google.com/vertex-ai/pricing) for current rates
- Estimated cost: ~$0.04 USD per image generation (subject to change)

## Blogs

* https://cloud.google.com/blog/products/ai-machine-learning/nano-banana-pro-available-for-enterprise
* https://x.com/GoogleAIStudio/status/1992267030050083091

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - feel free to use and modify as needed.

## Support

For issues related to:
- **Google Cloud setup**: Check [Google Cloud documentation](https://cloud.google.com/docs)
- **API usage**: See [Google AI documentation](https://ai.google.dev)
- **This toolkit**: Open an issue on GitHub
