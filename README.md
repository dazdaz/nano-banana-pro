# Nano Banana Pro

A command-line toolkit for managing Google Cloud API keys and generating images using Google's Generative AI.

## Features

- **API Key Management** (`01-apikey.sh`) - Secure setup, audit, and removal of Google Cloud API keys
- **Image Generation** (`02-nanopro.py`) - Generate and edit images using AI with simple text prompts

## Prerequisites

- Google Cloud account with billing enabled
- `gcloud` CLI installed and configured
- Python 3.7+ (for image generation)
- `google-generativeai` Python package

## Installation

1. **Install gcloud CLI** (if not already installed):
   ```bash
   # macOS
   brew install google-cloud-sdk
   
   # Linux - see https://cloud.google.com/sdk/docs/install
   ```

2. **Install Python dependencies**:
   ```bash
   pip install google-generativeai
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

### 1. API Key Management (`01-apikey.sh`)

#### Setup - Create and save a new API key

```bash
./01-apikey.sh setup
```

This will:
- Let you select a Google Cloud project
- Check and enable billing if needed
- Enable required APIs (AI Platform, API Keys)
- Create a new API key
- Save it to `~/.nano_banana_pro_key`

#### Status - View current configuration

```bash
./01-apikey.sh status
```

Shows:
- Local key file path and content
- Project file path and ID

#### Audit - Verify key exists in cloud

```bash
./01-apikey.sh audit
```

Displays:
- Local key information
- All API keys in the cloud project
- Marks your local key as (ACTIVE) if found

#### Remove - Delete keys

```bash
./01-apikey.sh remove
```

Interactive menu to:
- Delete specific cloud keys
- Remove only local files (keep cloud keys)
- Cancel operation

#### Add - Manually add a key

```bash
./01-apikey.sh add "AIzaSy..."
```

Saves a manually-provided API key.

#### Project - Show current project ID

```bash
./01-apikey.sh project
```

### 2. Image Generation (`02-nanopro.py`)

#### Generate an image from text

```bash
./02-nanopro.py "A cyberpunk banana wearing sunglasses, 4K"
```

#### Edit an existing image

```bash
./02-nanopro.py --edit photo.png "Add a crown to the subject"
```

#### List recent generations

```bash
./02-nanopro.py --list
```

Show up to 20 recent images (customize with `-n`):
```bash
./02-nanopro.py --list -n 50
```

#### Get help

```bash
./02-nanopro.py --help
```

## File Locations

- **API Key**: `~/.nano_banana_pro_key`
- **Project ID**: `~/.nano_banana_pro_project`
- **Generated Images**: `~/nano_banana_pro_outputs/`

## Security

- API keys are stored in your home directory with `600` permissions (read/write for owner only)
- The `.gitignore` file prevents accidental commits of sensitive files
- Never share your API key or commit it to version control

## Examples

### Complete workflow

```bash
# 1. Set up API key
./01-apikey.sh setup

# 2. Verify setup
./01-apikey.sh audit

# 3. Generate an image
./02-nanopro.py "A serene mountain landscape at sunset, photorealistic"

# 4. Edit the generated image
./02-nanopro.py --edit ~/nano_banana_pro_outputs/nano_20251122_201500.png "Add a cabin in the foreground"

# 5. List all generations
./02-nanopro.py --list
```

### Generate various images

```bash
# Art styles
./02-nanopro.py "A cat in the style of Van Gogh's Starry Night"
./02-nanopro.py "Futuristic cityscape, cyberpunk aesthetic, neon lights"

# Photo editing
./02-nanopro.py --edit photo.jpg "Make it look like a Studio Ghibli scene"
./02-nanopro.py --edit portrait.png "Add dramatic lighting and remove background"

# Creative concepts
./02-nanopro.py "A steampunk robot playing chess, Victorian era, detailed mechanical parts"
```

## Troubleshooting

### "No API key found"
Run `./01-apikey.sh setup` to create and save a new API key.

### "Billing not enabled"
The setup script will attempt to link your project to a billing account automatically. If this fails, visit the [Google Cloud Console](https://console.cloud.google.com/billing) to enable billing manually.

### "google-generativeai not installed"
Install the required Python package:
```bash
pip install google-generativeai
```

### "Generation blocked"
The AI service may block certain prompts due to content policies. Try rephrasing your prompt to be more appropriate.

### Permission errors
Ensure scripts are executable:
```bash
chmod +x 01-apikey.sh 02-nanopro.py
```

## Architecture

### Key Manager (`01-apikey.sh`)
- Written in Bash for easy integration with `gcloud` CLI
- Handles project selection, billing checks, and API enablement
- Provides interactive menus for key management
- Stores keys securely in home directory

### Image Generator (`02-nanopro.py`)
- Written in Python for robust error handling and type safety
- Uses Google's `generativeai` library
- Reads API key from file created by key manager
- Object-oriented design for maintainability
- Supports both text-to-image and image-to-image generation

## API Usage and Costs

- Images are generated using Google's Gemini AI models
- Charges apply based on your Google Cloud billing account
- Monitor usage in the [Google Cloud Console](https://console.cloud.google.com)
- See [Google AI pricing](https://ai.google.dev/pricing) for current rates

## Contributing

Contributions are welcome! Please feel free to submit issues or pull requests.

## License

MIT License - feel free to use and modify as needed.

## Support

For issues related to:
- **Google Cloud setup**: Check [Google Cloud documentation](https://cloud.google.com/docs)
- **API usage**: See [Google AI documentation](https://ai.google.dev)
- **This toolkit**: Open an issue on GitHub
