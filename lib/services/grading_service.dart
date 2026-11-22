import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/prompts/grading_tool.dart';
import '../core/prompts/prompt_builder.dart';
import '../models/enums.dart';
import '../models/essay_draft.dart';
import '../models/grading_report.dart';

/// A user-visible failure from the grading call.
class GradingServiceException implements Exception {
  const GradingServiceException(
    this.message, {
    this.rawResponse,
    this.statusCode,
  });

  final String message;
  final String? rawResponse;
  final int? statusCode;

  @override
  String toString() => message;
}

/// DeepSeek grading over the function-calling endpoint.
///
/// `flutter_deepseek 0.1.1` can send tools but its non-streaming response model
/// drops `tool_calls`, so this service uses the same tool schema via HTTP and
/// parses the tool arguments itself. The tool schema and the package's typed
/// models remain the source of truth; no `strict` flag is used.
class GradingService {
  GradingService({
    http.Client? httpClient,
    this.baseUrl = 'https://api.deepseek.com',
    this.timeout = const Duration(seconds: 120),
  }) : _httpClient = httpClient;

  final http.Client? _httpClient;
  final String baseUrl;
  final Duration timeout;

  Future<GradingReport> grade({
    required String apiKey,
    required EssayDraft draft,
    required String reportId,
    DateTime? createdAt,
    void Function(int attempt)? onAttempt,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw const GradingServiceException('请先配置 DeepSeek API Key。');
    }

    final maxScore = draft.language.defaultMaxScore.toDouble();
    final systemPrompt = PromptBuilder.systemPrompt(
      language: draft.language,
      genre: draft.genre,
      maxScore: maxScore.toInt(),
    );
    final baseUserPrompt = PromptBuilder.userPrompt(
      language: draft.language,
      genre: draft.genre,
      title: draft.title,
      content: draft.content,
      maxScore: maxScore.toInt(),
      promptText: draft.promptText,
    );

    final client = _httpClient ?? http.Client();
    final ownedClient = _httpClient == null;
    String? lastRaw;

    try {
      for (var attempt = 1; attempt <= 2; attempt++) {
        onAttempt?.call(attempt);
        final userPrompt = attempt == 2
            ? '$baseUserPrompt\n\n上一次输出未通过结构校验。请重新调用 '
                  '$gradingToolName，且 JSON 参数必须完全符合工具 schema，'
                  '不要省略任何必填字段，不要输出解释或 Markdown。'
            : baseUserPrompt;

        final response = await _post(
          client: client,
          apiKey: key,
          body: {
            'model': 'deepseek-chat',
            'messages': [
              {'role': 'system', 'content': systemPrompt},
              {'role': 'user', 'content': userPrompt},
            ],
            'temperature': 0.3,
            'max_tokens': 4096,
            'stream': false,
            'tools': [buildGradingTool()],
            'tool_choice': {
              'type': 'function',
              'function': {'name': gradingToolName},
            },
          },
        );

        if (response.statusCode != 200) {
          throw _statusError(response);
        }

        lastRaw = response.body;
        final rawArguments = _extractToolArguments(_responseText(response));
        lastRaw = rawArguments;
        try {
          final arguments = _decodeObject(rawArguments);
          _validatePayload(arguments, maxScore);
          return GradingReport.fromAiJson(
            {...arguments, 'maxScore': maxScore},
            id: reportId,
            draftId: draft.id,
            rawAiResponse: rawArguments,
            createdAt: createdAt ?? DateTime.now(),
          );
        } on FormatException {
          if (attempt == 2) {
            throw GradingServiceException(
              '批改结果的结构校验没有通过，已停止重试。你可以查看原始响应或重新批改。',
              rawResponse: lastRaw,
            );
          }
        }
      }

      throw GradingServiceException(
        '批改结果的结构校验没有通过，已停止重试。你可以查看原始响应或重新批改。',
        rawResponse: lastRaw,
      );
    } on GradingServiceException {
      rethrow;
    } on SocketException {
      throw GradingServiceException('网络连接失败，请检查网络后重试。', rawResponse: lastRaw);
    } on TimeoutException {
      throw GradingServiceException(
        '批改请求超时，AI 可能仍在处理。请检查网络后重试。',
        rawResponse: lastRaw,
      );
    } on http.ClientException {
      throw GradingServiceException('网络连接失败，请检查网络后重试。', rawResponse: lastRaw);
    } on FormatException {
      throw GradingServiceException(
        'AI 返回的批改结果无法解析。请重试，或查看原始响应。',
        rawResponse: lastRaw,
      );
    } catch (_) {
      throw GradingServiceException('批改失败，请稍后重试。', rawResponse: lastRaw);
    } finally {
      if (ownedClient) client.close();
    }
  }

  Future<http.Response> _post({
    required http.Client client,
    required String apiKey,
    required Map<String, dynamic> body,
  }) {
    return client
        .post(
          Uri.parse(
            '${baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl}/chat/completions',
          ),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: jsonEncode(body),
        )
        .timeout(timeout);
  }

  GradingServiceException _statusError(http.Response response) {
    final body = _responseText(response);
    String message = 'DeepSeek 返回了错误（${response.statusCode}）。';
    try {
      final json = jsonDecode(body) as Map<String, dynamic>;
      final error = json['error'];
      if (error is Map<String, dynamic> && error['message'] is String) {
        message = error['message'] as String;
      }
    } catch (_) {
      if (body.trim().isNotEmpty) message = body.trim();
    }

    final friendly = switch (response.statusCode) {
      401 => 'API Key 无效或已过期，请检查后重试。',
      429 => '请求过于频繁，请稍等片刻再试。',
      400 => 'DeepSeek 没有接受这次批改请求，请稍后重试。',
      503 => 'DeepSeek 服务暂时不可用，请稍后重试。',
      _ => 'DeepSeek 返回错误：$message',
    };
    return GradingServiceException(
      friendly,
      rawResponse: body,
      statusCode: response.statusCode,
    );
  }

