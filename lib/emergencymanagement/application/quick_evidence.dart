/// Port to the camera and microphone for the quick evidence of A_04.
abstract interface class QuickEvidence {
  /// Opens the camera and returns the local path of the photo, or null if
  /// the citizen cancelled.
  Future<String?> takePhoto();

  /// Starts recording audio. Returns false without microphone permission.
  Future<bool> startAudio();

  /// Stops the recording and returns the local path of the audio file.
  Future<String?> stopAudio();
}
