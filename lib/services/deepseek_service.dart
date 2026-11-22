import 'package:flutter_deepseek/flutter_deepseek.dart';
import 'package:http/http.dart' as http;

/// A user-facing failure from the AI connection layer.
class DeepSeekServiceException implements Exception {
  const DeepSeekServiceException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The single place that talks to DeepSeek.
///
/// Phase 1 only performs a tiny `Say OK` probe. Grading and streaming will be
/// added here in Phase 2, so the UI never depends on the package's raw types.
class DeepSeekService {
  DeepSeekService({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 30),
  }) : _httpClient = httpClient;

  final http.Client? _httpClient;
  final Duration timeout;

  /// Sends the documented connectivity probe and returns the reply text.
  Future<String> testConnection(String apiKey) async {
    final trimmed = apiKey.trim();
    if (trimmed.isEmpty) {
      throw const DeepSeekServiceException('请先填写 API Key。');
    }

    final client = DeepSeekClient(
      apiKey: trimmed,
      timeout: timeout,
      httpClient: _httpClient,
    );

    try {
      final response = await client.chat(
        messages: [ChatMessage.user('Say OK')],
        model: DeepSeekModel.chat,
        temperature: 0,
        maxTokens: 8,
      );
      final reply = response.text.trim();
      if (reply.isEmpty) {
        throw const DeepSeekServiceException('连接成功，但模型没有返回内容。');
      }
      return reply;
    } on DeepSeekAuthException {
      throw const DeepSeekServiceException('API Key 无效或已过期，请检查后重试。');
    } on DeepSeekRateLimitException {
      throw const DeepSeekServiceException('请求过于频繁，请稍等片刻再试。');
    } on DeepSeekRequestException {
      throw const DeepSeekServiceException('请求参数未被 DeepSeek 接受，请稍后重试。');
    } on DeepSeekServerException {
      throw const DeepSeekServiceException('DeepSeek 服务暂时不可用，请稍后重试。');
    } on DeepSeekNetworkException {
      throw const DeepSeekServiceException('网络连接失败，请检查网络后重试。');
    } on DeepSeekException {
      throw const DeepSeekServiceException('DeepSeek 返回了未预期的错误，请稍后重试。');
    } finally {
      client.dispose();
    }
  }
}
