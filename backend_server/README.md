# Outfit Assistant Backend Server

A production-ready FastAPI backend server for integrating Google's Nano Banana image editing model via fal.ai.

## Features

- 🚀 FastAPI-based REST API
- 🎨 Nano Banana image editing integration via fal.ai
- 🔒 Environment-based configuration
- 📝 Comprehensive error handling and logging
- 🌐 CORS support for mobile applications
- ✅ Input validation and type safety
- 📊 Health check endpoints

## Prerequisites

- Python 3.8 or higher
- fal.ai API key ([Get one here](https://fal.ai/dashboard))

## Installation

1. **Clone the repository** (if applicable) or navigate to the project directory:
   ```bash
   cd backend_server
   ```

2. **Create a virtual environment** (recommended):
   ```bash
   python -m venv venv
   
   # On Windows
   venv\Scripts\activate
   
   # On macOS/Linux
   source venv/bin/activate
   ```

3. **Install dependencies**:
   ```bash
   pip install -r requirements.txt
   ```

4. **Set up environment variables**:
   ```bash
   # Copy the example environment file
   cp .env.example .env
   
   # Edit .env and add your fal.ai API key
   # FAL_KEY=your_actual_api_key_here
   ```

## Configuration

The server can be configured via environment variables or a `.env` file:

- `FAL_KEY`: Your fal.ai API key (required)
- `HOST`: Server host (default: `0.0.0.0`)
- `PORT`: Server port (default: `8000`)
- `DEBUG`: Debug mode (default: `False`)
- `LOG_LEVEL`: Logging level (default: `INFO`)
- `CORS_ORIGINS`: Comma-separated list of allowed origins

## Running the Server

### Development Mode

```bash
python -m app.main
```

Or using uvicorn directly:

```bash
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

### Production Mode

```bash
uvicorn app.main:app --host 0.0.0.0 --port 8000 --workers 4
```

The server will be available at `http://localhost:8000`

## API Documentation

Once the server is running, you can access:

- **Interactive API Docs (Swagger UI)**: `http://localhost:8000/docs`
- **Alternative API Docs (ReDoc)**: `http://localhost:8000/redoc`

## API Endpoints

### 1. Health Check

```http
GET /health
```

**Response:**
```json
{
  "status": "healthy"
}
```

### 2. Check Nano Banana Status

```http
GET /api/v1/nano-banana/status
```

**Response:**
```json
{
  "status": "configured",
  "message": "Service is ready"
}
```

### 3. Edit Images with Nano Banana

```http
POST /api/v1/nano-banana/edit
Content-Type: application/json

{
  "user_image_url": "https://example.com/user.png",
  "clothing_image_url": "https://example.com/outfit.png",
  "style_prompt": "Add a leather belt and gold jewelry",
  "with_logs": true
}
```

**Response:**
```json
{
  "success": true,
  "result": {
    // fal.ai response data
  },
  "message": "Images edited successfully"
}
```

## Integration Steps for Mobile Application

### 1. Set Up Backend Server

Follow the installation steps above to set up and run the backend server.

### 2. Configure CORS

Update the `CORS_ORIGINS` in your `.env` file to include your mobile app's domain or use `*` for development (not recommended for production).

### 3. Make API Calls from Mobile App

#### Example using Flutter/Dart:

```dart
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<Map<String, dynamic>> editImages({
  required String userImageUrl,
  required String clothingImageUrl,
  String? stylePrompt,
}) async {
  final url = Uri.parse('http://your-server:8000/api/v1/nano-banana/edit');
  
  final response = await http.post(
    url,
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'user_image_url': userImageUrl,
      'clothing_image_url': clothingImageUrl,
      if (stylePrompt != null) 'style_prompt': stylePrompt,
      'with_logs': true,
    }),
  );
  
  if (response.statusCode == 200) {
    return jsonDecode(response.body);
  } else {
    throw Exception('Failed to edit images: ${response.body}');
  }
}
```

#### Example using React Native/JavaScript:

```javascript
const editImages = async ({ userImageUrl, clothingImageUrl, stylePrompt }) => {
  const response = await fetch('http://your-server:8000/api/v1/nano-banana/edit', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      user_image_url: userImageUrl,
      clothing_image_url: clothingImageUrl,
      ...(stylePrompt ? { style_prompt: stylePrompt } : {}),
      with_logs: true,
    }),
  });
  
  if (!response.ok) {
    throw new Error(`HTTP error! status: ${response.status}`);
  }
  
  return await response.json();
};
```

### 4. Handle Responses

The API returns a structured response with:
- `success`: Boolean indicating if the operation succeeded
- `result`: The actual result from fal.ai (contains edited image URLs)
- `message`: Human-readable message

### 5. Error Handling

The API returns appropriate HTTP status codes:
- `200`: Success
- `400`: Bad Request (validation errors)
- `500`: Internal Server Error

Always handle errors in your mobile application:

```dart
try {
  final result = await editImages(
    userImageUrl: 'https://example.com/user.png',
    clothingImageUrl: 'https://example.com/outfit.png',
    stylePrompt: 'Add subtle jewelry',
  );
  // Process result
} catch (e) {
  // Handle error
  print('Error: $e');
}
```

## Project Structure

```
backend_server/
├── app/
│   ├── __init__.py
│   ├── main.py              # FastAPI application entry point
│   ├── config.py            # Configuration management
│   ├── routes/
│   │   ├── __init__.py
│   │   └── nano_banana.py   # Nano Banana API routes
│   ├── services/
│   │   ├── __init__.py
│   │   └── nano_banana_service.py  # fal.ai integration service
│   └── models/
│       ├── __init__.py
│       └── response.py      # Response models
├── .env.example             # Example environment variables
├── requirements.txt         # Python dependencies
└── README.md               # This file
```

## Development

### Running Tests

```bash
# Add your test commands here
```

### Code Style

This project follows PEP 8 style guidelines. Consider using:
- `black` for code formatting
- `flake8` for linting
- `mypy` for type checking

## Troubleshooting

### Common Issues

1. **FAL_KEY not configured**
   - Ensure you've set the `FAL_KEY` in your `.env` file
   - Verify the API key is correct

2. **CORS errors**
   - Add your mobile app's origin to `CORS_ORIGINS` in `.env`
   - Ensure the backend server URL is accessible from your mobile device

3. **Image URL errors**
   - Ensure image URLs are publicly accessible
   - Verify URLs are valid HTTP/HTTPS URLs

## License

[Add your license here]

## Support

For issues related to:
- **fal.ai API**: Check [fal.ai documentation](https://fal.ai/docs)
- **Backend Server**: Open an issue in this repository

