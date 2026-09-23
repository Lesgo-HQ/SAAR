import '../models/role_ontology.dart';
import '../models/ui_node.dart';

class NodeMatch {
  final UiNode node;
  final double score;

  const NodeMatch(this.node, this.score);
}

class NodeRanker {
  static const double executeThreshold = 0.85;
  static const double verifyThreshold = 0.65;

  NodeMatch? best(Iterable<UiNode> nodes, String targetRole) {
    final ranked = nodes.map((node) => NodeMatch(node, _score(node, targetRole))).toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    return ranked.isEmpty || ranked.first.score < executeThreshold ? null : ranked.first;
  }

  double _score(UiNode node, String targetRole) {
    final roleScore = RoleOntology.matchScore(node, targetRole);
    final classScore = node.isEditable || node.isClickable ? 1.0 : 0.0;
    final text = '${node.text ?? ''} ${node.contentDescription ?? ''}'.toLowerCase();
    final terms = targetRole.toLowerCase().split('_');
    final textScore = terms.where(text.contains).length / terms.length;
    return (roleScore * 0.65 + classScore * 0.2 + textScore * 0.15).clamp(0.0, 1.0).toDouble();
  }
}
