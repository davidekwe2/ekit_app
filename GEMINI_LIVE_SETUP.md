# Gemini Live Streaming Setup for Writer 2

## Overview
Writer 2 now uses Gemini Live API for real-time audio transcription streaming. This provides enhanced transcription quality with AI-powered processing.

## Current Implementation

The implementation uses WebSocket connections to the Gemini Live API. However, **you may need to verify the exact WebSocket endpoint** from Google's latest documentation, as the API endpoints may have changed.

## Important Notes

1. **API Key**: Your Gemini API key is stored in `lib/assets/keys/gemini_api_key.json` and is already in `.gitignore` for security.

2. **WebSocket Endpoint**: The current implementation uses:
   ```
   wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key=YOUR_API_KEY
   ```
   
   **You may need to verify this endpoint** from the latest Gemini Live API documentation at:
   - https://ai.google.dev/gemini-api/docs/multimodal-live
   - https://ai.google.dev/api/live

3. **Alternative Package**: If the direct WebSocket implementation doesn't work, you can use the `gemini_live` package:
   ```yaml
   dependencies:
     gemini_live: ^0.1.0
   ```
   
   Then update `lib/services/gemini_live_service.dart` to use the package instead.

## Testing

1. Select "Writer 2" in the record page
2. Start recording
3. The app will attempt to connect to Gemini Live API
4. Audio chunks will be streamed in real-time
5. Transcripts will appear as they're generated

## Troubleshooting

If you encounter connection errors:

1. **Check API Key**: Ensure your Gemini API key is valid and has access to the Live API
2. **Verify Endpoint**: Check Google's latest documentation for the correct WebSocket endpoint
3. **Check Permissions**: Ensure microphone permissions are granted
4. **Network**: Ensure you have a stable internet connection

## Model Options

The current implementation uses `gemini-2.0-flash-live-001`. You can change this in `lib/services/gemini_live_service.dart`:
- `gemini-2.0-flash-live-001`
- `gemini-live-2.5-flash-preview`
- Other models as they become available

## Next Steps

1. Test the connection with your API key
2. If the WebSocket endpoint is incorrect, update it in `lib/services/gemini_live_service.dart`
3. Monitor the console for any connection errors
4. Adjust the message format if needed based on Google's API documentation

