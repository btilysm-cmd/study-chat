/// Converts an assistant answer (Markdown + LaTeX) into plain readable text
/// suitable for the clipboard.
String readableText(String source) {
  var text = source.replaceAll('\r\n', '\n');
  final out = <String>[];
  var inFence = false;
  for (final raw in text.split('\n')) {
    final line = raw.trimRight();
    if (line.trimLeft().startsWith('```')) {
      inFence = !inFence;
      continue;
    }
    if (inFence) {
      out.add(line);
      continue;
    }
    var next = line;
    final heading = RegExp(r'^\s{0,3}#{1,6}\s+').firstMatch(next);
    if (heading != null) next = next.substring(heading.end);
    next = next.replaceFirst(RegExp(r'^\s*>\s?'), '');
    next = next.replaceAllMapped(
      RegExp(r'^(\s*)[-*+]\s+'),
      (match) => '${match[1]}• ',
    );
    out.add(next);
  }
  text = out.join('\n');

  text = text.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\(([^)]*)\)'),
    (match) => '🖼 ${match[1]!.isEmpty ? '图片' : match[1]}',
  );
  text = text.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\(([^)]+)\)'),
    (match) => '${match[1]}（${match[2]}）',
  );
  text = text.replaceAllMapped(
    RegExp(r'\$\$([\s\S]+?)\$\$|\\\[([\s\S]+?)\\\]'),
    (match) => '\n${_texToText(match[1] ?? match[2] ?? '')}\n',
  );
  text = text.replaceAllMapped(
    RegExp(r'\$([^$\n]+?)\$|\\\(([\s\S]+?)\\\)'),
    (match) => _texToText(match[1] ?? match[2] ?? ''),
  );
  text = text.replaceAllMapped(RegExp(r'\*\*(.+?)\*\*'), (m) => m[1]!);
  text = text.replaceAllMapped(RegExp(r'__(.+?)__'), (m) => m[1]!);
  text = text.replaceAll(RegExp(r'```[a-zA-Z0-9_+-]*'), '');
  text = text.replaceAll('```', '');
  return text.replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

const _greek = {
  'alpha': 'α',
  'beta': 'β',
  'gamma': 'γ',
  'delta': 'δ',
  'epsilon': 'ε',
  'varepsilon': 'ε',
  'zeta': 'ζ',
  'eta': 'η',
  'theta': 'θ',
  'vartheta': 'θ',
  'iota': 'ι',
  'kappa': 'κ',
  'lambda': 'λ',
  'mu': 'μ',
  'nu': 'ν',
  'xi': 'ξ',
  'pi': 'π',
  'rho': 'ρ',
  'sigma': 'σ',
  'tau': 'τ',
  'upsilon': 'υ',
  'phi': 'φ',
  'varphi': 'φ',
  'chi': 'χ',
  'psi': 'ψ',
  'omega': 'ω',
  'Gamma': 'Γ',
  'Delta': 'Δ',
  'Theta': 'Θ',
  'Lambda': 'Λ',
  'Xi': 'Ξ',
  'Pi': 'Π',
  'Sigma': 'Σ',
  'Upsilon': 'Υ',
  'Phi': 'Φ',
  'Psi': 'Ψ',
  'Omega': 'Ω',
};

const _symbols = {
  'sum': 'Σ',
  'prod': 'Π',
  'int': '∫',
  'iint': '∬',
  'oint': '∮',
  'in': '∈',
  'notin': '∉',
  'ni': '∋',
  'subset': '⊂',
  'subseteq': '⊆',
  'supset': '⊃',
  'cup': '∪',
  'cap': '∩',
  'le': '≤',
  'leq': '≤',
  'ge': '≥',
  'geq': '≥',
  'ne': '≠',
  'neq': '≠',
  'approx': '≈',
  'equiv': '≡',
  'sim': '∼',
  'propto': '∝',
  'times': '×',
  'div': '÷',
  'cdot': '·',
  'pm': '±',
  'mp': '∓',
  'infty': '∞',
  'partial': '∂',
  'nabla': '∇',
  'to': '→',
  'rightarrow': '→',
  'leftarrow': '←',
  'leftrightarrow': '↔',
  'Rightarrow': '⇒',
  'Leftarrow': '⇐',
  'Leftrightarrow': '⇔',
  'forall': '∀',
  'exists': '∃',
  'emptyset': '∅',
  'varnothing': '∅',
  'angle': '∠',
  'perp': '⊥',
  'parallel': '∥',
  'cong': '≅',
  'circ': '∘',
  'ast': '∗',
  'star': '⋆',
  'degree': '°',
  'prime': '′',
  'dots': '…',
  'ldots': '…',
  'cdots': '⋯',
  'vdots': '⋮',
  'ddots': '⋱',
  'hbar': 'ℏ',
  'ell': 'ℓ',
  'Re': 'ℜ',
  'Im': 'ℑ',
  'aleph': 'ℵ',
  'therefore': '∴',
  'because': '∵',
  'quad': ' ',
  'qquad': '  ',
};

String _texToText(String tex) {
  var s = tex.trim();
  // \frac{a}{b} -> (a)/(b); nested formatting is left as-is.
  for (var i = 0; i < 4; i++) {
    final before = s;
    s = s.replaceAllMapped(
      RegExp(r'\\frac\s*\{([^{}]*)\}\s*\{([^{}]*)\}'),
      (m) => '(${m[1]})/(${m[2]})',
    );
    if (before == s) break;
  }
  s = s.replaceAllMapped(RegExp(r'\\sqrt\s*\{([^{}]*)\}'), (m) => '√(${m[1]})');
  s = s.replaceAllMapped(
    RegExp(
      r'\\(?:text|mathrm|mathbf|mathit|operatorname|mathbb|mathcal|mathsf)\s*\{([^{}]*)\}',
    ),
    (m) => m[1] ?? '',
  );
  s = s.replaceAllMapped(RegExp(r'\\([a-zA-Z]+)'), (m) {
    final name = m[1]!;
    return _greek[name] ?? _symbols[name] ?? name;
  });
  s = s.replaceAll(
    RegExp(r'\\left|\\right|\\,|\\;|\\!|\\ |\\quad|\\qquad'),
    '',
  );
  s = s.replaceAll('~', ' ');
  s = s.replaceAll(RegExp(r'[{}]'), '');
  s = _scripts(s);
  s = s.replaceAll(RegExp(r'\s+'), ' ');
  return s.trim();
}

const _superscripts = {
  '0': '⁰',
  '1': '¹',
  '2': '²',
  '3': '³',
  '4': '⁴',
  '5': '⁵',
  '6': '⁶',
  '7': '⁷',
  '8': '⁸',
  '9': '⁹',
  '+': '⁺',
  '-': '⁻',
  'n': 'ⁿ',
  'i': 'ⁱ',
  'T': 'ᵀ',
};

const _subscripts = {
  '0': '₀',
  '1': '₁',
  '2': '₂',
  '3': '₃',
  '4': '₄',
  '5': '₅',
  '6': '₆',
  '7': '₇',
  '8': '₈',
  '9': '₉',
  'n': 'ₙ',
  'i': 'ᵢ',
  'j': 'ⱼ',
  'k': 'ₖ',
  'a': 'ₐ',
  'e': 'ₑ',
  'o': 'ₒ',
  'x': 'ₓ',
  'm': 'ₘ',
};

String _scripts(String input) {
  var s = input;
  for (final entry in _superscripts.entries) {
    s = s.replaceAll('^${entry.key}', entry.value);
  }
  for (final entry in _subscripts.entries) {
    s = s.replaceAll('_${entry.key}', entry.value);
  }
  return s;
}
