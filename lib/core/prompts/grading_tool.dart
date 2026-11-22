/// The function-calling contract for a structured grading report.
///
/// `flutter_deepseek 0.1.1` defines [ToolCall] but its non-streaming response
/// model drops `tool_calls`, so [GradingService] sends this same tool schema
/// with its own HTTP call and parses the returned tool arguments. The schema is
/// still the single source of truth for the grader prompt and validation.
const String gradingToolName = 'submit_grading_report';

Map<String, dynamic> buildGradingTool() {
  const scoreProperties = {
    'name': {'type': 'string', 'description': '维度名称'},
    'score': {'type': 'number', 'description': '该维度得分'},
    'maxScore': {'type': 'number', 'description': '该维度满分'},
    'comment': {'type': 'string', 'description': '得分理由'},
  };

  return {
    'type': 'function',
    'function': {
      'name': gradingToolName,
      'description':
          'Submit the complete structured grading report for one essay. '
          'Call this exactly once with every required field.',
      'parameters': {
        'type': 'object',
        'properties': {
          'overallScore': {'type': 'number'},
          'maxScore': {'type': 'number'},
          'dimensionScores': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': scoreProperties,
              'required': ['name', 'score', 'maxScore', 'comment'],
            },
          },
          'sentenceFeedback': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'sentenceIndex': {'type': 'integer'},
                'originalText': {'type': 'string'},
                'issueType': {
                  'type': 'string',
                  'enum': [
                    'grammar',
                    'wordChoice',
                    'coherence',
                    'spelling',
                    'praise',
                  ],
                },
                'severity': {
                  'type': 'string',
                  'enum': ['critical', 'minor', 'suggestion', 'highlight'],
                },
                'comment': {'type': 'string'},
                'suggestion': {'type': 'string'},
              },
              'required': [
                'sentenceIndex',
                'originalText',
                'issueType',
                'severity',
                'comment',
                'suggestion',
              ],
            },
          },
          'paragraphFeedback': {
            'type': 'array',
            'items': {
              'type': 'object',
              'properties': {
                'paragraphIndex': {'type': 'integer'},
                'coherenceComment': {'type': 'string'},
                'contentComment': {'type': 'string'},
                'suggestion': {'type': 'string'},
              },
              'required': [
                'paragraphIndex',
                'coherenceComment',
                'contentComment',
                'suggestion',
              ],
            },
          },
          'revisedEssay': {'type': 'string'},
        },
        'required': [
          'overallScore',
          'maxScore',
          'dimensionScores',
          'sentenceFeedback',
          'paragraphFeedback',
          'revisedEssay',
        ],
      },
    },
  };
}