  /// Extracts the JSON arguments from a tool call. A content JSON fallback is
  /// allowed only because some gateways ignore `tool_choice`; the strict schema
  /// validation is identical either way.
  String _responseText(http.Response response) {
    try {
      return utf8.decode(response.bodyBytes);
    } on FormatException {
      return response.body;
    }
  }

  String _extractToolArguments(String responseBody) {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('response is not a JSON object');
    }
    final choices = decoded['choices'];
    if (choices is! List<dynamic> || choices.isEmpty) {
      throw const FormatException('response has no choices');
    }
    final first = choices.first;
    if (first is! Map<String, dynamic>) {
      throw const FormatException('choice is not an object');
    }
    final message = first['message'];
    if (message is! Map<String, dynamic>) {
      throw const FormatException('choice has no message');
    }

    final toolCalls = message['tool_calls'];
    if (toolCalls is List<dynamic> && toolCalls.isNotEmpty) {
      final firstCall = toolCalls.first;
      if (firstCall is Map<String, dynamic>) {
        final function = firstCall['function'];
        if (function is Map<String, dynamic> &&
            function['arguments'] is String) {
          final args = (function['arguments'] as String).trim();
          if (args.isNotEmpty) return args;
        }
      }
    }

    final content = message['content'];
    if (content is String && content.trim().isNotEmpty) {
      final text = _stripCodeFence(content.trim());
      if (text.startsWith('{') && text.endsWith('}')) return text;
    }

    throw const FormatException('response has no tool call arguments');
  }

  Map<String, dynamic> _decodeObject(String raw) {
    final text = _stripCodeFence(raw.trim());
    final decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('tool arguments must be an object');
    }
    return decoded;
  }

  String _stripCodeFence(String text) {
    var value = text;
    if (value.startsWith('```')) {
      value = value.replaceFirst(RegExp(r'^```(?:json)?\s*'), '');
      value = value.replaceFirst(RegExp(r'\s*```$'), '');
    }
    final start = value.indexOf('{');
    final end = value.lastIndexOf('}');
    if (start >= 0 && end > start) {
      value = value.substring(start, end + 1);
    }
    return value;
  }

  void _validatePayload(Map<String, dynamic> json, double maxScore) {
    final overall = _num(json['overallScore'], 'overallScore');
    if (overall < 0 || overall > maxScore + 0.01) {
      throw const FormatException('overallScore is outside the score range');
    }

    final dimensions = json['dimensionScores'];
    if (dimensions is! List<dynamic> || dimensions.isEmpty) {
      throw const FormatException('dimensionScores must be non-empty');
    }
    for (final item in dimensions) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('dimension must be an object');
      }
      _requiredString(item['name'], 'dimension.name');
      _num(item['score'], 'dimension.score');
      final dimensionMax = _num(item['maxScore'], 'dimension.maxScore');
      if (dimensionMax <= 0) {
        throw const FormatException('dimension.maxScore must be positive');
      }
      _requiredString(item['comment'], 'dimension.comment');
    }

    final sentences = json['sentenceFeedback'];
    if (sentences is! List<dynamic> || sentences.isEmpty) {
      throw const FormatException('sentenceFeedback must be non-empty');
    }
    for (final item in sentences) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('sentence feedback must be an object');
      }
      _nonNegativeInt(item['sentenceIndex'], 'sentenceFeedback.sentenceIndex');
      _requiredString(item['originalText'], 'sentenceFeedback.originalText');
      final issueType = item['issueType'];
      if (issueType is! String || feedbackIssueTypeOrNull(issueType) == null) {
        throw const FormatException('invalid issueType');
      }
      final severity = item['severity'];
      if (severity is! String || feedbackSeverityOrNull(severity) == null) {
        throw const FormatException('invalid severity');
      }
      _requiredString(item['comment'], 'sentenceFeedback.comment');
      _requiredString(item['suggestion'], 'sentenceFeedback.suggestion');
    }

    final paragraphs = json['paragraphFeedback'];
    if (paragraphs is! List<dynamic> || paragraphs.isEmpty) {
      throw const FormatException('paragraphFeedback must be non-empty');
    }
    for (final item in paragraphs) {
      if (item is! Map<String, dynamic>) {
        throw const FormatException('paragraph feedback must be an object');
      }
      _nonNegativeInt(
        item['paragraphIndex'],
        'paragraphFeedback.paragraphIndex',
      );
      _requiredString(
        item['coherenceComment'],
        'paragraphFeedback.coherenceComment',
      );
      _requiredString(
        item['contentComment'],
        'paragraphFeedback.contentComment',
      );
      _requiredString(item['suggestion'], 'paragraphFeedback.suggestion');
    }

    _requiredString(json['revisedEssay'], 'revisedEssay');
  }

  double _num(Object? value, String field) {
    if (value is num) return value.toDouble();
    throw FormatException('$field must be a number');
  }

  int _nonNegativeInt(Object? value, String field) {
    if (value is int && value >= 0) return value;
    if (value is num && value >= 0 && value == value.roundToDouble()) {
      return value.toInt();
    }
    throw FormatException('$field must be a non-negative integer');
  }

  String _requiredString(Object? value, String field) {
    if (value is String && value.trim().isNotEmpty) return value.trim();
    throw FormatException('$field must be a non-empty string');
  }
}
