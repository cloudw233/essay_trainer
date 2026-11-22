import 'dart:convert';

import 'package:flutter_deepseek/flutter_deepseek.dart';
import 'package:http/http.dart' as http;

import '../core/prompts/prompt_generation.dart';
import '../models/enums.dart';
import '../models/generated_prompt.dart';
import '../core/utils/id_generator.dart';

/// The request parameters for one independent prompt-generation call.
class PromptGenerationRequest {
  const PromptGenerationRequest({
    required this.language,
    required this.genre,
    required this.difficulty,
    this.count = 3,
    this.avoidTitles = const [],
    this.extraHint = '',
  });

  final EssayLanguage language;
  final EssayGenre genre;
  final PromptDifficulty difficulty;
  final int count;
  final List<String> avoidTitles;
  final String extraHint;
}

/// A successful batch plus the raw model text for diagnostics.
class PromptGenerationBatch {
  const PromptGenerationBatch({
    required this.prompts,
    required this.rawResponse,
    required this.attempts,
  });

  final List<GeneratedPrompt> prompts;
  final String rawResponse;
  final int attempts;
}

class PromptGenerationException implements Exception {
  const PromptGenerationException(this.message, {this.rawResponse});

  final String message;
  final String? rawResponse;

  @override
  String toString() => message;
}

/// DeepSeek prompt generation using JSON mode, not `strict` function schemas.
///
/// DeepSeek's json_object mode guarantees syntactic JSON but not our field
/// names, so every response is validated locally and the model gets exactly
/// one correction attempt.
class PromptGenerationService {
  PromptGenerationService({
    http.Client? httpClient,
    this.timeout = const Duration(seconds: 60),
  }) : _httpClient = httpClient;

  final http.Client? _httpClient;
  final Duration timeout;

  Future<PromptGenerationBatch> generate({
    required String apiKey,
    required PromptGenerationRequest request,
    void Function(int attempt)? onAttempt,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const PromptGenerationException('请先配置 DeepSeek API Key。');
    }

    final client = DeepSeekClient(
      apiKey: key,
      timeout: timeout,
      httpClient: _httpClient,
    );

    String? lastRaw;

    try {
      for (var attempt = 1; attempt <= 2; attempt++) {
        onAttempt?.call(attempt);
        final correction = attempt == 2
            ? '\n\n上一次输出未通过格式校验，请只返回符合上述 schema 的 JSON，字段名和类型必须完全一致。'
            : '';

        try {
          final response = await client.chat(
            model: DeepSeekModel.chat,
            messages: [
              ChatMessage.user(
                PromptGenerationPromptBuilder.userPrompt(
                      language: request.language,
                      genre: request.genre,
                      difficulty: request.difficulty,
                      count: request.count,
                      avoidTitles: request.avoidTitles,
                      extraHint: request.extraHint,
                    ) +
                    correction,
              ),
            ],
            systemPrompt: PromptGenerationPromptBuilder.systemPrompt(
              request.language,
            ),
            temperature: 0.9,
            maxTokens: 1800,
            extra: const {
              'response_format': {'type': 'json_object'},
            },
          );

          lastRaw = response.text;
          final prompts = _validateResponse(
            lastRaw,
            language: request.language,
            count: request.count,
          );
          return PromptGenerationBatch(
            prompts: prompts,
            rawResponse: lastRaw,
            attempts: attempt,
          );
        } on FormatException {
          // The loop intentionally retries exactly once, then exits.
        } on TypeError {
          // A malformed field type is still a validation failure, not a
          // transport failure, so the correction attempt applies here too.
        }
      }

      throw PromptGenerationException(
        'AI 返回的题目格式没有通过校验，已停止重试。你可以再试一次，或手动输入题目。',
        rawResponse: lastRaw,
      );
    } on DeepSeekAuthException {
      throw const PromptGenerationException('API Key 无效或已过期，请检查后重试。');
    } on DeepSeekRateLimitException {
      throw const PromptGenerationException('请求过于频繁，请稍等片刻再试。');
    } on DeepSeekRequestException {
      throw const PromptGenerationException('请求参数未被 DeepSeek 接受，请稍后重试。');
    } on DeepSeekServerException {
      throw const PromptGenerationException('DeepSeek 服务暂时不可用，请稍后重试。');
    } on DeepSeekNetworkException {
      throw const PromptGenerationException('网络连接失败，请检查网络后重试。');
    } on DeepSeekException {
      throw const PromptGenerationException('DeepSeek 返回了未预期的错误，请稍后重试。');
    } on PromptGenerationException {
      rethrow;
    } catch (error) {
      throw PromptGenerationException(
        '生成题目失败，请稍后重试或手动输入题目。',
        rawResponse: lastRaw,
      );
    } finally {
      client.dispose();
    }
  }

  List<GeneratedPrompt> _validateResponse(
    String raw, {
    required EssayLanguage language,
    required int count,
  }) {
    final json = _decodeJsonObject(raw);
    final rawPrompts = json['prompts'];
    if (rawPrompts is! List<dynamic> || rawPrompts.length != count) {
      throw FormatException('prompts 必须正好包含 $count 项');
    }

    final createdAt = DateTime.now();
    final prompts = <GeneratedPrompt>[];
    for (final item in rawPrompts) {
      if (item is! Map<dynamic, dynamic>) {
        throw const FormatException('prompts 中的每一项都必须是对象');
      }
      prompts.add(
        GeneratedPrompt.fromJson(
          Map<String, dynamic>.from(item),
          id: newLocalId('prompt'),
          language: language,
          createdAt: createdAt,
        ),
      );
    }

    final normalized = prompts
        .map((prompt) => '${prompt.title}|${prompt.promptText}'.trim())
        .toSet();
    if (normalized.length != prompts.length) {
      throw const FormatException('三道候选题目不能完全相同');
    }

    return List.unmodifiable(prompts);
  }

  Map<String, dynamic> _decodeJsonObject(String raw) {
    var text = raw.trim();
    if (text.startsWith('```')) {
      text = text.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      text = text.replaceFirst(RegExp(r'\s*```$'), '');
    }

    final start = text.indexOf('{');
    final end = text.lastIndexOf('}');
    if (start < 0 || end <= start) {
      throw const FormatException('响应中找不到 JSON 对象');
    }

    final decoded = jsonDecode(text.substring(start, end + 1));
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('JSON 根节点必须是对象');
    }
    return decoded;
  }
}
