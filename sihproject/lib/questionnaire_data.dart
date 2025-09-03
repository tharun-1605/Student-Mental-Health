import 'package:flutter/material.dart';

// Enum for questionnaire types
enum QuestionnaireType {
  PHQ9,
  GAD7,
  GHQ,
}

// Severity levels
enum SeverityLevel {
  minimal,
  mild,
  moderate,
  moderatelySevere,
  severe,
  noSignificant,
}

// Questionnaire question model
class Question {
  final String text;
  final List<String> options;

  const Question({
    required this.text,
    required this.options,
  });
}

// Questionnaire model
class Questionnaire {
  final String title;
  final String description;
  final List<Question> questions;
  final QuestionnaireType type;

  const Questionnaire({
    required this.title,
    required this.description,
    required this.questions,
    required this.type,
  });

  int get maxScore => questions.length * 3; // Each question is 0-3 points
}

// Scoring result model
class ScoringResult {
  final int totalScore;
  final SeverityLevel severity;
  final String severityDescription;
  final String recommendation;
  final Color severityColor;

  const ScoringResult({
    required this.totalScore,
    required this.severity,
    required this.severityDescription,
    required this.recommendation,
    required this.severityColor,
  });
}

// PHQ-9 Questionnaire Data
const List<Question> phq9Questions = [
  Question(
    text: 'Little interest or pleasure in doing things',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Feeling down, depressed, or hopeless',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Trouble falling or staying asleep, or sleeping too much',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Feeling tired or having little energy',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Poor appetite or overeating',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Feeling bad about yourself or that you are a failure or have let yourself or your family down',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Trouble concentrating on things, such as reading the newspaper or watching television',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Moving or speaking so slowly that other people could have noticed. Or the opposite - being so fidgety or restless that you have been moving around a lot more than usual',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Thoughts that you would be better off dead, or of hurting yourself',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
];

const Questionnaire phq9Questionnaire = Questionnaire(
  title: 'PHQ-9 Depression Screening',
  description: 'Patient Health Questionnaire-9 for assessing depression severity over the past 2 weeks.',
  questions: phq9Questions,
  type: QuestionnaireType.PHQ9,
);

// GAD-7 Questionnaire Data
const List<Question> gad7Questions = [
  Question(
    text: 'Feeling nervous, anxious, or on edge',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Not being able to stop or control worrying',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Worrying too much about different things',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Trouble relaxing',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Being so restless that it is hard to sit still',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Becoming easily annoyed or irritable',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
  Question(
    text: 'Feeling afraid as if something awful might happen',
    options: [
      'Not at all',
      'Several days',
      'More than half the days',
      'Nearly every day'
    ],
  ),
];

const Questionnaire gad7Questionnaire = Questionnaire(
  title: 'GAD-7 Anxiety Screening',
  description: 'Generalized Anxiety Disorder-7 for assessing anxiety severity over the past 2 weeks.',
  questions: gad7Questions,
  type: QuestionnaireType.GAD7,
);

// GHQ-12 Questionnaire Data
const List<Question> ghq12Questions = [
  Question(
    text: 'Have you recently been able to concentrate on whatever you are doing?',
    options: [
      'Better than usual',
      'Same as usual',
      'Less than usual',
      'Much less than usual'
    ],
  ),
  Question(
    text: 'Have you recently lost much sleep over worry?',
    options: [
      'Not at all',
      'No more than usual',
      'Rather more than usual',
      'Much more than usual'
    ],
  ),
  Question(
    text: 'Have you recently felt that you are playing a useful part in things?',
    options: [
      'More so than usual',
      'Same as usual',
      'Less than usual',
      'Much less than usual'
    ],
  ),
  Question(
    text: 'Have you recently felt capable of making decisions about things?',
    options: [
      'More so than usual',
      'Same as usual',
      'Less than usual',
      'Much less than usual'
    ],
  ),
  Question(
    text: 'Have you recently felt constantly under strain?',
    options: [
      'Not at all',
      'No more than usual',
      'Rather more than usual',
      'Much more than usual'
    ],
  ),
  Question(
    text: 'Have you recently felt you couldn\'t overcome your difficulties?',
    options: [
      'Not at all',
      'No more than usual',
      'Rather more than usual',
      'Much more than usual'
    ],
  ),
  Question(
    text: 'Have you recently been able to enjoy your normal day-to-day activities?',
    options: [
      'More than usual',
      'Same as usual',
      'Less than usual',
      'Much less than usual'
    ],
  ),
  Question(
    text: 'Have you recently been able to face up to your problems?',
    options: [
      'More so than usual',
      'Same as usual',
      'Less than usual',
      'Much less than usual'
    ],
  ),
  Question(
    text: 'Have you recently been feeling unhappy and depressed?',
    options: [
      'Not at all',
      'No more than usual',
      'Rather more than usual',
      'Much more than usual'
    ],
  ),
  Question(
    text: 'Have you recently been losing confidence in yourself?',
    options: [
      'Not at all',
      'No more than usual',
      'Rather more than usual',
      'Much more than usual'
    ],
  ),
  Question(
    text: 'Have you recently been thinking of yourself as a worthless person?',
    options: [
      'Not at all',
      'No more than usual',
      'Rather more than usual',
      'Much more than usual'
    ],
  ),
  Question(
    text: 'Have you recently been feeling reasonably happy, all things considered?',
    options: [
      'More so than usual',
      'Same as usual',
      'Less than usual',
      'Much less than usual'
    ],
  ),
];

const Questionnaire ghq12Questionnaire = Questionnaire(
  title: 'GHQ-12 General Health Screening',
  description: 'General Health Questionnaire-12 for assessing general mental health and distress.',
  questions: ghq12Questions,
  type: QuestionnaireType.GHQ,
);

// Scoring functions
class QuestionnaireScorer {
  static ScoringResult calculatePHQ9Score(List<int> scores) {
    int totalScore = scores.reduce((a, b) => a + b);

    if (totalScore <= 4) {
      return const ScoringResult(
        totalScore: 0, // Will be set dynamically
        severity: SeverityLevel.minimal,
        severityDescription: 'Minimal Depression',
        recommendation: 'Your symptoms suggest minimal depression. Continue monitoring your mental health.',
        severityColor: Colors.green,
      );
    } else if (totalScore <= 9) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.mild,
        severityDescription: 'Mild Depression',
        recommendation: 'Consider lifestyle changes, exercise, or talking to a counselor.',
        severityColor: Colors.yellow,
      );
    } else if (totalScore <= 14) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.moderate,
        severityDescription: 'Moderate Depression',
        recommendation: 'Professional help recommended. Consider therapy or counseling.',
        severityColor: Colors.orange,
      );
    } else if (totalScore <= 19) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.moderatelySevere,
        severityDescription: 'Moderately Severe Depression',
        recommendation: 'Seek professional medical help. Consider medication and therapy.',
        severityColor: Colors.deepOrange,
      );
    } else {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.severe,
        severityDescription: 'Severe Depression',
        recommendation: 'Immediate professional help required. Contact mental health services.',
        severityColor: Colors.red,
      );
    }
  }

  static ScoringResult calculateGAD7Score(List<int> scores) {
    int totalScore = scores.reduce((a, b) => a + b);

    if (totalScore <= 4) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.minimal,
        severityDescription: 'Minimal Anxiety',
        recommendation: 'Your symptoms suggest minimal anxiety. Continue monitoring your mental health.',
        severityColor: Colors.green,
      );
    } else if (totalScore <= 9) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.mild,
        severityDescription: 'Mild Anxiety',
        recommendation: 'Consider relaxation techniques, exercise, or talking to a counselor.',
        severityColor: Colors.yellow,
      );
    } else if (totalScore <= 14) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.moderate,
        severityDescription: 'Moderate Anxiety',
        recommendation: 'Professional help recommended. Consider therapy or counseling.',
        severityColor: Colors.orange,
      );
    } else {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.severe,
        severityDescription: 'Severe Anxiety',
        recommendation: 'Seek professional medical help. Consider medication and therapy.',
        severityColor: Colors.red,
      );
    }
  }

  static ScoringResult calculateGHQ12Score(List<int> scores) {
    // GHQ-12 scoring: 0-0-1-1 for each question (0,0,1,1)
    int totalScore = 0;
    for (int score in scores) {
      if (score == 2) totalScore += 1; // "Less than usual" = 1
      else if (score == 3) totalScore += 1; // "Much less than usual" = 1
    }

    if (totalScore <= 11) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.noSignificant,
        severityDescription: 'No Significant Distress',
        recommendation: 'Your general health appears good. Continue maintaining healthy habits.',
        severityColor: Colors.green,
      );
    } else if (totalScore <= 15) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.mild,
        severityDescription: 'Mild Distress',
        recommendation: 'Consider stress management techniques and self-care activities.',
        severityColor: Colors.yellow,
      );
    } else if (totalScore <= 20) {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.moderate,
        severityDescription: 'Moderate Distress',
        recommendation: 'Professional support recommended. Consider counseling or therapy.',
        severityColor: Colors.orange,
      );
    } else {
      return const ScoringResult(
        totalScore: 0,
        severity: SeverityLevel.severe,
        severityDescription: 'Severe Distress',
        recommendation: 'Seek immediate professional help. Contact mental health services.',
        severityColor: Colors.red,
      );
    }
  }

  static ScoringResult calculateScore(QuestionnaireType type, List<int> scores) {
    ScoringResult result;
    switch (type) {
      case QuestionnaireType.PHQ9:
        result = calculatePHQ9Score(scores);
        break;
      case QuestionnaireType.GAD7:
        result = calculateGAD7Score(scores);
        break;
      case QuestionnaireType.GHQ:
        result = calculateGHQ12Score(scores);
        break;
    }
    return ScoringResult(
      totalScore: scores.reduce((a, b) => a + b),
      severity: result.severity,
      severityDescription: result.severityDescription,
      recommendation: result.recommendation,
      severityColor: result.severityColor,
    );
  }
}

// Helper function to get questionnaire by type
Questionnaire getQuestionnaire(QuestionnaireType type) {
  switch (type) {
    case QuestionnaireType.PHQ9:
      return phq9Questionnaire;
    case QuestionnaireType.GAD7:
      return gad7Questionnaire;
    case QuestionnaireType.GHQ:
      return ghq12Questionnaire;
  }
}
